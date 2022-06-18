{ match
  # string -> (string | [ string ]) -> x
, all
  # ([ x ] | { * :: x }) -> x
, any
  # ([ x ] | { * :: x }) -> x
, not
  # x -> x
}: {
  kmod = match "type" [
    "KERNEL_MODULE_*"
    "UVM_MODULE_*"
  ];
  xserver = {
    modules = {
      driver = match "type" "XMODULE_*";
      glx_module = match "type" "GLX_MODULE_*";
      xvmc = match "type" "XLIB_*";
      legacy = match "type" "XFREE86_*";
    };
    drm_conf = match "type" "XORG_OUTPUTCLASS_CONFIG";
  };
  glvnd = any {
    drivers = match "target_path" [
      "libGLX_nvidia.so.*"
      "libEGL_nvidia.so.*"
      "libGLX_indirect.so.0"
      "libGLESv2_nvidia.so.*"
      "libGLESv1_CM_nvidia.so.*"
    ];
    icd = match "type" "GLVND_EGL_ICD_JSON";
  };

  libGL-glvnd = any {
    # when shipping both glvnd and non-glvnd versions
    both_shipped = match "extra" "GLVND";
    # match the GLVND_* types, except for the glvnd ICD config file
    marked_by_type = all [
      (match "type" "GLVND_*")
      (not (match "type" "GLVND_EGL_ICD_JSON"))
    ];
    # if not explicitly marked
    other = all {
      files = any [
        (match "type" "EGL_CLIENT_*")
        (match "type" "GLX_CLIENT_*")
      ];
      libgl-nvidia = not (match "extra" "NON_GLVND");
      has_module = match "module" "opengl";
    };
  };

  # non-glvnd libGL
  libGL-nvidia = any {
    opengl_headers = match "type" "OPENGL_HEADER";
    not_glvnd = match "extra" "NON_GLVND";
    libtool = match "type" "LIBGL_LA";
    other = all {
      type = match "type" "OPENGL_*";
      not_internal = not (match "target_path" "libnvidia-*");
      no_module = match "module" "\"\"";
      not_vendored = not (match "src_path" "*_nvidia.so*");
    };
  };

  vdpau = all [
    (match "type" "VDPAU_*")
    # some distributions include the vdpau vendor-neutral libs
    (not (match "type" "VDPAU_WRAPPER_*"))
  ];
  vdpau_wrapper = match "type" "VDPAU_WRAPPER_*";

  libnvidia-tls = match "type" "TLS_*";

  gbm_backend = match "type" "GBM_BACKEND_LIB_SYMLINK";
  vulkan_icd = match "type" "VULKAN_ICD_JSON";

  internal_libraries = match "target_path" [
    "libnvidia-cbl*"
    "libnvidia-cfg*"
    "libnvidia-compiler*"
    "libnvidia-eglcore*"
    "libnvidia-glcore*"
    "libnvidia-glsi*"
    "libnvidia-glvkspirv*"
    "libnvidia-rtcore*"
    "libnvidia-allocator*"
  ];

  internal_vulkan_producer = match "target_path" "libnvidia-vulkan-producer*";

  opencl = any [
    (match "type" "OPENCL_WRAPPER_*")
    (match "target_path" "libOpenCL.so*")
  ];

  opencl_driver = any {
    driver = match "target_path" "libnvidia-opencl.so.*";
    icd = match "type" "CUDA_ICD";
  };

  NVVM = match "target_path" "libnvidia-nvvm.so*";
  Fatbinary_Loader = match "target_path" "libnvidia-fatbinaryloader.so*";
  PTX_JIT = match "target_path" "libnvidia-ptxjitcompiler.so*";
  cuda = match "target_path" "libcuda.so*";

  html_docs = all [
    (match "target_path" "*.html")
    (match "type" "DOCUMENTATION")
  ];
  wine_dll = match "type" "WINE_LIB";
  firmware = match "type" "FIRMWARE";

  ngx = any {
    lib = match "target_path" "libnvidia-ngx.so.*";
    bin = match "target_path" "nvidia-ngx-updater";
  };

  optical_flow = match "module" "opticalflow";
  OptiX = match "module" "optix";
  app_profiles = match "type" "APPLICATION_PROFILE";

  NvFBC = match "target_path" "libnvidia-fbc.so*";
  NvEncodeAPI = match "type" "ENCODEAPI_*";
  NVCUVID = match "target_path" "libnvcuvid.so*";
  NvIFROpenGL = match "type" "NVIFR_*";

  nvidia-persistenced = match "src_path" "nvidia-persistenced*";
  nvidia-powerd = match "module" "powerd";
  nvidia-bug-report = match "target_path" [
    "nvidia-debugdump"
    "nvidia-bug-report.sh"
  ];
  systemd = any [
    (all [
      (match "type" "SYSTEMD_*")
      (match "module" "installer")
    ])
    (match "target_path" "nvidia-sleep.sh")
  ];

  nvidia-smi = all [
    (match "src_path" "*nvidia-smi*")
    (not (match "target_path" "*/nvidia-smi.html"))
  ];

  libnvidia-gtk = match "target_path" "libnvidia-gtk*";
  nvidia-settings = match "src_path" "*nvidia-settings*";
  nvidia-xconfig = match "src_path" "*nvidia-xconfig*";
  nvidia-modprobe = match "src_path" "*nvidia-modprobe*";
  nvidia-installer = match "src_path" "*nvidia-installer*";
  libnvidia-ml = match "target_path" "libnvidia-ml*";
  cuda-mpi = match "src_path" [
    "nvidia-cuda-mps-*"
    "nvidia-cuda-proxy-*"
  ];

  egl_wayland = match "target_path" [
    "libnvidia-egl-wayland.so.*"
    "10_nvidia_wayland.json"
  ];
  egl_gbm = match "target_path" [
    "libnvidia-egl-gbm.so.*"
    "15_nvidia_gbm.json"
  ];

  supported-gpus = match "src_path" "supported-gpus/*";

  installer_utils = match "type" "INTERNAL_UTILITY_*";
  misc_documentation = all [
    (match "type" "DOCUMENTATION")
    (match "src_path" [
      "*NVIDIA_Changelog"
      "LICENSE"
      "*README*"
      "*/include/GL/gl*"
      "*/XF86Config.sample"
    ])
  ];
  dkms = match "type" "DKMS_CONF";
  grid_contrib_files = match "src_path" [
    "pci.ids"
    "monitoring.conf"
  ];
}
