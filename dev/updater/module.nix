{inputs, ...}: {
  imports = [
    inputs.flake-root.flakeModule
  ];

  perSystem = {
    pkgs,
    config,
    ...
  }: {
    flake-root.projectRootFile = ".git/config";

    devShells.update = let
      inherit (pkgs) writeText lib formats;

      versions = pkgs.callPackage "${inputs.flake}/pkgs/nvidia-driver/versions" {};

      nvchecker = let
        nvchecker_config = {
          "__config__" = {
            # todo: derive from versions directory
            "oldver" = "\${FLAKE_ROOT}/pkgs/nvidia-driver/versions/refs.json";
            "newver" = "\${SCRATCHDIR}/current-versions.json";
          };

          "vulkan-dev" = {
            source = "htmlparser";
            prefix = "Linux ";
            include_regex = "^Linux [.0-9]+$";
            url = "https://developer.nvidia.com/vulkan-driver";
            xpath = ''//*[@id="content"]/div/section/h3'';
          };

          "geforce" = {
            source = "unix_drivers";

            # branch/maturity mapping based on
            # https://github.com/aaronp24/nvidia-versions
            known = lib.mapAttrsToList (match: data:
              {
                inherit match;
              }
              // data) {
              "Production Branch Version" = {
                maturity = "long-lived-branch-release";
              };
              "New Feature Branch Version" = {};
              "Beta Version" = {
                maturity = "beta";
              };
              "Legacy GPU version (470.xx series)" = {
                branch = "R470_00";
              };
              "Legacy GPU version (390.xx series)" = {
                branch = "R390_00";
              };
              "Legacy GPU version (340.xx series)" = {
                branch = "R340_00";
              };
              "Legacy GPU version (304.xx series)" = {
                branch = "R304_00";
              };
              "Legacy GPU Version (71.86.xx series)" = {
                branch = "L7160";
              };
              "Legacy GPU Version (96.43.xx series)" = {
                branch = "L9622";
              };
              "Legacy GPU Version (173.14.xx series)" = {
                branch = "R173_14";
              };
            };
          };

          "tesla" = {
            source = "tesla_releases";
            url = "https://docs.nvidia.com/datacenter/tesla/drivers/releases.json";

            # tesla versions prepend date, so newer releases supercede
            from_pattern = ''(?:[^-]+-)*(.+)'';
            to_pattern = ''\1'';
          };
        };

        nvchecker_extra = lib.fileset.toSource {
          root = ./.;
          fileset = ./nvchecker_source;
        };

        configFormat = formats.toml {};
        configFile = configFormat.generate "nvchecker.toml" nvchecker_config;

        packageOverrides = self: super: {
          nvchecker = super.nvchecker.overridePythonAttrs (old: {
            propagatedBuildInputs = old.propagatedBuildInputs ++ [self.lxml];
            makeWrapperArgs = [
              ''--append-flags "-c ${configFile}"''
              ''--prefix PYTHONPATH : ${nvchecker_extra}''
            ];
          });
        };
        python = pkgs.python3.override {
          inherit packageOverrides;
          self = python;
        };
      in
        python.withPackages (ps: [ps.nvchecker]);

      jqHandleArray = writeText "map-arr.jq" ''
        .[] | [
          .name,
          .newver
        ] | @tsv
      '';
    in
      pkgs.mkShell {
        packages = [nvchecker pkgs.jq];

        inputsFrom = [config.flake-root.devShell];

        shellHook = ''
          handleNewVersion() {
            local name="$1"
            local version="$2"

            case "$name" in
              driver.vulkan-dev)
                echo "VULKAN"
                ;;
              driver.display.*)
                echo "DISPLAY"
                ;;
              driver.tesla.*)
                echo "TESLA"
                ;;
              *)
                echo "WHAT"
                ;;
            esac

            echo "$name => $version"
          }

          export SCRATCHDIR=$(mktemp -d)
          trap 'rm -rf -- "$SCRATCHDIR"' EXIT

          exec nvchecker
        '';
      };
  };
}
