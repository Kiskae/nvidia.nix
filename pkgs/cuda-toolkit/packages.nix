{ lib, pkgs, newScope, stdenv, autoPatchelfHook }:
let
  baseDefinition = pname: { version, ... }@pkg: self:
    let
      inherit (self.stdenv) system;
      src = pkg.src.${system} or (throw "platform ${system} not supported for ${pname}");
    in
    {
      inherit stdenv;
      supportedByPlatform = pkg.src ? ${system};

      includeLibCpp = false;
      autoPatchelfIgnoreMissingDeps = false;

      nativeBuildInputs = [ autoPatchelfHook ];
      buildInputs = lib.optional self.includeLibCpp self.stdenv.cc.cc.lib;
      installPhase = "cp -r . $out";

      derivationArgs = {
        inherit pname version src;

        inherit (self) autoPatchelfIgnoreMissingDeps nativeBuildInputs buildInputs installPhase;

        meta = with lib; {
          description = pkg.name;
          # license = licenses.unfree;
          homepage = "https://docs.nvidia.com/cuda/";
          platforms = attrNames pkg.src;
        };
      };

      drv = self.stdenv.mkDerivation self.derivationArgs;
    };

  packageOverrides = {
    cuda_memcheck = _: {
      includeLibCpp = true;
    };
    cuda_nvtx = _: {
      includeLibCpp = true;
    };
    cuda_nvprof = x: {
      includeLibCpp = true;
      # libcuda
      autoPatchelfIgnoreMissingDeps = true;
    };
    cuda_demo_suite = x: {
      includeLibCpp = true;
      # libcufft, libcurand
      autoPatchelfIgnoreMissingDeps = true;
      buildInputs = x.buildInputs ++ [ pkgs.freeglut pkgs.libGLU ];
    };
    cuda_nvrtc = x: {
      includeLibCpp = true;
    };
    cuda_gdb = x: {
      includeLibCpp = true;
    };
    cuda_nvcc = x: {
      includeLibCpp = true;
    };
    fabricmanager = x: {
      includeLibCpp = true;
    };
    libcufile = x: {
      includeLibCpp = true;
      # libcuda
      autoPatchelfIgnoreMissingDeps = true;
      buildInputs = x.buildInputs ++ (with pkgs; [
        numactl
        rdma-core
      ]);
      installPhase = ''
        ${x.installPhase}
        ldconfig -n $out/lib $out/lib32
      '';
    };
    libcusolver = x: {
      includeLibCpp = true;
      # libcublasLt, libcublas
      autoPatchelfIgnoreMissingDeps = true;
    };
    libcublas = x: {
      includeLibCpp = true;
    };
    nsight_compute = x: with pkgs.libsForQt5.qt5; {
      nativeBuildInputs = x.nativeBuildInputs ++ [ wrapQtAppsHook ];
      # bundles QtWebEngineProcess, but not the actual dynamic libraries?
      buildInputs = x.buildInputs ++ [ qtwebengine ];
    };
    nsight_systems = x: with pkgs.libsForQt5.qt5; {
      # libcuda
      autoPatchelfIgnoreMissingDeps = true;
      nativeBuildInputs = x.nativeBuildInputs ++ [ wrapQtAppsHook ];
      buildInputs = x.buildInputs ++ [ qtwebengine ];
      derivationArgs = x.derivationArgs // {
        runtimeDependencies = [ pkgs.udev ];
      };
    };
    nvidia_fs = x: {
      derivationArgs = x.derivationArgs // {
        setSourceRoot = "sourceRoot=$(dirname $(find . -name 'configure'))";
      };
    };
    nvidia_driver = x: {
      buildInputs = x.buildInputs ++ (with pkgs; [
        libGL
        libglibutil
        pango
        gtk3
        gtk2
        wayland
        xorg.libX11
        libdrm
        mesa
      ]);
      installPhase = ''
        ${x.installPhase}
        ldconfig -n $out/lib $out/lib32
      '';
    };
  };
in
{ manifest # path to redistributable manifest 
,
}:
let
  resolvedPackages = lib.mapAttrs
    (pname: data:
      let
        pkg = lib.makeExtensible (baseDefinition pname data);
      in
      if packageOverrides ? ${pname} then
        pkg.extend (lib.const packageOverrides.${pname})
      else
        pkg
    )
    manifest.pkgs;
in
(lib.mapAttrs (_: x: x.drv) (lib.filterAttrs (_: x: x.supportedByPlatform) resolvedPackages)) // {
  recurseForDerivations = true;
}
