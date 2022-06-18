{ match
  # string -> string -> x
,
}:
[
  {
    check = match "arch" "COMPAT32";
    prefix = "lib32";
  }
  {
    check = match "type" "MANPAGE";
    prefix = "!outputMan";
    dir = "/share/man";
  }
  {
    check = match "type" "XORG_OUTPUTCLASS_CONFIG";
    dir = "/share/X11/xorg.conf.d";
  }
  {
    check = match "type" "GLVND_EGL_ICD_JSON";
    dir = "/share/glvnd/egl_vendor.d";
  }
  {
    check = match "type" "GBM_BACKEND_LIB_SYMLINK";
    dir = "/lib/gbm";
    # links to either $allocator/lib or ${!outputLib}/lib
    ln_override = "$''{allocator:-$''{!outputLib}}/lib";
  }
  {
    check = match "type" "VULKAN_ICD_JSON";
    dir = "/share/vulkan";
  }
  {
    check = match "type" "*_BIN*";
    prefix = "!outputBin";
    dir = "/bin";
  }
  {
    check = match "category" "kmod";
    dir = "/.";
  }
  {
    check = match "category" "xserver.modules.*";
    dir = "/lib/xorg/modules";
  }
]
