{ lib
, nvlib
, writeScript
}:
let
  inherit (nvlib.manifest) mkScriptTemplate variables;

  classifierToScript = name: classifier: lib.pipe classifier [
    # State[int, Matcher]
    nvlib.classifier.eval
    # Matcher
    (
      let inherit (nvlib.codegen) fromCode; in
      x: x
        (fromCode "return 0")
        (fromCode "return 1")
    )
    # CodeGen
    (x: x {
      indent = map (l: "  ${l}");
      fromCode = lib.splitString "\n";
    })
    # [ string ]
    (lib.concatStringsSep "\n")
    # string
    (writeScript "${name}.sh")
    # derivation
  ];

  vars = lib.genAttrs nvlib.manifest.variables (x: "\$${x}");

  wellKnown = writeScript "well-known-locations.sh" ''
    declare prefix dir

    prefix=out
    case ${vars.type} in
      MANPAGE)
        prefix=$outputMan
        dir=/share/man
        ;;
      XORG_OUTPUTCLASS_CONFIG)
        prefix=$outputLib
        dir=/share/X11/xorg.conf.d
        ;;
      GLVND_EGL_ICD_JSON)
        prefix=$outputLib
        dir=/share/glvnd/egl_vendor.d
        ;;
      GBM_BACKEND_LIB_SYMLINK)
        prefix=$outputLib
        dir=/lib/gbm
        ln_path=$out/lib
        ;;
      VULKAN_ICD_JSON)
        prefix=$outputLib
        dir=/share/vulkan
        ;;
      *_BIN*)
        prefix=$outputBin
        dir=/bin
        ;;
      *)
        prefix=$outputLib
        dir=/lib
        ;;
    esac

    if [[ ${vars.arch} == COMPAT32 ]]; then
      prefix=lib32
    fi
  '';
in
{
  inherit classifierToScript;

  classifierToInstallPhase =
    let
      inherit (nvlib.classifier.matchers) matchAny;
      toScript = classifierToScript;
    in
    lib.makeOverridable (
      { pname
      , classifier
      , manifest
      , source
      }: writeScript "${pname}-install-phase" (
        nvlib.manifest.mkScriptTemplate ''
          local version=$version

          source ${wellKnown}

          declare -A override
          if source ${toScript pname classifier}; then
            # process overrides
            dir=''${override[dir]:-$dir}
            prefix=''${override[prefix]:-$prefix}
            echo "\$$prefix$dir/$target_path"
            target_dir=''${!prefix:?missing output dir}$dir

            if [[ ! ${vars.perms} == "0000" ]]; then
              install -D \
                -m ${vars.perms} \
                -T ${source}/$src_path $target_dir/$target_path
            else
              #TODO: target needs to be overridable
              mkdir -p $target_dir
              ln -s \
                -r \
                -T ''${ln_path:-$target_dir}/$src_path $target_dir/$target_path
            fi
          fi
        ''
          manifest
      )
    );
}

