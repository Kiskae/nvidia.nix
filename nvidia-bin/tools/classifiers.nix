{ lib, vars, matchVariable, matchAny, matchAll, dontMatch, ... }:
let
  inherit (lib.attrsets) genAttrs attrVals;
  matchType = matchVariable vars.type;
  matchTargetPath = matchVariable vars.target_path;
  matchSourcePath = matchVariable vars.src_path;
  matchModules = modules: matchAny (map (matchVariable vars.module) modules);
  matchNoModule = matchVariable vars.module "\"\"";
  matchDynamicLibrary = name: matchTargetPath "${name}.so*";

  /**
    binaries with addition files; they have to have a common prefix as name
  */
  known_binaries = [
    /*
      The application nvidia-installer is NVIDIA's tool for installing and updating NVIDIA drivers.
    */
    "nvidia-installer"
    /*
      The application nvidia-modprobe is installed as setuid root and is used to load the NVIDIA kernel module and create the /dev/nvidia* device nodes by processes (such as CUDA applications) that don't run with sufficient privileges to do those things themselves.
    */
    "nvidia-modprobe"
    /*
      The application nvidia-xconfig is NVIDIA's tool for manipulating X server configuration files.
    */
    "nvidia-xconfig"
    /*
      The application nvidia-settings is NVIDIA's tool for dynamic configuration while the X server is running.
    */
    "nvidia-settings"
    /*
      The application nvidia-smi is the NVIDIA System Management Interface for management and monitoring functionality.
    */
    "nvidia-smi"
    /*
      The daemon nvidia-persistenced is the NVIDIA Persistence Daemon for allowing the NVIDIA kernel module to maintain persistent state when no other NVIDIA driver components are running.
    */
    "nvidia-persistenced"
    /*
      The nvidia-cuda-mps-control and nvidia-cuda-mps-server applications, which allow MPI processes to run concurrently on a single GPU.
    */
    "nvidia-cuda-mps"
    /*
      The application nvidia-debugdump is NVIDIA's tool for collecting internal GPU state. 
      It is normally invoked by the nvidia-bug-report.sh script.
    */
    "nvidia-debugdump"
    "nvidia-bug-report"
    /*
      NGX; and the NVIDIA NGX Updater; NGX is a collection of software which provides AI features to applications.
      On Linux this is supported only with x86_64 applications.
    */
    "nvidia-ngx-updater"
  ];
  /*
    matches the complete name of the dynamic library without extension, including soname symlinks
  */
  known_libraries = [
    /*
      The CUDA library which provides runtime support for CUDA (high-performance computing on the GPU) applications.
    */
    "libcuda"
    /*
      The PTX JIT Compiler library is a JIT compiler which compiles PTX into GPU machine code and is used by the CUDA driver.
    */
    "libnvidia-ptxjitcompiler"
    /*
      The NVVM Compiler library is loaded by the CUDA driver to do JIT link-time-optimization.
    */
    "libnvidia-nvvm"
    /*
      The nvidia-ml library; The NVIDIA Management Library provides a monitoring and management API. 
    */
    "libnvidia-ml"
    /*
      The NVCUVID library; The NVIDIA CUDA Video Decoder (NVCUVID) library provides an interface to hardware video decoding capabilities on NVIDIA GPUs with CUDA.
    */
    "libnvcuvid"
    /*
      The NvEncodeAPI library; The NVENC Video Encoding library provides an interface to video encoder hardware on supported NVIDIA GPUs.
    */
    "libnvidia-encode"
    /*
      The NvFBC library; The NVIDIA Framebuffer Capture library provides an interface to capture and optionally encode the framebuffer of an X server screen.
    */
    "libnvidia-fbc"
    /*
      The OptiX library; This library implements the OptiX ray tracing engine.
      It is loaded by the liboptix.so.* library bundled with applications that use the OptiX API.
    */
    "libnvoptix"
    /*
      The NVIDIA Optical Flow library; The NVIDIA Optical Flow library can be used for hardware-accelerated computation of optical flow vectors and stereo disparity values on Turing and later NVIDIA GPUs.
      This is useful for some forms of computer vision and image analysis.
      The Optical Flow library depends on the NVCUVID library, which in turn depends on the CUDA library.
    */
    "libnvidia-opticalflow"
    /*
      NGX; and the NVIDIA NGX Updater; NGX is a collection of software which provides AI features to applications.
      On Linux this is supported only with x86_64 applications.
    */
    "libnvidia-ngx"
    /*
      The NvIFROpenGL library; The NVIDIA OpenGL-based Inband Frame Readback library provides an interface to capture and optionally encode an OpenGL framebuffer.
    */
    "libnvidia-ifr"
    /*
      NOT_DOCUMENTED: helper library for wayland WSI / vulkan
    */
    "libnvidia-vulkan-producer"
    /*
      The Fatbinary Loader library provides support for the CUDA driver to work with CUDA fatbinaries.
      Fatbinary is a container format which can package multiple PTX and Cubin files compiled for different SM architectures.
    */
    "libnvidia-fatbinaryloader"
  ];
