{
  lib,
  runCommand,
  linkFarm,
  writeText,
  python3,
  jq,
  tree,
  libarchive,
  # package inputs
  src,
  doExtract ? true,
  buildCompat32 ? false,
  version ? src.version,
  meta ? src.meta or {},
} @ args: let
  src = let
    inherit (args) src;
    meta' =
      (src.meta or {})
      // {
        # default to unfree license if not specified
        license = lib.licenses.unfree;
      }
      // meta;
  in
    if doExtract
    then
      runCommand "nvidia-source-${version}" {
        inherit src version;
        meta = meta';

        nativeBuildInputs = [libarchive];

        # Ensure we don't need to keep the tarball around
        disallowedReferences = [src];
      } ''
        skip=$(sed 's/^skip=//; t; d' $src)

        mkdir -p $out
        tail -n +$skip $src | bsdtar xvf - -C $out
      ''
    # components derive from the source package, make sure it has a license
    else lib.addMetaAttrs meta' src;

  manifest =
    runCommand "nvidia-manifest" {
      inherit src;
      nativeBuildInputs = [python3];
    } ''
      if [ ! -f "$src/.manifest" ]; then
        echo "$src is not an nvidia-installer distribution"
        exit 1
      fi

      mkdir $out
      python ${./parse-manifest.py} \
        --entries "$out/manifest.json" \
        --header "$out/header.json" \
        "$src/.manifest"
    '';

  runJqScript = {
    name,
    src,
    flags ? [],
    preBuild ? "",
  }: script:
    runCommand "jq-${name}" {
      jqScript = script;
      passAsFile = ["jqScript"];
      outputs = ["out" "script"];
      nativeBuildInputs = [jq];
    } ''
      ${preBuild}

      install -D -T $jqScriptPath $script

      jq -f $script \
         ${lib.escapeShellArgs flags} \
         ${src} \
         >> $out
    '';

  components = import ./components.nix {inherit lib;};

  annotatedManifest =
    runJqScript {
      name = "annotated-manifest.json";
      src = "${manifest}/manifest.json";
      flags = ["--slurpfile" "header" "${manifest}/header.json"];
    } ''
      def mark(f; $name): (select(.entry | f) | .match) |= . + [$name];
      def basename: split("/") | last;
      ${lib.concatStringsSep " |\n" (lib.mapAttrsToList (
          pname: entry: ''
            # ${pname}
            mark(${entry.jqFilter}; "${pname}")''
        )
        components)}
    '';

  availability = let
    isAtLeast = lib.versionAtLeast version;
    isOlder = lib.versionOlder version;
    isAvailable = {
      addedIn ? null,
      removedIn ? null,
      compat32 ? false,
    }:
      (addedIn == null || (isAtLeast addedIn))
      && (removedIn == null || (isOlder removedIn))
      && (!buildCompat32 || compat32);
    checkPackage = _: {availability ? {}, ...}: isAvailable availability;
  in
    lib.mapAttrs checkPackage components;

  generatePkg = pname: {
    meta ? {},
    extraPaths ? [],
    ...
  }: let
    defaultPaths = [
      {
        path = "/lib";
      }
      {
        test = ''.type | endswith("MANPAGE")'';
        path = "/share/man";
      }
      {
        test = ''.type | contains("_BIN")'';
        path = "/bin";
      }
      {
        test = ''.type == "DOCUMENTATION"'';
        path = "/share/doc";
      }
      {
        test = ''.type == "DOT_DESKTOP"'';
        path = "/share/applications";
        force_path = true;
      }
      {
        test = ''.file_path | endswith(".png")'';
        path = "/share/icons/hicolor/128x128/apps";
        force_path = true;
      }
      {
        test = ''.type | startswith("SYSTEMD_UNIT")'';
        path = "/lib/systemd/system";
      }
    ];
    installScript =
      runJqScript {
        name = "install-${pname}-${version}.sh";
        src = annotatedManifest;
        flags = [
          "--raw-output"
          "--slurp"
          "--arg"
          "version"
          version
        ];
      } ''
        def basename: split("/") | last;
        def path_definition(f; path_f): (select(.entry | f) | .final_path) = (.entry.path | path_f);
        def emit_cmd: .final_path as $final_path | .entry | if .ln_target != null
          then "ln -v -s -T \"\(.ln_target)\" \"$out\($final_path)/\(.file_path | basename)\""
          else "install -v -m \(.mode[-3:]) -t \"$out\($final_path)\" \"$1/\(.file_path)\""
          end;
        map(
          # filter out compat32 based on flag
          select(.entry.architecture != "${
          if buildCompat32
          then "NATIVE"
          else "COMPAT32"
        }") |
          # only entries for this module
          select(.match[]? == "${pname}") |
          # ensure path is appendable
          (.entry.path |= if . != "." then "/\(.)" else "" end) |
          ${lib.concatMapStringsSep
          " |\n" ({
            test ? "true",
            path,
            force_path ? false,
          }: ''path_definition(${test}; "${path}"${lib.optionalString (!force_path) " + ."})'')
          (defaultPaths ++ extraPaths)}
        ) |
        group_by(.final_path) |
        [
          "#!/usr/bin/env bash",
          map(
            "install -v -d \"$out\(.[0].final_path)\"",
            map("# \(.raw_entry)", emit_cmd)
          )[] // "return 1"
        ] | flatten[]
      '';
  in
    runCommand "${pname}-${version}" {
      inherit pname version src installScript;
      meta =
        (removeAttrs src.meta ["sourceProvenance"])
        // meta
        // {
          broken = !availability.${pname};
        };
      allowedReferences = [];
      succeedOnFailure = true;
    } ''
      . $installScript $src
    '';

  componentReport = let
    availabilityJSON = writeText "availability.json" (builtins.toJSON availability);
    compat32JSON = writeText "compat32.json" (builtins.toJSON (lib.mapAttrs
      (_: attrs: (attrs.availability or {}).compat32 or false)
      components));
  in
    runJqScript {
      name = "data.json";
      src = annotatedManifest;
      flags = [
        "--slurp"
        "--slurpfile"
        "availability"
        availabilityJSON
        "--slurpfile"
        "compat32"
        compat32JSON
      ];
    } ''
      . as $manifest |
      # index on availability keys, since matches might not even occur in the manifest
      reduce ($availability[0] | keys[]) as $match (
        {};
        setpath(
          [$match];
          $manifest | map(select(.match[]? == $match) | .entry) | {
            total: length,
            native: map(select(.architecture == "NATIVE")) | length,
            compat32: map(select(.architecture == "COMPAT32")) | length,
            hasCompat32: ($compat32[0][$match] or false),
            isAvailable: ($availability[0][$match] or false)
          }
        )
      )
    '';

  mismatches =
    runJqScript {
      name = "mismatches.csv";
      src = annotatedManifest;
      flags = ["--raw-output"];
      preBuild = ''
        echo "matches file_path mode type path ln_target architecture tls_class glvnd_variant module" > $out
      '';
    } ''
      select(.match | length != 1) | [
        (.match | length),
        (.entry | .file_path, .mode, .type, .path, .ln_target, .architecture, .tls_class, .glvnd_variant, .module),
        .match[]?
      ] | @sh
    '';

  packages = lib.mapAttrs generatePkg components;

  pkgTree = linkFarm "nvidia-packages-${version}" (lib.filterAttrs (_: pkg: (!pkg.meta.broken or false)) packages);
  componentTree =
    runCommand "nvidia-component-tree" {
      inherit pkgTree version;
      nativeBuildInputs = [tree];
    } ''
      tree -l --noreport -o $out $pkgTree
      sed -i -e 's/\/nix\/store\/[^-]*/\/nix\/store\/<storeHash>/g' -e "s/$version/<pkgVer>/g" $out
    '';
