{ lib
, pkgs
, stdenvNoCC
, binutils
, patchelf
, tools ? pkgs.callPackage ./tools { } }:
let
  installActionTemplate =
    { prefixSelector ? ""
      # overwrite prefix to change the location the file is created at
    , symlinkSelector ? ""
      # overwrite link_to to change the location of the file linked to
    , derivationArgs ? { }
    }: {
      inherit derivationArgs;
      script = ''
        local prefix=$out
        ${prefixSelector}

        case $type in
          *_SYMLINK|*_NEWSYM)
            local link_to=$prefix
            ${symlinkSelector}
            ln -s -T "$link_to/$src_path" "$prefix/$target_path"
            ;;
          *)
            install -D -m''${perms: -3} $src_path $prefix/$target_path
        esac
      '';
    };

  libraryInstall = { noCompat32 ? false }:
    let
      templateCompat32 = if noCompat32 then (lib: _: "prefix=${lib}") else
      (lib: lib32: ''
        if [[ $arch = COMPAT32 ]]; then
          prefix=${lib32}
        else
          prefix=${lib}
        fi
      '');
    in
    installActionTemplate {
      derivationArgs = {
        nativeBuildInputs = [ binutils patchelf ];
        outputs = [ "lib" "out" ] ++ lib.optional (!noCompat32) "lib32";
      };
      prefixSelector = ''
        ${templateCompat32 (placeholder "lib") (placeholder "lib32")}
        prefix=$prefix/lib
      '';
    };

  packagesFor = src:
    let
      manifest = tools.prepareManifest src;
      mkNvidiaDerivation =
        { pname
        , derivationArgs ? installSingleFile.derivationArgs
        , nativeBuildInputs ? [ ]
        , classifiers
        , installSingleFile ? installActionTemplate { }
        }:
        let
          installScript = tools.bashHandlerDefinition {
            inherit manifest;
            entryHandler = ''
              classifier="assert_no_classification"
              runClassifier $@ || true
                
              if [[ ! $classifier_filter =~ "|$classifier|" ]]; then
                  return 0
              fi

              header "installing $type/$target_path"
              source $installActionPath
            '';
          };
        in
        stdenvNoCC.mkDerivation ({
          inherit pname src;
          inherit (src) version;
          nativeBuildInputs = [ tools.classifierHook ] ++ (derivationArgs.nativeBuildInputs or [ ]);
          phases = [ "installPhase" "fixupPhase" ];
          classifier_filter = "|${lib.concatStringsSep "|" classifiers}|";
          installAction = installSingleFile.script;
          passAsFile = [ "installAction" ] ++ (derivationArgs.passAsFile or [ ]);
          passthru = (derivationArgs.passthru or {}) // {
            inherit classifiers;
          };
          installPhase = ''
            cd $src

            source ${installScript}
          '';
        } // builtins.removeAttrs derivationArgs [ "passthru" "nativeBuildInputs" "passAsFile" ]);

      builder = self: with self; {
        inherit manifest;

        kernel_sources = mkNvidiaDerivation {
          pname = "nvidia-kernel-sources";
          classifiers = [
            "kernel_nvidia"
            "kernel_nvidia_drm"
            "kernel_nvidia_modeset"
            "kernel_nvidia_peermem"
            "kernel_nvidia_uvm"
            "kernel_legacy"
          ];
        };

        libnvidia_internal = mkNvidiaDerivation {
          pname = "libnvidia-internal";
          classifiers = [
            "libnvidia_internal"
          ];
          installSingleFile = libraryInstall { };
        };
      };
    in
    lib.makeExtensible builder;
in
packagesFor
