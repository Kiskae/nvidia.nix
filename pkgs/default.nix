{ lib, pkgs, callPackage, }:
let
  mapOutputs = drv: map
    (output: {
      name = "${drv.name}${lib.optionalString (output != "out") "-${output}"}";
      path = lib.getOutput output drv;
    })
    drv.outputs;
in
lib.recurseIntoAttrs (
  (callPackage ./nvidia-driver { }) //
  {
    runtime = lib.recurseIntoAttrs (callPackage ./runtime.nix { });
    samples = callPackage ./vulkan-samples.nix { };
    settings = callPackage ./nvidia-settings.nix { };
    egl_platform =
      let
        version = "1.1";
        src = pkgs.fetchFromGitHub {
          owner = "NVIDIA";
          repo = "eglexternalplatform";
          rev = version;
          hash = "sha256-C1qRfcq3AxWXh4eRMrkpgZ7T6+NRrwofEML+oLrQJVM=";
        };
      in
      pkgs.stdenvNoCC.mkDerivation {
        pname = "eglexternalplatform";
        inherit version src;

        # depends on EGL headers
        propagatedBuildInputs = [ pkgs.libGL ];

        nativeBuildInputs = [ pkgs.validatePkgConfig ];

        dontBuild = true;
        installPhase = ''
          install -D -t $out/include ./interface/*

          substituteInPlace ./eglexternalplatform.pc \
            --replace "/usr/include/EGL" "$out/include"
          echo "Requires.private: egl" >> ./eglexternalplatform.pc

          install -D -t $out/lib/pkgconfig ./eglexternalplatform.pc
        '';
      };
  }
)
