{ match
  # string -> (string | [ string ]) -> x
, all
  # ([ x ] | { * :: x }) -> x
, any
  # ([ x ] | { * :: x }) -> x
, not
  # x -> x
}: {
  # https://github.com/NVIDIA/libnvidia-container/blob/main/src/nvc_info.c
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
  glvnd = {
    drivers = match "src_path" [
      "*libGLX_nvidia.so.*"
      "*libEGL_nvidia.so.*"
      "*libGLESv2_nvidia.so.*"
      "*libGLESv1_CM_nvidia.so.*"
    ];
    # Not strictly part of GLVND, but needs to be available relative to 
    #    libGLX_nvidia.so.0
    # https://gitlab.steamos.cloud/steamrt/steam-runtime-tools/-/issues/71
    wine_dll = match "type" "WINE_LIB";
  };

  glvnd_egl_icd = match "type" "GLVND_EGL_ICD_JSON";

  vulkan_icd = match "type" "VULKAN_ICD_JSON";

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
      no_module = not (match "module" "*");
      not_vendored = not (match "src_path" "*_nvidia.so*");
    };
  };

  vdpau-driver = all [
    (match "type" "VDPAU_*")
    # some distributions include the vdpau vendor-neutral libs
    (not (match "type" "VDPAU_WRAPPER_*"))
  ];
  vdpau_wrapper = match "type" "VDPAU_WRAPPER_*";

  libnvidia-tls = match "type" "TLS_*";

  gbm_backend = match "type" "GBM_BACKEND_LIB_SYMLINK";

  libnvidia_internal = match "target_path" [
    "libnvidia-cbl*"
    "libnvidia-compiler*"
    "libnvidia-eglcore*"
    "libnvidia-glcore*"
    "libnvidia-glsi*"
    "libnvidia-glvkspirv*"
    "libnvidia-rtcore*"
    "libnvidia-allocator*"
  ];

  # README lists as internal, but the nvidia-persistenced
  ## daemon links against it
  libnvidia-cfg = match "target_path" "libnvidia-cfg*";

  libnvidia-vulkan-producer = match "target_path" "libnvidia-vulkan-producer*";

  opencl = any [
    (match "type" "OPENCL_WRAPPER_*")
    (match "target_path" "libOpenCL.so*")
  ];

  libnvidia-opencl = any {
    driver = match "target_path" "libnvidia-opencl.so.*";
    icd = match "type" "CUDA_ICD";
  };

  nvidia-settings = {
    program = match "src_path" "*nvidia-settings*";
    libnvidia-gtk = match "target_path" "libnvidia-gtk*";
    libnvidia-wayland-client = match "target_path" "libnvidia-wayland-client*";
  };

  libnvidia-nvvm = match "target_path" "libnvidia-nvvm.so*";
  libnvidia-fatbinaryloader = match "target_path" "libnvidia-fatbinaryloader.so*";
  libnvidia-ptxjitcompiler = match "target_path" "libnvidia-ptxjitcompiler.so*";
  libcuda = match "target_path" "libcuda.so*";

  html_docs = all [
    (match "target_path" "*.html")
    (match "type" "DOCUMENTATION")
  ];

  firmware = match "type" "FIRMWARE";

  libnvidia-ngx = {
    lib = match "target_path" "libnvidia-ngx.so.*";
    bin = match "target_path" "nvidia-ngx-updater";
  };

  libnvidia-opticalflow = match "module" "opticalflow";
  # Optix
  libnvoptix = match "module" "optix";
  app_profiles = match "type" "APPLICATION_PROFILE";

  # framebuffer capture
  libnvidia-fbc = match "target_path" "libnvidia-fbc.so*";
  # NVENC
  libnvidia-encode = match "type" "ENCODEAPI_*";
  # NVDEC
  libnvcuvid = match "target_path" "libnvcuvid.so*";
  # OpenGL framebuffer capture
  libnvidia-ifr = match "type" "NVIFR_*";

  nvidia-persistenced = all [
    (match "src_path" "nvidia-persistenced*")
    (not (match "target_path" "html/*"))
  ];
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

  nvidia-xconfig = match "src_path" "*nvidia-xconfig*";
  nvidia-modprobe = match "src_path" "*nvidia-modprobe*";
  nvidia-installer = match "src_path" "*nvidia-installer*";
  libnvidia-ml = match "target_path" "libnvidia-ml*";
  cuda-mpi = match "src_path" [
    "nvidia-cuda-mps-*"
    "nvidia-cuda-proxy-*"
  ];

  egl-wayland = match "target_path" [
    "libnvidia-egl-wayland.so.*"
    "10_nvidia_wayland.json"
  ];
  egl-gbm = match "target_path" [
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
    (not (match "target_path" [
      "supported-gpus/*"
    ]))
  ];

  dkms = match "type" "DKMS_CONF";

  grid_contrib_files = match "src_path" [
    "pci.ids"
    "monitoring.conf"
  ];
}