in {
  inherit packages;
  report = linkFarm "nvidia-report-${version}" {
    "source" = src;
    "packages" = pkgTree;
    "entry-summary.json" = componentReport;
    "manifest.json" = annotatedManifest;
    "final-components.nix" = writeText "final-components.nix" (lib.generators.toPretty {} components);
    "tree.txt" = componentTree;
    "mismatch.csv" = mismatches;
  };

  check = let
    # check that all components that yield files are marked as non-broken
    #  and all compat32 packages contain native lib counterparts
    checkComponentInvariants =
      runJqScript {
        name = "check-statics";
        src = componentReport;
        flags = [
          "--exit-status"
        ];
      } ''
        def checks($match):
          def check(test; $msg):
            if test | not
            then "assert failed (\($match)): \($msg)" | stderr | false
            else true end | [$match, $msg, .];
          check(
            (.total > 0) == .isAvailable;
            "at least 1 entry required to be available"
          ),
          check(
            [
              .hasCompat32,
              (.compat32 == 0)
            ] | any;
            "all components containing compat32 are marked"
          ),
          check(
            (.hasCompat32 | not) or (
              (.native > 0) == (.compat32 > 0)
            );
            "compat32 with native files must include compat32 counterparts"
          );
        to_entries | map(
          .key as $match | .value | checks($match)
        ) | map(last) | all
      '';
  in
    runCommand "check-nvidia-${version}" {
      packages = pkgTree;
      buildInputs = [checkComponentInvariants];
      nativeBuildInputs = [jq];
      succeedOnFailure = true;
    } ''
      # check that all packages built successfully
      for f in $packages/*;
      do
        echo "Checking $(basename "$f") for failure"
        [ ! -f "$f/nix-support/failed" ]
      done

      # TODO: check for mismatches

      touch $out
    '';
}
