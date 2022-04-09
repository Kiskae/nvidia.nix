{ lib, pkgs, newScope }:
let
  packageBuilder =
    let
      packageRequiresLibStdCpp = [
        "cuda_demo_suite"
        "cuda_gdb"
        "cuda_memcheck"
        "cuda_nvcc"
        "cuda_nvrtc"
        "cuda_nvtx"
        "fabricmanager"
        "libcublas"
        "libcufile"
        "libcusolver"
      ];
    in
    lib.makeOverridable (
      { pname
      , pkg
      , validatedVersions ? [ ]
        # mkDerivation inputs
      , buildInputs ? [ ]
      , nativeBuildInputs ? [ ]
      , installPhase ? "cp -r . $out"
      , autoPatchelfIgnoreMissingDeps ? lib.elem pkg.version validatedVersions
        # other options
      , injectStdLibCpp ? lib.elem pname packageRequiresLibStdCpp
      , stdenv ? pkgs.stdenv
      , extraArgs ? { }
      }: stdenv.mkDerivation ({
        inherit pname;
        inherit (pkg) version;

        src =
          let
            inherit (stdenv) system;
          in
            pkg.srcs.${system} or (throw "platform ${system} not supported for ${pname}");

        inherit installPhase autoPatchelfIgnoreMissingDeps;

        nativeBuildInputs = nativeBuildInputs ++ [ pkgs.autoPatchelfHook ];
        buildInputs = buildInputs ++ (
          lib.optional injectStdLibCpp (lib.getAttrFromPath [ "cc" "cc" "lib" ] stdenv)
        );

        meta = {
          platforms = lib.attrNames pkg.srcs;
        };
      } // extraArgs)
    );

  packageOverrides = self: super: {
    cuda_demo_suite = super.cuda_demo_suite.override {
      buildInputs = [
        self.libcufft
        self.libcurand
        pkgs.freeglut
        pkgs.libGLU
      ];
    };

    cuda_nvprof = super.cuda_nvprof.override {
      buildInputs = [ self.cuda_cupti ];
      validatedVersions = [
        "11.4.120"
        "11.6.112"
      ];
    };

    libcufile = super.libcufile.override {
      buildInputs = [
        pkgs.numactl
        pkgs.rdma-core
      ];

      validatedVersions = [
        "1.0.2.10"
        "1.2.1.4"
      ];

      extraArgs = {
        preFixup = ''
          ldconfig -n $out/lib $out/lib32
        '';
      };
    };

    libcusolver = super.libcusolver.override {
      buildInputs = [ self.libcublas ];
    };

    nsight_compute = with pkgs.libsForQt5; super.nsight_compute.override {
      stdenv = {
        inherit mkDerivation;
        inherit (super.nsight_compute) system;
      };

      buildInputs = [ qtwebengine ];
    };

    nsight_systems = with pkgs.libsForQt5; super.nsight_systems.override {
      stdenv = {
        inherit mkDerivation;
        inherit (super.nsight_systems) system;
      };

      validatedVersions = [
        "2021.3.2.4"
        "2021.5.2.53"
      ];

      buildInputs = [
        qtwebengine
        pkgs.e2fsprogs
        pkgs.libGL
      ];

      extraArgs = {
        # gets added to rpath, but doesnt fix issue...
        runtimeDependencies = [
          pkgs.udev
        ];

        prePatch = ''
          rm -v -r ./nsight-systems/*/host-linux-x64/Mesa
        '';
      };
    };

    nvidia_driver = super.nvidia_driver.override {
      buildInputs = with pkgs; [
        libGL
        libglibutil
        pango
        gtk3
        gtk2
        wayland
        xorg.libX11
        libdrm
        mesa
      ];

      extraArgs = {
        preFixup = ''
          ldconfig -n $out/lib $out/lib32
        '';
      };
    };
  };

  applyToManifest = manifest:
    let
      applyBuilder = f: pname: pkg: f { inherit pname pkg; };
      addPackages = cudaPkgs: lib.mapAttrs (applyBuilder packageBuilder) manifest.pkgs;
      cudaPkgs = lib.makeScope newScope addPackages;
    in
    cudaPkgs.overrideScope' packageOverrides;
in
applyToManifest
