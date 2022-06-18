{ lib
, stdenv
, fetchFromGitHub
, fetchpatch
, pkg-config
, m4
, autoPatchelfHook
, addOpenGLRunpath
, wrapGAppsHook
, libGL
, libvdpau
, libXext
, libX11
, wayland
, libXrandr
, libXxf86vm
, libXv
, gtk2
, gtk3
, librsvg
, dbus
, jansson
}:
let
  version = "515.48.07";
  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nvidia-settings";
    rev = version;
    sha256 = "sha256-XwdMsAAu5132x2ZHqjtFvcBJk6Dao7I86UksxrOkknU="; #lib.fakeSha256; # "sha256-4TBA/ITpaaBiVDkpj7/Iydei1knRPpruPL4fRrqFAmU=";
  };

  # these dependencies get dynamically loaded
  runtimeDependencies = [
    # libXv
    libXv
    # libXrandr
    libXrandr
    # libGL/libEGL
    libGL
    # libvdpau
    libvdpau
  ];
in
stdenv.mkDerivation {
  pname = "nvidia-settings";
  inherit src version;

  outputs = [ "out" "dev" ];

  makeFlags = [
    "NV_USE_BUNDLED_LIBJANSSON=0"
  ];

  nativeBuildInputs = [ pkg-config m4 autoPatchelfHook wrapGAppsHook ];

  propagatedBuildInputs = [
    libX11
    libXext
  ];

  buildInputs = [
    libXxf86vm
    jansson
    dbus
    gtk3
    gtk2
    librsvg
    wayland
  ] ++ runtimeDependencies;

  # while libXNVCtrl is shipped with nvidia-settings, the binary isn't required
  propagatedBuildOutputs = [ ];
  outputDoc = "dev";

  installFlags = [ "PREFIX=$(out)" ];
  postInstall = ''
    # there isn't really a reason to use the gtk2 version
    rm $out/lib/*gtk2*

    # XDG files
    install -D -t $out/share/applications/ doc/nvidia-settings.desktop
    install -D -t $out/share/icons/hicolor/128x128/apps/ doc/nvidia-settings.png

    # X-NV-CONTROL library, headers and docs
    install -D -t $dev/lib/ $(find src -name "libXNVCtrl.a")
    install -D -t $dev/include/NVCtrl/ src/libXNVCtrl/NVCtrl*.h 
    install -D -t $dev/share/doc/ doc/{NV-CONTROL-API,FRAMELOCK}.txt
    
    #TODO: copy samples?
  '';

  ldLibraryPath = lib.makeLibraryPath (runtimeDependencies ++ [
    # libnvidia-gtk3
    (placeholder "out")

    # libnvidia-ml
    addOpenGLRunpath.driverLink
  ]);

  preFixup = ''
    gappsWrapperArgs+=(--suffix LD_LIBRARY_PATH : $ldLibraryPath)
  '';

  postFixup = ''
    sed -i $out/share/applications/nvidia-settings.desktop \
      -e "s|^Exec=.*$|Exec=nvidia-settings|" \
      -e "s|^Icon=.*$|Icon=nvidia-settings|" \
      -e "s|__NVIDIA_SETTINGS_DESKTOP_CATEGORIES__|Settings;HardwareSettings;GTK;|"
  '';

  enableParallelBuilding = true;
}
