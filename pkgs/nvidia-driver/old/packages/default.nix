{ lib
, pkgs
, system
, linuxPackages
, nvidiaVersion
, distTarball
, enableCompat32 ? false
}:
assert lib.assertMsg
  (enableCompat32 == false || system == "x86_64-linux")
  "compat32 can only be enabled for 'x86_64-linux'";
let
  nvlib = import ../lib { inherit lib; };
  sources =
    let
      # nvidia packages their distributions with a modified makeself 1.6
      makeself_nv = pkgs.makeSetupHook
        {
          # required for makeself to find decompressors
          deps = [ pkgs.which ];
        }
        (pkgs.writeScript "makeself-nvidia" ''
          unpackCmdHooks+=(_tryMakeself)

          _tryMakeself() {
            # we're dealing with a modified makeself
            if ! sh $curSrc --help 2>&1 | grep -q "NVIDIA" ; then return 1; fi
            sh $curSrc --extract-only
          }
        '');
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = lib.removeSuffix ".run" distTarball.name;

      src = distTarball;
      version = nvidiaVersion;

      nativeBuildInputs = [ makeself_nv ];

      dontConfigure = true;
      dontBuild = true;
      installPhase = "cp -r . $out";
      dontFixup = true;

      meta.platforms = [ system ]
        ++ lib.optional enableCompat32 "i686-linux";
    };

  classifiers = lib.makeOverridable (import ./classifiers.nix) {
    inherit lib;
    inherit (nvlib.classifier.matchers)
      matchVariable
      matchVariableMany
      matchAll
      matchAny
      invert;
    vars = lib.genAttrs
      (nvlib.manifest.variables ++ [ "version" ])
      (var: "\$${var}");
    addOverride =
      let
        inherit (nvlib.codegen) concatOutput;
        inherit (nvlib.classifier) intercept;
      in
      params: intercept (g: onPass: g
        (concatOutput
          ((lib.mapAttrsToList
            (n: v: "override[${n}]=\"${v}\"")
            params
          ) ++ [ onPass ]))
      );

    isClassifier = nvlib.state.isState;
  };

  builder = pkgs.callPackage ./builder.nix {
    inherit nvlib;
  };

  dependency_report = drv: pkgs.stdenv.mkDerivation {
    name = "${drv.name}-report";
    buildCommand = ''
      mkdir -p $out/files
      ln -s ${drv} $out/source

      while IFS= read -r file; do
        if isELF $file; then
          output=$out/files/''${file##*/}
          soname=$(patchelf --print-soname $file)
          patchelf --print-needed $file > $output.static.csv
          strings $file | grep ".*\.so" | grep -v "\s" > $output.dynamic.csv
        fi
      done < <(find ${drv}/ -type f)
    '';
  };
in
self:
let
  mkDerivedPackage = self.callPackage ./mkPackage.nix {
    inherit (builder) classifierToInstallPhase;
    nvidiaPkgs = self;
  };
in
{
  inherit mkDerivedPackage sources;

  manifest = nvlib.manifest.mkManifestWith pkgs self.sources;

  kmod =
    let
      src = self.mkDerivedPackage {
        pname = "kmod-sources";
        classifier = classifiers.kmod;
      };
      inherit (src) version;
    in
    lib.makeOverridable
      ({ kernel
       , enableLegacyBuild ? !(lib.versionAtLeast version "390")
         # compatibility with the pre-KBuild makefile
       , ignoreRtCheck ? false
         # whether to allow the driver to compile for realtime kernels
       , disabledModules ? [ ]
       }: kernel.stdenv.mkDerivation ({
        name = "nvidia-kmod-${version}-${kernel.version}";

        inherit version src kernel;

        hardeningDisable = [ "pic" ];
        nativeBuildInputs = kernel.moduleBuildDependencies;

        outputs = [ "out" "dev" ];

        NV_EXCLUDE_KERNEL_MODULES = disabledModules;

        makeFlags = kernel.makeFlags ++ [
          "SYSSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source"
          "SYSOUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        ] ++ lib.optional ignoreRtCheck "IGNORE_PREEMPT_RT_PRESENCE=1";

        buildFlags = [ "modules" ];

        installFlags = [
          "INSTALL_MOD_PATH=$(out)"
        ];

        installTargets = [ "modules_install" ];

        # additional kernel modules like nvidia-fs require these
        postInstall = "install -D -t $dev/src/nvidia-${version}/${kernel.modDirVersion}/ Module*.symvers";

        disallowedReferences = [ kernel.dev ];

        enableParallelBuilding = true;
      } // lib.optionalAttrs enableLegacyBuild {
        # legacy makefile depends on src
        preBuild = "unset src";

        # modules target doesn't exist
        buildFlags = [ "module" ];

        # makefile install requires root, copy over install command
        installPhase = ''
          runHook preInstall

          install -D -m 0664 -t $out/lib/modules/${kernel.modDirVersion}/kernel/video $(make print-module-filename)
            
          runHook postInstall
        '';
      }))
      {
        inherit (linuxPackages) kernel;
      };

  xorg_driver = self.mkDerivedPackage {
    pname = "xorg-drivers";
    classifier = classifiers.xorg;
  };

  driver = self.mkDerivedPackage {
    pname = "glvnd-driver";

    classifier = classifiers.drivers;

    dependencies = pkgs: with pkgs; {
      build = [
        xorg.libX11
        xorg.libXext
        libGL
        egl-wayland
      ];
      runtime = [ ];
    };

    postFixup = ''
      while IFS= read -r file; do
        substituteInPlace $file \
          --replace 'libEGL_nvidia.so.0' '@out@/lib/libEGL_nvidia.so.0' \
          --replace 'libGLX_nvidia.so.0' '@out@/lib/libGLX_nvidia.so.0' \
          --subst-var out
      done < <(find $out/share/ -type f)
    '';
  };

  test = import ./locations.nix {
    inherit lib;
    inherit (nvlib) codegen;

    toScript = code: lib.pipe code [
      # CodeGen
      (x: x {
        indent = map (l: "  ${l}");
        fromCode = lib.splitString "\n";
      })
      # [ string ]
      (lib.concatStringsSep "\n")
      # string
      (pkgs.writeScript "well-known.sh")
      # derivation
    ];
  };

  pkgFarm = self.manifest;
}
