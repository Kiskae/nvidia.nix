{ lib
, pkgs
, newScope
}:
let
  nvlib = import ./lib { inherit lib; };
  mkManifest = nvlib.manifest.mkManifestWith pkgs;
  classifiers = with nvlib.classifier.matchers; let
    match =
      let
        inherit (lib) genAttrs mapAttrs const;
        vars = genAttrs nvlib.manifest.variables (var: "\$${var}");
        many = mapAttrs (const matchVariableMany) vars;
      in
      (mapAttrs (const matchVariable) vars) // { inherit many; };
  in
  {
    xorg_driver = match.type "XMODULE_*";
    xorg_glx_module = match.type "GLX_MODULE_*";
    xorg_xvmc = match.type "XLIB_*";
    xorg_very_old = match.type "XFREE86_*";
    libnvidia-tls = match.type "TLS_*";
    kernel_src = match.many.type [
      "KERNEL_MODULE_*"
      "UVM_MODULE_*"
    ];
    vdpau = matchAll [
      (match.type "VDPAU_*")
      # some distributions include the vdpau vendor-neutral libs
      (invert (match.type "VDPAU_WRAPPER_*"))
    ];
    vdpau_wrapper = match.type "VDPAU_WRAPPER_*";
    opencl = matchAny [
      (match.type "OPENCL_WRAPPER_*")
      (match.target_path "libOpenCL.so*")
    ];
    html_docs = matchAll [
      (match.target_path "*.html")
      (match.type "DOCUMENTATION")
    ];
    wine_dll = match.type "WINE_LIB";
    firmware = match.type "FIRMWARE";
    ngx = matchAny {
      lib = match.target_path "libnvidia-ngx.so.*";
      bin = match.target_path "nvidia-ngx-updater";
    };
    optical_flow = match.module "opticalflow";
    OptiX = match.module "optix";
    app_profiles = match.type "APPLICATION_PROFILE";
    xorg_config_file = match.type "XORG_OUTPUTCLASS_CONFIG";
    NvFBC = match.target_path "libnvidia-fbc.so*";
    NvEncodeAPI = match.type "ENCODEAPI_*";
    NVCUVID = match.target_path "libnvcuvid.so*";
    nvidia-persistenced = match.src_path "nvidia-persistenced*";
    nvidia-powerd = match.module "powerd";
    nvidia-bug-report = match.many.target_path [
      "nvidia-debugdump"
      "nvidia-bug-report.sh"
    ];
    systemd = matchAny [
      (matchAll [
        (match.type "SYSTEMD_*")
        (match.module "installer")
      ])
      (match.target_path "nvidia-sleep.sh")
    ];
    nvidia-smi = matchAll [
      (match.src_path "*nvidia-smi*")
      (invert (match.target_path "*/nvidia-smi.html"))
    ];
    libnvidia-gtk = match.target_path "libnvidia-gtk*";
    nvidia-settings = match.src_path "*nvidia-settings*";
    nvidia-xconfig = match.src_path "*nvidia-xconfig*";
    nvidia-modprobe = match.src_path "*nvidia-modprobe*";
    nvidia-installer = match.src_path "*nvidia-installer*";
    libnvidia-ml = match.target_path "libnvidia-ml*";
    cuda-mpi = match.many.src_path [
      "nvidia-cuda-mps-*"
      "nvidia-cuda-proxy-*"
    ];
    opencl_driver = matchAny {
      driver = match.target_path "libnvidia-opencl.so.*";
      icd = match.type "CUDA_ICD";
    };
    NVVM = match.target_path "libnvidia-nvvm.so*";
    Fatbinary_Loader = match.target_path "libnvidia-fatbinaryloader.so*";
    PTX_JIT = match.target_path "libnvidia-ptxjitcompiler.so*";
    cuda = match.target_path "libcuda.so*";
    internal_libs = match.many.target_path [
      "libnvidia-cbl*"
      "libnvidia-cfg*"
      "libnvidia-compiler*"
      "libnvidia-eglcore*"
      "libnvidia-glcore*"
      "libnvidia-glsi*"
      "libnvidia-glvkspirv*"
      "libnvidia-rtcore*"
      "libnvidia-allocator*"
      # not explicitly listed?
      "libnvidia-vulkan-producer*"
    ];
    NvIFROpenGL = match.type "NVIFR_*";
    glvnd = matchAny {
      # when shipping both glvnd and non-glvnd versions
      both_shipped = match.extra "GLVND";
      # match the GLVND_* types, except for the glvnd ICD config file
      marked_by_type = matchAll [
        (match.type "GLVND_*")
        (invert (match.type "GLVND_EGL_ICD_JSON"))
      ];
      # if not explicitly marked
      other = matchAll {
        files = matchAny [
          (match.type "EGL_CLIENT_*")
          (match.type "GLX_CLIENT_*")
        ];
        not_glvnd = invert (match.extra "NON_GLVND");
        has_module = match.module "opengl";
      };
    };
    egl_wayland = match.many.target_path [
      "libnvidia-egl-wayland.so.*"
      "10_nvidia_wayland.json"
    ];
    egl_gbm = match.many.target_path [
      "libnvidia-egl-gbm.so.*"
      "15_nvidia_gbm.json"
    ];
    gbm_backend = match.type "GBM_BACKEND_LIB_SYMLINK";
    # non-glvnd libGL
    libGL-nvidia = matchAny {
      opengl_headers = match.type "OPENGL_HEADER";
      not_glvnd = match.extra "NON_GLVND";
      libtool = match.type "LIBGL_LA";
      other = matchAll {
        type = match.type "OPENGL_*";
        not_internal = invert (match.target_path "libnvidia-*");
        no_module = match.module "\"\"";
      };
    };
    glvnd_driver = matchAny {
      drivers = match.many.target_path [
        "libGLX_nvidia.so.*"
        "libEGL_nvidia.so.*"
        "libGLX_indirect.so.0"
        "libGLESv2_nvidia.so.*"
        "libGLESv1_CM_nvidia.so.*"
      ];
      icd = match.type "GLVND_EGL_ICD_JSON";
    };
    vulkan_json = match.type "VULKAN_ICD_JSON";
    supported-gpus = match.src_path "supported-gpus/*";

    installer_utils = match.type "INTERNAL_UTILITY_*";
    misc_documentation = matchAll [
      (match.type "DOCUMENTATION")
      (match.many.src_path [
        "*NVIDIA_Changelog"
        "LICENSE"
        "*README*"
        "*/include/GL/gl*"
        "*/XF86Config.sample"
      ])
    ];
    dkms = match.type "DKMS_CONF";
  };

  #TODO: turn into useful validation layer
  mega_classifier =
    let
      inherit (nvlib.classifier) intercept;
      inherit (nvlib.classifier.matchers) matchAny doOnMatch;
      inherit (nvlib.codegen) concatOutput fromCode ifExpr;

      noop = fromCode ":";
      wrapResult = intercept (g: onPass: onFail: concatOutput [
        (fromCode "declare -a matches\n")
        (g noop noop)
        ""
        (ifExpr "\${#matches[@]} -ne 0" onPass onFail)
      ]);
      # always call onFail, so matchAny evaluates everything
      injectMatch = n: intercept (g: _: onFail: g
        (concatOutput [
          (fromCode "matches+=(${lib.escapeShellArg n})")
          onFail
        ])
        onFail);
    in
    # TODO: needs to just run all other classifiers, not
      #  use the results..
    wrapResult (matchAny (lib.mapAttrs injectMatch classifiers));

  # turns the classifier into a bash script for use with the manifest
  classifierToScript = name: classifier:
    lib.pipe classifier [
      # evaluate state
      nvlib.classifier.eval
      # resolve codegen, output to return
      (with nvlib.codegen; x: x (fromCode "return 0") (fromCode "return 1"))
      # write codegen to strings
      (x: x {
        indent = map (l: "  ${l}");
        fromCode = lib.splitString "\n";
      })
      # merge strings
      (lib.concatStringsSep "\n")
      # write to file
      (pkgs.writeScript "${name}.sh")
    ];

  testPkg = manifest: pkgs.runCommand "classifier-report"
    {
      inherit manifest;
      classifier = classifierToScript "mega_classifier" mega_classifier;
    } ''
    mkdir -p $out/1_results
    ln -s $classifier $out/classifier.sh
    ln -s $manifest $out/manifest.sh

    ${nvlib.manifest.mkScriptTemplate ''
      data=$(echoCmd "entry" "$@")
      declare -a matches
      if source $classifier; then
        if [[ ''${#matches[@]} -gt 1 ]]; then
          echoCmd "matches" ''${matches[@]} >> $out/2_collisions.csv
          echo $data >> $out/2_collisions.csv
        fi

        echo $data >> "$out/1_results/''${matches[0]}.csv"
      else
        echo $data >> $out/0_unmatched.csv
      fi
    '' "$manifest"}
  '';

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

  mkPackages =
    { src
    , version
    }:
    let
      addPackages = self: {
        sources = pkgs.stdenvNoCC.mkDerivation {
          name = lib.removeSuffix ".run" src.name;
          inherit src version;
          nativeBuildInputs = [ makeself_nv ];

          dontConfigure = true;
          dontBuild = true;
          installPhase = "cp -r . $out";
          dontFixup = true;
        };

        manifest = mkManifest self.sources;

        # TODO: replace with classifier
        kmod_sources = pkgs.runCommand "source" { inherit (self) sources; } ''
          cp -rv $sources/kernel/ $out
        '';

        supported_gpus = pkgs.runCommand "supported-gpus"
          {
            nativeBuildInputs = [ pkgs.jq ];
            inherit (self) sources;
          } ''
          install -D -t $out $sources/supported-gpus/*
          jq . $out/supported-gpus.json > $out/supported-gpus-pretty.json
        '';

        kmod = lib.makeOverridable (
          { kernel
          , enableLegacyBuild ? !(lib.versionAtLeast version "390")
            # compatibility with the pre-KBuild makefile
          , ignoreRtCheck ? false
            # whether to allow the driver to compile for realtime kernels
          , disabledModules ? [ ]
          }: kernel.stdenv.mkDerivation ({
            name = "nvidia-kmod-${version}-${kernel.version}";
            inherit version;

            # TODO: inline definition with classifiers?
            src = self.kmod_sources;

            inherit kernel;

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
          })
        );

        pkgFarm = pkgs.linkFarm "current-packages" (
          let
            mapOutputs = drv: map
              (output: {
                name = "${drv.name}${lib.optionalString (output != "out") "-${output}"}";
                path = lib.getOutput output drv;
              })
              drv.outputs;
          in
          lib.concatMap mapOutputs [
            self.sources
            #self.manifest
            #(self.kmod {
            #  inherit (pkgs.linuxPackages_zen) kernel;
            #})
            pkgs.linuxPackages_zen.nvidia_x11_legacy470
            pkgs.mesa
            # self.supported_gpus
            #(classifierToScript "mega_classifier" mega_classifier)
            (testPkg self.manifest)
            pkgs.egl-wayland
            pkgs.libglvnd
            pkgs.xorg.xf86videoati
          ]
        );
      };
    in
    lib.makeScope newScope addPackages;

in
mkPackages
