{lib}: let
  match = rec {
    # ensure that each filter has a single output, either the entry or 'false', so 'all' works correctly
    all = matchers: "[${lib.concatMapStringsSep ", " (m: "select(${m}) // false") matchers}] | all";
    any = matchers: "[${lib.concatMapStringsSep ", " (m: "(${m})") matchers}] | any";

    field = field: matcher: ''.${field} | ${matcher}'';

    type = field "type";
    filePath = field "file_path";
    path = field "path";
    module = field "module";

    basename = matcher: filePath "basename | ${matcher}";
  };

  processComponent = let
    doExtraPath = {
      test ? "",
      path,
      force_path ? false,
    } @ attrs:
      attrs;
    doAvailability = {
      addedIn ? "",
      removedIn ? "",
      compat32 ? false,
    } @ attrs:
      attrs;
    doComponent = pname: {
      matcher ? ''error("No matcher for '${pname}'")'',
      availability ? {},
      meta ? {},
      extraPaths ? [],
      ...
    }: {
      inherit meta;
      extraPaths = map doExtraPath extraPaths;
      jqFilter = matcher;
      availability = doAvailability availability;
    };
    handleProfile = pname: let
      doNext = doComponent pname;
    in
      {profile ? null, ...} @ attrs:
        if profile != null
        then doNext (attrs // (profile pname attrs))
        else doNext attrs;
  in
    handleProfile;

  egl_platform_profile = _: {matcher, ...}: {
    matcher = match.all [
      matcher
      (match.type ''. == "EGL_EXTERNAL_PLATFORM_JSON"'')
    ];

    extraPaths = [
      {
        path = "/share/egl/egl_external_platform.d";
      }
    ];
  };

  kernel_source_profile = _: {
    matcher,
    meta ? {},
    ...
  }: {
    matcher = match.all [
      matcher
      (match.type ''
        startswith(
          "KERNEL_MODULE_",
          "UVM_MODULE_",
          "DKMS_CONF"
        )'')
    ];

    extraPaths = [
      {
        path = "/src";
      }
    ];

    meta =
      {
        # kernel sources distributed by nvidia include precompiled object files.
        sourceProvenance = with lib.sourceTypes; [fromSource binaryNativeCode];
      }
      // meta;
  };

  dylib_profile = pname: {
    matcher ? match.basename ''startswith("${pname}")'',
    meta ? {},
    ...
  }: {
    inherit matcher;
    meta =
      {
        sourceProvenance = with lib.sourceTypes; (meta.sourceProvenance or []) ++ [binaryNativeCode];
      }
      // meta;
  };

  executable_profile = pname: {
    matcher ?
      match.all [
        (match.basename ''startswith("${pname}")'')
        (match.path ''endswith("html") | not'')
      ],
    meta ? {},
    ...
  }: {
    inherit matcher;
    meta =
      {
        sourceProvenance = with lib.sourceTypes; (meta.sourceProvenance or []) ++ [binaryNativeCode];
      }
      // meta;
  };
in
  lib.mapAttrs processComponent rec {
    egl_glvnd_icd = {
      matcher = match.type ''. == "GLVND_EGL_ICD_JSON"'';

      extraPaths = [
        {
          path = "/share/glvnd/egl_vendor.d";
        }
      ];

      inherit (libglvnd_nvidia) availability;
    };

    egl_platform_gbm = {
      matcher = match.filePath ''contains("_gbm")'';
      profile = egl_platform_profile;
      inherit (libnvidia-egl-gbm) availability;
    };

    egl_platform_wayland = {
      matcher = match.filePath ''contains("_wayland")'';
      profile = egl_platform_profile;
      inherit (libnvidia-egl-wayland) availability;
    };

    firmware = {
      matcher = match.type ''. == "FIRMWARE"'';

      extraPaths = [
        {
          path = "/lib/firmware/nvidia/\\($version)";
        }
      ];

      meta = {
        sourceProvenance = with lib.sourceTypes; [binaryFirmware];
        license = lib.licenses.unfreeRedistributableFirmware;
      };

      availability = {
        addedIn = "465.19.01";
      };
    };

    html-docs = {
      matcher = match.path ''. == "NVIDIA_GLX-1.0/html"'';
      availability = {
        # might be earlier, but only checking the official builds
        addedIn = "96.43.23";
      };
    };

    kmod-open = {
      matcher = match.filePath ''startswith("kernel-open/")'';
      availability = {
        addedIn = "515.43.04";
      };
      profile = kernel_source_profile;
    };

    kmod-unfree = {
      matcher = match.filePath ''startswith("\($header[0].kernel_module_build_dir)/")'';
      profile = kernel_source_profile;
    };

    libcuda = {
      availability = {
        # might be earlier, but only checking the official builds
        # NOTE: available as early as r173, but not included in manifest for some reason
        addedIn = "304.137";
        compat32 = true;
      };
      #TODO: includes libcudadebugger, should this be seperate
      profile = dylib_profile;
    };

    libGL-nvidia = {
      matcher = match.any [
        (match.type ''. == ("OPENGL_HEADER", "LIBGL_LA")'')
        ''.glvnd_variant == "NON_GLVND"''
        (match.all [
          # messy, but gathers the non-vendored OPENGL libs
          (match.type ''startswith("OPENGL_")'')
          (match.basename ''startswith("libnvidia-") | not'')
          (match.module ''. == null'')
          (match.filePath ''contains("_nvidia.so") | not'')
        ])
      ];

      extraPaths = [
        {
          test = match.type ''endswith("_HEADER")'';
          path = "/include";
        }
      ];

      availability = {
        removedIn = "435.17";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libglvnd = {
      matcher = match.any [
        ''.glvnd_variant == "GLVND"''
        (match.all [
          (match.type ''startswith("GLVND_")'')
          (match.type ''. == "GLVND_EGL_ICD_JSON" | not'')
        ])
        (match.all [
          (match.type ''
            startswith(
              "EGL_CLIENT_",
              "GLX_CLIENT_"
            )'')
          ''.glvnd_variant == "NON_GLVND" | not''
          (match.module ''. == "opengl"'')
        ])
      ];

      inherit (libglvnd_nvidia) availability;

      profile = dylib_profile;
    };

    libglvnd_install_checker = {
      matcher = match.filePath ''contains("libglvnd_install_checker")'';

      availability = {
        addedIn = "450.51";
        compat32 = true;
      };
    };

    libglvnd_nvidia = {
      matcher = match.basename ''
        startswith(
          "libGLX_nvidia.so.",
          "libGLX_indirect.so.",
          "libEGL_nvidia.so.",
          "libGLESv2_nvidia.so.",
          "libGLESv1_CM_nvidia.so."
        )'';

      availability = {
        addedIn = "361.16";
        compat32 = true;
      };
    };

    libnvcuvid = {
      availability = {
        addedIn = "260.19.04";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-allocator = {
      matcher = match.module ''. == "nvalloc"'';

      availability = {
        # debian changelog
        addedIn = "440.26";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-api = {
      profile = dylib_profile;
      availability = {
        addedIn = "525.53";
      };
    };

    libnvidia-cfg = {
      availability = {
        # might be earlier, but only checking the official builds
        addedIn = "96.43.23";
      };
      profile = dylib_profile;
    };

    libnvidia-compiler = {
      inherit (libcuda) availability;
      profile = dylib_profile;
    };

    libnvidia-egl-gbm = {
      availability = {
        addedIn = "495.29.05";
      };
      profile = dylib_profile;
    };

    libnvidia-egl-wayland = {
      availability = {
        addedIn = "378.09";
      };

      profile = dylib_profile;
    };

    libnvidia-eglcore = {
      availability = {
        # NOTE: some builds appear to only contain 32-bit versions..
        addedIn = "331.20";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-encode = {
      matcher = match.type ''startswith("ENCODEAPI_")'';

      availability = {
        addedIn = "319.12";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-fatbinaryloader = {
      availability = {
        # from debian changelog
        addedIn = "361.45.18";
        removedIn = "450.51";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-fbc = {
      availability = {
        addedIn = "331.17";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-glcore = {
      availability = {
        # might be earlier, but only checking the official builds
        addedIn = "304.137";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-glsi = {
      availability = {
        # might be earlier, but only checking the official builds
        addedIn = "340.108";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-glvkspirv = {
      availability = {
        # debian changelog
        addedIn = "396.18";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-ifr = {
      matcher = match.type ''startswith("NVIFR_")'';
      availability = {
        addedIn = "319.49";
        removedIn = "495.29.05";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-ml = {
      availability = {
        # debian changelog
        addedIn = "270.30";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-ngx = {
      matcher = match.all [
        (match.module ''. == "ngx"'')
        (match.type ''. != "WINE_LIB"'')
      ];
      inherit (wine_dll) availability;
      profile = dylib_profile;
    };

    libnvidia-nvvm = {
      availability = {
        # debian changelog
        addedIn = "470.42.01";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-opencl = {
      availability = {
        # debian changelog
        addedIn = "195.36.24";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-opticalflow = {
      matcher = match.module ''. == "opticalflow"'';
      availability = {
        addedIn = "418.30";
      };
      profile = dylib_profile;
    };

    libnvidia-ptxjitcompiler = {
      availability = {
        # from debian changelog
        addedIn = "361.45.18";
        compat32 = true;
      };

      profile = dylib_profile;
    };

    libnvidia-rtcore = {
      matcher = match.module ''. == "raytracing"'';
      availability = {
        addedIn = "410.57";
      };
      # includes libnvidia-cbl < 495
      profile = dylib_profile;
    };

    libnvidia-tls = {
      matcher = match.type ''startswith("TLS_")'';
      availability = {
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libnvidia-vulkan-producer = {
      availability = {
        # debian changelog
        addedIn = "470.63.01";
      };

      profile = dylib_profile;
    };

    libnvoptix = {
      matcher = match.module ''. == "optix"'';
      availability = {
        addedIn = "410.57";
      };
      profile = dylib_profile;
    };

    libOpenCL = {
      inherit (libnvidia-opencl) availability;
      profile = dylib_profile;
    };

    libvdpau = {
      matcher = match.all [
        (match.type ''startswith("VDPAU_")'')
        (match.basename ''contains("_nvidia") | not'')
      ];
      availability = {
        inherit (libvdpau_nvidia.availability) addedIn;
        # removed multiple times, need to live with warnings on older builds
        removedIn = "361.16";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    libvdpau_nvidia = {
      availability = {
        addedIn = "180.22";
        compat32 = true;
      };
      profile = dylib_profile;
    };

    misc_documentation = {
      # includes LICENSE and CHANGELOG
      matcher = match.any [
        (match.all [
          (match.path ''. == "NVIDIA_GLX-1.0"'')
          (match.basename ''startswith("nvidia-") | not'')
          (match.filePath ''. != "supported-gpus.json"'')
        ])
        # some builds include libGL headers twice
        (match.path ''. == "NVIDIA_GLX-1.0/include/GL"'')
      ];
    };

    misc_grid_contrib = {
      matcher = match.filePath ''
        . == (
          "pci.ids",
          "monitoring.conf"
        )'';

      extraPaths = [
        {
          path = "";
        }
      ];

      availability = {
        # debian changelog
        addedIn = "331.79";
        removedIn = "352.21";
      };
    };

    nvidia-application-profile = {
      matcher = match.type ''. == "APPLICATION_PROFILE"'';

      extraPaths = [
        {
          # is this correct?
          path = "/share/nvidia";
        }
      ];

      availability = {
        # debian changelog
        addedIn = "319.60";
      };
    };

    nvidia-bug-report = {
      matcher = match.filePath ''
        startswith(
          "nvidia-bug-report",
          "nvidia-debugdump",
          # very old version of the path
          "usr/bin/nvidia-bug-report.sh"
        )'';
      # Shell scripts and a binary utility
      meta.sourceProvenance = with lib.sourceTypes; [binaryNativeCode fromSource];
    };

    nvidia-cuda-mps = {
      matcher = match.basename ''startswith("nvidia-cuda-")'';
      availability = {
        # debian changelog
        addedIn = "304.88";
      };
      profile = executable_profile;
    };

    nvidia-installer = {
      matcher = match.filePath ''
        contains(
          "nvidia-installer",
          "nvidia-uninstall"
        )'';
      profile = executable_profile;
    };

    nvidia-modprobe = {
      extraPaths = [
        {
          test = match.type ''. == "NVIDIA_MODPROBE"'';
          path = "/bin";
          force_path = true;
        }
      ];

      availability = {
        addedIn = "319.12";
      };

      profile = executable_profile;
    };

    nvidia-persistenced = {
      availability = {
        addedIn = "319.17";
      };
      profile = executable_profile;
    };

    nvidia-powerd = {
      matcher = match.module ''. == "powerd"'';

      extraPaths = [
        {
          test = match.basename ''. == "nvidia-dbus.conf"'';
          path = "/share/dbus-1/system.d";
        }
      ];

      availability = {
        addedIn = "510.39.01";
      };

      profile = executable_profile;
    };

    nvidia-settings = {
      matcher = match.basename ''
        startswith(
          "nvidia-settings",
          "libnvidia-gtk",
          "libnvidia-wayland-client"
        )'';
      profile = executable_profile;
    };

    nvidia-sleep = {
      matcher = match.all [
        (match.any [
          (match.filePath ''startswith("systemd/")'')
          (match.type ''startswith("SYSTEMD_")'')
          (match.path ''. == "NVIDIA_GLX-1.0/samples/systemd"'')
        ])
        (match.module ''. == "installer"'')
      ];

      extraPaths = [
        # build 460.91.03 has scripts as "documentation"
        {
          test = match.all [
            (match.filePath ''endswith(".service")'')
            (match.type ''. == "DOCUMENTATION"'')
          ];
          path = "/lib/systemd/system";
          force_path = true;
        }
        {
          test = match.any [
            (match.type ''. == "SYSTEMD_SLEEP_SCRIPT"'')
            (match.basename ''. == "nvidia"'')
          ];
          path = "/lib/systemd/system-sleep";
          force_path = true;
        }
        {
          test = match.all [
            (match.filePath ''endswith("nvidia-sleep.sh")'')
            (match.type ''. == "DOCUMENTATION"'')
          ];
          path = "/bin";
          force_path = true;
        }
      ];

      availability = {
        addedIn = "430.09";
      };
      profile = executable_profile;
    };

    nvidia-smi = {
      availability = {
        # debian changelog
        addedIn = "173.14.39";
      };
      profile = executable_profile;
    };

    nvidia-xconfig = {
      availability = {
        # might be earlier, but only checking the official builds
        addedIn = "96.43.23";
      };
      profile = executable_profile;
    };

    opencl_icd = {
      matcher = match.type ''. == "CUDA_ICD"'';

      extraPaths = [
        {
          path = "/etc/OpenCL/vendors";
        }
      ];

      inherit (libnvidia-opencl) availability;
    };

    supported-gpus = {
      matcher = match.any [
        (match.path ''. == "NVIDIA_GLX-1.0/supported-gpus"'')
        (match.filePath ''. == "supported-gpus.json"'')
      ];

      extraPaths = [
        {
          path = "";
          force_path = true;
        }
      ];

      availability = {
        addedIn = "450.51";
      };
    };

    vulkan_icd = {
      matcher = match.type ''. == "VULKAN_ICD_JSON"'';

      extraPaths = [
        {
          path = "/share/vulkan";
        }
      ];

      availability = {
        addedIn = "364.12";
        compat32 = true;
      };
    };

    wine_dll = {
      matcher = match.type ''. == "WINE_LIB"'';

      extraPaths = [
        {
          path = "/lib/nvidia/wine";
        }
      ];

      availability = {
        addedIn = "470.42.01";
      };

      profile = dylib_profile;
    };

    xserver = {
      matcher = match.type ''
        startswith(
          "XMODULE_",
          "GLX_MODULE_",
          "XLIB_",
          "XFREE86_",
          "XORG_"
        )'';

      extraPaths = [
        {
          path = "/lib/xorg/modules";
        }
        {
          test = match.type ''. == "XORG_OUTPUTCLASS_CONFIG"'';
          path = "/share/X11/xorg.conf.d";
        }
      ];

      profile = dylib_profile;
    };
  }
