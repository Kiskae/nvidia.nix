{ lib
, pkgs
, system
, callPackage
, linuxPackages
, nvidiaVersion
, distTarball
, enableCompat32 ? false
}:
let
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

  manifest = callPackage ../manifest {
    inherit sources;
  };
in
self: {
  supported =
    let
      versionAtLeast = lib.versionAtLeast nvidiaVersion;
      versionOlder = lib.versionOlder nvidiaVersion;
    in
    {
      gbm = versionAtLeast "495.29.05";
      firmware = versionAtLeast "465.19.01";
      # non-glvnd libGL
      libGL-nvidia = versionOlder "435.17";
      wayland = versionAtLeast "364.12";
      vulkan = versionAtLeast "364.12";
      libGL-glvnd = versionAtLeast "361.16";
      NvIFROpenGL = versionAtLeast "331.17" && versionOlder "495.29.05";
      vdpau = versionAtLeast "180.22";
      vdpau-wrapper = versionAtLeast "180.22" && versionOlder "361.16";
      cuda = versionAtLeast "169.07";
    };

  mkNvidiaPackage = callPackage ./mkPackage.nix {
    inherit manifest;
  };

  libnvidia-tls = self.mkNvidiaPackage {
    pname = "libnvidia-tls";
    category = "libnvidia-tls";
    outputs = [ "out" "lib32" ];
  };

  libcuda = self.mkNvidiaPackage {
    pname = "libcuda";
    category = "libcuda";
    outputs = [ "out" "lib32" ];
  };

  libnvidia-internal = self.mkNvidiaPackage {
    pname = "libnvidia-internal";
    category = "libnvidia_internal";
    outputs = [ "out" "lib32" ];
    autoPatchelfIgnoreMissingDeps = true;
  };

  testPkg = self.mkNvidiaPackage {
    pname = "testPkg";
    category = "_all";
    outputs = [ "out" "bin" "lib" "lib32" "dev" ];
    autoPatchelfIgnoreMissingDeps = true;

    buildInputs = with pkgs; [
      xorg.libX11
      xorg.libXext
      wayland
    ];

    fixupOutput = ''
      if [[ -d $prefix/lib ]]; then
        ldconfig -N $prefix/lib
      fi
    '';
  };

  kmod = self.callPackage ./kmod.nix {
    inherit linuxPackages;
    src = self.mkNvidiaPackage {
      pname = "kmod-sources";
      category = "kmod";

      # shuffle around source so it gets installed to the root of $out
      preInstall = ''
        tmp_dev=$NIX_BUILD_TOP/dev
        mkdir $tmp_dev
        outputDev=tmp_dev
      '';
      postInstall = ''
        mv $tmp_dev/src $out
      '';

      dontFixup = true;
    };
  };

  firmware = self.mkNvidiaPackage {
    pname = "nvidia-firmware";
    category = "firmware";

    postInstall = ''
      pushd $out/lib/firmware
      mv nvidia $version
      mkdir nvidia
      mv $version nvidia
      popd
    '';

    meta.broken = true;
  };

  pkgFarm = pkgs.linkFarm "package-list" (
    let
      mapOutputs = drv: map
        (output: {
          name = "${drv.name}${lib.optionalString (output != "out") "-${output}"}";
          path = lib.getOutput output drv;
        })
        drv.outputs;
    in
    lib.concatMap mapOutputs [
      sources
      manifest
      #self.libnvidia-tls
      #self.libcuda
      self.kmod
      #self.libnvidia-internal
      # self.firmware
      self.testPkg
      # linuxPackages.nvidia_x11_legacy470
      #linuxPackages.nvidia_x11_legacy470.settings
      #linuxPackages.nvidia_x11_legacy470.persistenced
      pkgs.mesa
      #pkgs.driversi686Linux.mesa
      pkgs.egl-wayland
      pkgs.libglvnd
      pkgs.wayland
      # pkgs.libvdpau
      pkgs.xorg.xf86videoati
    ]
  );
}