in
{
  classifiers = {
    /*
      A kernel module; this kernel module provides low-level access to your NVIDIA hardware for all of the above components. 
      It is generally loaded into the kernel when the X server is started, and is used by the X driver and OpenGL. 
      nvidia.ko consists of two pieces: the binary-only core, and a kernel interface that must be compiled specifically for your kernel version. 
      Note that the Linux kernel does not have a consistent binary interface like the X server, so it is important that this kernel interface be matched with the version of the kernel that you are using. 
      This can either be accomplished by compiling yourself, or using precompiled binaries provided for the kernels shipped with some of the more common Linux distributions.
    */
    kernel_nvidia = matchModules [ "resman" "nvlink" "nvswitch" ];
    /*
      NVIDIA Unified Memory kernel module; this kernel module provides functionality for sharing memory between the CPU and GPU in CUDA programs. 
      It is generally loaded into the kernel when a CUDA program is started, and is used by the CUDA driver on supported platforms.
    */
    kernel_nvidia_uvm = matchModules [ "uvm" ];
    /*
      A kernel module; this kernel module is responsible for programming the display engine of the GPU.
      User-mode NVIDIA driver components such as the NVIDIA X driver, OpenGL driver, and VDPAU driver communicate with nvidia-modeset.ko through the /dev/nvidia-modeset device file.
    */
    kernel_nvidia_modeset = matchModules [ "nvkms" ];
    /*
      UNDOCUMENTED: allows xserver to load the driver dynamically
    */
    kernel_nvidia_drm = matchModules [ "nvidia_drm" ];
    /*
      A kernel module; this kernel module allows Mellanox HCAs access to NVIDIA GPU memory read/write buffers without needing to copy data to host memory.
    */
    kernel_nvidia_peermem = matchModules [ "nvidia_peermem" ];
    /*
      legacy packaging, bundles all kernel modules into a single classification
    */
    kernel_legacy = matchAll {
      is_kernel = matchType "*_MODULE_SRC";
      and_no_modules = matchNoModule;
    };
    /*
      check that classifier doesn't trigger to make sure new kernel modules don't get missed.
    */
    assert_no_extra_kernel = matchSourcePath "kernel/*";
    /*
      packaged documentation, includes README, LICENCES and list of officially supported GPUs
    */
    documentation = matchType "DOCUMENTATION";
    /*
      NGX for Proton and Wine is a Microsoft Windows dynamic-link library used by Microsoft Windows applications which support NVIDIA DLSS.
    */
    wine_lib = matchType "WINE_LIB";
    /*
      Firmware which offloads tasks from the CPU to the GPU.
    */
    firmware = matchType "FIRMWARE";
    /*
      systemd suspend/hibernate units and dependencies, including nvidia-sleep.sh
    */
    systemd = matchAny {
      unit_files = matchType "SYSTEMD_UNIT*";
      supporting_files = matchSourcePath "systemd/*";
    };
    /*
      Various libraries that are used internally by other driver components.
    */
    libnvidia_internal = matchAny (map matchDynamicLibrary [
      "libnvidia-cbl"
      "libnvidia-cfg"
      "libnvidia-compiler"
      "libnvidia-eglcore"
      "libnvidia-glcore"
      "libnvidia-glsi"
      "libnvidia-glvkspirv"
      "libnvidia-rtcore"
      "libnvidia-allocator"
    ]);
    xorg_modules = matchAny (map matchType [
      /*
        A GLX extension module for X; this module is used by the X server to provide server-side GLX support.
      */
      "GLX_MODULE_*"
      /*
        An X driver; this driver is needed by the X server to use your NVIDIA hardware.

        -- 396.54 confirmed 
        An X module for wrapped software rendering; this module is used by the X driver to perform software rendering on GeForce 8 series GPUs.
        If libwfb.so already exists, nvidia-installer will not overwrite it.
        Otherwise, it will create a symbolic link from libwfb.so to libnvidia-wfb.so.XXX.XX.
      */
      "XMODULE_*"
      /*
        An X driver configuration file; If the X server is sufficiently new, this file will be installed to configure the X server to load the nvidia_drv.so driver automatically if it is started after the NVIDIA DRM kernel module (nvidia-drm.ko) is loaded. 
        This feature is supported in X.Org xserver 1.16 and higher when running on Linux kernel 3.13 or higher with CONFIG_DRM enabled.
      */
      "XORG_OUTPUTCLASS_CONFIG"
    ]);
    /*
      A VDPAU (Video Decode and Presentation API for Unix-like systems) library for the NVIDIA vendor implementation
    */
    libvdpau_vendor = matchTargetPath "*libvdpau_nvidia*";
    /*
      Three VDPAU (Video Decode and Presentation API for Unix-like systems) libraries: The top-level wrapper, a debug trace library.
      NOTE: vendor implementation split off into libvdpau_vendor
    */
    libvdpau_contrib = matchType "VDPAU_WRAPPER_*";
    /*
      GLVND vendor implementation libraries for GLX and EGL; these libraries provide NVIDIA implementations of OpenGL functionality which may be accessed using the GLVND client-facing libraries.
    */
    glvnd_vendor = matchAny (map matchDynamicLibrary [
      "libGLX_nvidia"
      "libEGL_nvidia"
      "libGLESv1_CM_nvidia"
      "libGLESv2_nvidia"
      # symlink to libGLX_nvidia
      "libGLX_indirect"
    ] ++ map matchType [
      "GLVND_EGL_ICD_JSON"
      /*
        might be nvidia_icd.json.template, in which case:
        substitute __NV_VK_ICD__ with a path to libGLX_nvidia
        rename to "nvidia_icd.json"
      */
      "VULKAN_ICD_JSON"
    ]);
    /*
      The nvidia-tls library; this file provides thread local storage support for the NVIDIA OpenGL libraries (libGLX_nvidia, libnvidia-glcore, and libglxserver_nvidia).

      NVIDIA's OpenGL libraries are compiled with one of two
      different thread local storage (TLS) mechanisms: 'classic
      tls' which is used on systems with glibc 2.2 or older, and
      'new tls' which is used on systems with tls-enabled glibc
      2.3 or newer.  nvidia-installer will select the OpenGL
      libraries appropriate for your system; however, you may use
      this option to force the installer to install one library
      type or another.  Valid values for FORCE-TLS are 'new' and
      'classic'.
    */
    libnvidia-tls = matchType "TLS_LIB";
    /*
      predefined application profiles
    */
    app_profiles = matchTargetPath "nvidia-application-profiles-${vars.version}-*";
    /*
      Two OpenCL libraries; the former is a vendor-independent Installable Client Driver (ICD) loader, and the latter is the NVIDIA Vendor ICD.
      A config file is also installed, to advertise the NVIDIA Vendor ICD to the ICD Loader.
    */
    libnvidia-opencl = matchAny [
      (matchDynamicLibrary "libnvidia-opencl")
      (matchType "CUDA_ICD")
    ];
    opencl_contrib = matchAny {
      named = matchType "OPENCL_WRAPPER_*";
      # older builds include the wrapper lib with cuda
      unnamed = matchAll {
        libName = matchSourcePath "libOpenCL.so.1*";
        for_cuda = matchType "CUDA_*";
      };
    };
    /*
      Vendor neutral graphics libraries provided by libglvnd; these libraries are currently used to provide full OpenGL dispatching support to NVIDIA's implementation of EGL.
    */
    glvnd_contrib = matchAll [
      (matchAny (map matchType [
        "GLVND_*"
        "GLX_CLIENT_*"
        "EGL_CLIENT_*"
      ]))
      (dontMatch (matchVariable vars.extra "NON_GLVND"))
    ];
    /*
      legacy opengl vendor implementation; can be used instead of glvnd
    */
    no_glvnd_vendor = matchAny {
      # distribution with both are explicitly marked
      dist_both = matchVariable vars.extra "NON_GLVND";
      # Otherwise they are mixed in with the vendor implementations
      only_dist = matchAll {
        # must not have libvn or nvidia in the name
        no_vendor = dontMatch (matchAny (map matchSourcePath [
          "*nvidia*"
          "*libnv*"
        ]));
        # marked as OPENGL_LIB / OPENGL_SYMLINK
        but_opengl = matchType "OPENGL_*";
      };
    };
    /*
      internal utility to check glvnd availbility during installation
    */
    glvnd_checker = matchType "INTERNAL_UTILITY_*";
    /*
      UNDOCUMENTED: 
    */
    gbm_backend = matchType "GBM_BACKEND_*";
    /*
      The libnvidia-gtk libraries; these libraries are required to provide the nvidia-settings user interface.
    */
    libnvidia-gtk = matchDynamicLibrary "libnvidia-gtk[23]";
    /*
      A Wayland EGL external platform library and its corresponding configuration file; this library provides client-side Wayland EGL application support using either dmabuf or EGLStream buffer sharing protocols, as well as server-side protocol extensions enabling the client-side EGLStream-based buffer sharing path.
      The EGLStream path can only be used in combination with an EGLStream-enabled Wayland compositor, e.g: https://gitlab.freedesktop.org/ekurzinger/weston.
    */
    wayland_egl = matchAny [
      (matchDynamicLibrary "libnvidia-egl-wayland")
      (matchTargetPath "10_nvidia_wayland.json")
    ];
    /*
      A GBM EGL external platform library and its corresponding configuration file; this library provides GBM EGL application support.
    */
    wayland_gbm = matchAny [
      (matchDynamicLibrary "libnvidia-egl-gbm")
      (matchTargetPath "15_nvidia_gbm.json")
    ];
    /*
      UNDOCUMENTED: OpenGL shared library and headers
    */
    opengl_contrib = matchAny (map matchType [
      "LIBGL_LA"
      "OPENGL_HEADER"
    ]);
    /*
      UNDOCUMENTED: appears to be related to the GRID-series GPUs, not sure
      why it is included in the public driver
    */
    grid_contrib_files = matchAny (map matchSourcePath [
      "pci.ids"
      "monitoring.conf"
    ]);
  } // genAttrs known_libraries matchDynamicLibrary
  // genAttrs known_binaries (name: matchSourcePath "${name}*");

  /*
    Since nix does not guarantee list or attrset order, we specifically list the order as a script
  */
  order = imports:
    let
      emitForTargets = targets: lib.strings.concatStringsSep "\n" (attrVals targets imports);
    in
    with imports; ''
      # known_binaries
      ${emitForTargets known_binaries}
      # known_libraries
      ${emitForTargets known_libraries}

      # run after known_binaries
      ${documentation}

      # kernel sources
      ${kernel_nvidia}
      ${kernel_nvidia_uvm}
      ${kernel_nvidia_modeset}
      ${kernel_nvidia_drm}
      ${kernel_nvidia_peermem}
      ${kernel_legacy}
      ${assert_no_extra_kernel}

      ${wine_lib}
      ${firmware}
      ${systemd}
      ${libnvidia_internal}
      ${libvdpau_vendor}
      ${libvdpau_contrib}
      ${xorg_modules}
      ${glvnd_vendor}
      ${glvnd_contrib}
      ${opengl_contrib}
      ${no_glvnd_vendor}
      ${libnvidia-tls}
      ${app_profiles}
      ${libnvidia-opencl}
      ${opencl_contrib}
      ${glvnd_checker}
      ${gbm_backend}
      ${libnvidia-gtk}
      ${wayland_egl}
      ${wayland_gbm}
      ${grid_contrib_files}
    '';
}
