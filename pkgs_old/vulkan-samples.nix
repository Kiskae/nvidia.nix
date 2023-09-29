{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  fetchFromGitHub,
  xorg,
  libGLU,
  python3,
  autoPatchelfHook,
  vulkan-loader,
  wayland,
  writeScript,
  makeWrapper,
}: let
  fix-env = writeScript "make-env.sh" ''
    dir=$(mktemp -d --tmpdir vulkan_env.XXXXXX)
    ln -s -T $PWD $dir/output
    ln -s -t $dir $1/share/{assets,shaders}
    echo $dir
  '';
in
  stdenv.mkDerivation rec {
    name = "vulkan_samples";

    src = fetchFromGitHub {
      owner = "KhronosGroup";
      repo = "Vulkan-Samples";
      rev = "a3202c902ab4cde2a462f55756ef6342756ee616";
      sha256 = "sha256-hC+PZLnnsQuwHOmT4oOxLAk0Yk8NQPymrzYjQlsgQ4s=";
      fetchSubmodules = true;
    };

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
      python3
      autoPatchelfHook
      makeWrapper
    ];

    installPhase = ''
      mkdir -p $out/{bin,share}
      # copy over cli
      find app/bin/ -name "$name" | xargs cp -t $out/bin
      # copy over assets and shaders so wrapper can link to them
      cp -R -t $out/share $NIX_BUILD_TOP/$sourceRoot/{assets,shaders}
    '';

    postFixup = ''
      wrapProgram $out/bin/$name \
        --run "cd \$(${fix-env} $out)"
    '';

    runtimeDependencies = with xorg; [
      # used by GLFW to load X11 windows
      libX11
      libXxf86vm
      libXi
      libXrandr
      libXcursor
      libXinerama
      libxcb
      libXrender
      libXext
      # vulkan driver loader
      vulkan-loader
      # used by GLFW to load wayland windows
      wayland
    ];

    buildInputs = with xorg;
      [
        libXdmcp
        libGLU
        stdenv.cc.cc.lib
      ]
      ++ runtimeDependencies;
  }
