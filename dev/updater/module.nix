{inputs, ...}: {
  imports = [
    inputs.flake-root.flakeModule
  ];

  perSystem = {
    pkgs,
    config,
    ...
  }: {
    flake-root.projectRootFile = "pkgs/overlay.nix";

    devShells.update = let
      inherit (pkgs) lib python3 formats;

      pytools = python3.withPackages (ps: [
        ps.nvchecker
        ps.lxml
      ]);

      extra_sources = lib.fileset.toSource {
        root = ./.;
        fileset = ./nvchecker_source;
      };

      configFormat = formats.toml {};
      configFile = configFormat.generate "nvchecker.toml" {
        "__config__" = {
          "oldver" = "\${FLAKE_ROOT}/pkgs/refs.json";
          #"newver" = "\${FLAKE_ROOT}/dev/current-versions.json";
        };
        "driver.vulkan-dev" = {
          source = "htmlparser";
          prefix = "Linux ";
          include_regex = "^Linux [.0-9]+$";
          url = "https://developer.nvidia.com/vulkan-driver";
          xpath = ''//*[@id="content"]/div/section/h3'';
        };
        "driver.display" = {
          source = "unix_drivers";
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
        "driver.tesla" = {
          source = "tesla_releases";
          url = "https://docs.nvidia.com/datacenter/tesla/drivers/releases.json";
          from_pattern = ''(?:[^-]+-)*(.+)'';
          to_pattern = ''\1'';
        };
      };
    in
      pkgs.mkShell {
        packages = [pytools pkgs.jq];

        inputsFrom = [config.flake-root.devShell];

        env = {
          PYTHONPATH = toString extra_sources;
          NVCHECKER_CONFIG = toString configFile;
        };

        shellHook = ''
          export SCRATCHDIR=$(mktemp -d)

          nvchecker -c ''${NVCHECKER_CONFIG}

          exit
        '';
      };
  };
}
