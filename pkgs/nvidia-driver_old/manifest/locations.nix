{ match
  # string -> string -> x
,
}:
[
  {
    check = match "type" "*MANPAGE";
    prefix = "!outputMan";
    dir = "/share/man";
  }
  {
    check = match "type" [
      "*_BIN*"
      "NVIDIA_MODPROBE"
    ];
    prefix = "!outputBin";
    dir = "/bin";
  }
  {
    check = match "type" "INTERNAL_UTILITY_BINARY";
    prefix = "!outputLib";
    dir = "/libexec";
  }
  {
    check = match "type" "DOCUMENTATION";
    prefix = "!outputDoc";
    dir = "/share/doc";
  }
  {
    check = match "type" "*_STATIC_LIB";
    prefix = "!outputDev";
  }
  {
    # config.environment.systemPackages
    check = match "type" "DOT_DESKTOP";
    prefix = "!outputBin";
    dir = "/share/applications";
  }
  {
    check = match "src_path" "*.png";
    prefix = "!outputBin";
    dir = "/share/icons/hicolor/128x128/apps";
  }
  {
    check = match "type" "*_HEADER";
    prefix = "!outputInclude";
    dir = "/include";
  }
  {
    # services.xserver.modules
    check = match "type" "XORG_OUTPUTCLASS_CONFIG";
    dir = "/share/X11/xorg.conf.d";
  }
  {
    # pkgs.libglvnd
    check = match "type" "GLVND_EGL_ICD_JSON";
    dir = "/share/glvnd/egl_vendor.d";
  }
  {
    # libEGL_nvidia looks in "/etc/egl/egl_external_platform.d"
    check = match "type" "EGL_EXTERNAL_PLATFORM_JSON";
    dir = "/share/egl/egl_external_platform.d";
  }
  {
    # config.environment.etc."/etc/nvidia/nvidia-application-profiles-rc.d"
    check = match "type" "APPLICATION_PROFILE";
    # is this correct?
    dir = "/share/nvidia";
  }
  {
    # proton looks relative to libGLX_nvidia, after resolving symlinks
    # ./nvidia/wine/*.dll
    check = match "type" "WINE_LIB";
    dir = "/lib/nvidia/wine";
  }
  {
    # config.systemd.packages
    check = match "type" "SYSTEMD_UNIT*";
    dir = "/lib/systemd/system";
  }
  {
    # config.environment.etc."/etc/systemd/system-sleep"
    check = match "type" "SYSTEMD_SLEEP_SCRIPT";
    dir = "/lib/systemd/system-sleep";
  }
  {
    # pkgs.ocl-icd
    check = match "type" "CUDA_ICD";
    dir = "/etc/OpenCL/vendors";
  }
  {
    # config.hardware.firmware
    check = match "type" "FIRMWARE";
    dir = "/lib/firmware/nvidia";
  }
  {
    # config.services.dbus.packages (also environment.systemPackages)
    check = match "src_path" "nvidia-dbus.conf";
    prefix = "!outputLib";
    dir = "/share/dbus-1/system.d";
  }
  {
    # pkgs.mesa
    check = match "type" "GBM_BACKEND_LIB_SYMLINK";
    dir = "/lib/gbm";
    # links to either $allocator/lib or ${!outputLib}/lib
    ln_override = "\${allocator:-\${!outputLib}}/lib";
  }
  {
    # pkgs.vulkan-loader
    check = match "type" "VULKAN_ICD_JSON";
    dir = "/share/vulkan";
  }
  {
    check = match "category" [
      "kmod"
      "dkms"
    ];
    prefix = "!outputDev";
    dir = "/src";
  }
  {
    # services.xserver.modules
    check = match "category" "xserver.modules.*";
    dir = "/lib/xorg/modules";
  }
  # TODO: integrate this into code generation
  #{
  #  check = match "arch" "COMPAT32";
  #  prefix = "lib32";
  #}
]
