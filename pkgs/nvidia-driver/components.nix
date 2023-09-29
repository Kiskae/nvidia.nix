{lib}: let
  kernel_source_profile = {
    test,
    meta ? {},
    ...
  }: {
    test = t:
      t.all [
        (test t)
        (t.type t.startsWith [
          "KERNEL_MODULE_"
          "UVM_MODULE_"
          "DKMS_CONF"
        ])
      ];

    meta =
      {
        # kernel sources distributed by nvidia include precompiled object files.
        sourceProvenance = with lib.sourceTypes; [fromSource binaryNativeCode];
      }
      // meta;
  };

  dylib_profile = {
    pname,
    test ? t: t.filePath t.basename t.startsWith pname,
    meta ? {},
    ...
  }: {
    inherit test;
    meta =
      meta
      // {
        sourceProvenance = with lib.sourceTypes; (meta.sourceProvenance or []) ++ [binaryNativeCode];
      };
  };
in {
  egl_glvnd_icd = {
    test = t: t.type t.eq "GLVND_EGL_ICD_JSON";
  };

  egl_platform_gbm = {
    test = t: t.filePath t.contains "_gbm";
  };

  egl_platform_wayland = {
    test = t: t.filePath t.contains "_wayland";
  };

  firmware = {
    test = t: t.module t.eq "gsp";

    meta = {
      sourceProvenance = with lib.sourceTypes; [binaryFirmware];
      license = lib.licenses.unfreeRedistributableFirmware;
    };
  };

  html-docs = {
    test = t: t.path t.eq "NVIDIA_GLX-1.0/html";
  };

  kmod-open = {
    test = t: t.filePath t.startsWith "kernel-open/";
  };

  kmod-unfree = {
    test = t: t.filePath t.startsWith ''\($header[0].kernel_module_build_dir)/'';
    profile = kernel_source_profile;
  };

  libcuda = {
    profile = dylib_profile;
  };

  test = {
    test = t: t.literal "error";
  };

  test2 = {
    test = t: "error";
  };
}
