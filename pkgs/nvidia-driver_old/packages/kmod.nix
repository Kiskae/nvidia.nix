{ lib
, src
, version ? src.version
, enableLegacyBuild ? !(lib.versionAtLeast version "390")
  # compatibility with the pre-KBuild makefile
, ignoreRtCheck ? false
  # whether to allow the driver to compile for realtime kernels
, disabledModules ? [ ]
  # list of kernel modules to NOT build
, linuxPackages
, kernel ? linuxPackages.kernel
  # override linuxPackages or kernel
}: kernel.stdenv.mkDerivation ({
  name = "nvidia-kmod-${version}-${kernel.version}";

  inherit version src kernel;

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  outputs = [ "out" "dev" ];

  NV_EXCLUDE_KERNEL_MODULES = [ ]; # [ "nvidia-peermem" ] ++ disabledModules;
  NV_VERBOSE = 1;

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
  postInstall = ''
    install -D -t $dev/src/nvidia-${version}/${kernel.modDirVersion}/ Module*.symvers
  '';

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
