{
  lib,
  runCommand,
  linkFarm,
  writeTextFile,
  python3,
  jq,
  tree,
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

        # Ensure we don't need to keep the tarball around
        disallowedReferences = [src];
      } ''
        if [[ $(file -b --mime-type $src) != "text/x-shellscript" ]]; then
          # not a makeself shell script
          return 1
        fi

        # nvidia has used different compression methods
        compression=$(PATH= $SHELL -r $src --info | sed -n 's/^.*Compression\s*:\s\(\S*\).*$/\1/p')
        case $compression in
          xz)
            extractCmd="xz -d"
            ;;
          gzip)
            extractCmd="gzip -d"
            ;;
          *)
            echo "runfile uses unknown compression '$compression'"
            return 1
            ;;
        esac

        skip=$(sed 's/^skip=//; t; d' $src)
        mkdir -p $out
        tail -n +$skip $src | $extractCmd | tar xvf - -C $out
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

  checkAvailability = {
    addedIn ? null,
    removedIn ? null,
    compat32 ? false,
  }:
    (addedIn == null || lib.versionAtLeast version addedIn)
    && (removedIn == null || (lib.versionOlder version removedIn))
    && (!buildCompat32 || compat32);

  generatePkg = pname: {
    availability ? {},
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
        flags = ["--raw-output" "--slurp"];
      } ''
        def basename: split("/") | last;
        def path_definition(f; path_f): (select(.entry | f) | .final_path) = (.entry.path | path_f);
        def emit_cmd: .final_path as $final_path | .entry | if .ln_target != null
          then "ln -s -T \"\(.ln_target)\" \"$out\($final_path)/\(.file_path | basename)\""
          else "install -m \(.mode[-3:]) -t \"$out\($final_path)\" \"$1/\(.file_path)\""
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
            "install -d \"$out\(.[0].final_path)\"",
            map("# \(.raw_entry)", emit_cmd)
          )[] // "return 1"
        ] | flatten[]
      '';
  in
    runCommand "${pname}-${version}" {
      inherit version src installScript;
      meta =
        (removeAttrs src.meta ["sourceProvenance"])
        // meta
        // {
          broken = !(checkAvailability availability);
        };
      allowedReferences = [];
      succeedOnFailure = true;
    } ''
      . $installScript $src
    '';

  /*
  TODO: validation
  - check for entries with more or less than 1 match
  - check that broken packages have no entries
  - check that $out/nix-support/failed doesn't exist for each package
  - generate an overview with tree, removing non-reproducible parts
  */

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
        (.entry | .file_path, .mode, .type, .path, .ln_target, .architecture, .tls_class, .glvnd_variant, .module)
      ] | @sh
    '';

  packages = lib.mapAttrs generatePkg components;
  pkgTree = linkFarm "nvidia-packages" (lib.filterAttrs (_: pkg: (!pkg.meta.broken or false)) packages);
  report =
    runCommand "tree-report" {
      inherit pkgTree version;
      nativeBuildInputs = [tree];
    } ''
      tree -l -s --noreport -o $out $pkgTree
      sed -i -e 's/\/nix\/store\/[^-]*/\/nix\/store\/<storeHash>/g' -e "s/$version/<pkgVer>/g" $out
    '';
in {
  #inherit packages;
  introspection = {
    "data.nix" = writeTextFile {
      name = "data.nix";
      text = lib.generators.toPretty {} components;
    };
    source = src;
    "manifest.json" = annotatedManifest;
    packages = pkgTree;
    "tree.txt" = report;
    "mismatch.csv" = mismatches;
  };
}
