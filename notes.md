dev snippet
```nix
args:
let
  src = fetchNvidiaBinary args;
  packageSet = packagesFor src;
in
runCommand "check-classifier"
{
  inherit (packageSet) manifest kernel_sources;
  inherit (src) version;
  libnvidia_internal = lib.getLib packageSet.libnvidia_internal;
  nativeBuildInputs = [ tools.classifierHook ];
  classes = tools.classifierHook.known-classifiers;
  stdenv = stdenvNoCC;
  binary_source = src;
} ''
  source $stdenv/setup

  manifest_entry () {
      classifier="UNCLASSIFIED"
      runClassifier $@ || true
      echo "$@" >> "$out/results/$classifier.txt"
  }

  mkdir -p $out/results
  source $manifest

  ln -s $binary_source $out/binary_source
  ln -s $manifest $out/manifest
  ln -s $new_classifier $out/classifier_definition

  ln -s $kernel_sources $out/kernel_src
  ln -s $libnvidia_internal $out/internal_libs

  echo $classes > $out/known_classifiers
''
```

Special nvidia releases:
```nix



{
  packages = {
    update-script = pkgs.callPackage ./update.nix { };
    nvidia-bin-x86 = buildNvidiaBinary {
      version = "390.144";
      arch = "x86";
      sha256 = "0c5vdgmhm6sard1fjbvlyiqp7sydihm9m1bxv8ggh0zizh8nsn7s";
    };
    nvidia-bin-oooold = buildNvidiaBinary {
      version = "340.108";
      arch = "x86";
      sha256 = "sha256-IDKq1hLZ868a7Pl5z9/kI9eap2kp74v406QDB29QfMo=";
    };
    nvidia-bin-aarch64 = buildNvidiaBinary {
      version = "470.86";
      arch = "aarch64";
      sha256 = "02xv7mqv7ly6gjy7ncq54vbm0513vxfkwsq5z2pprnkjdhkhr5av";
    };

    nvidia-beta = buildNvidiaBinary {
      version = "495.29.05";
      arch = "x86_64";
      sha256 = "sha256-9yVLl9QAxpJQR5ZJb059j2TpOx4xxCeGCk8hmhhvEl4=";
    };

    nvidia-430 = buildNvidiaBinary {
      version = "430.64";
      arch = "x86_64";
      sha256 = "1k5s05a7yvrms97nr3gd8cbvladn788qamsmwr6jsmdzv6yh5gvk";
    };

    nvidia-vulkan_beta = buildNvidiaBinary {
      version = "470.62.07";
      arch = "x86_64";
      sha256 = "sha256-nus1BLf8XL06LVXpdrwCE3TeKEfZGHvpfLL+f8CtXPU=";
      urlBuilder = { version, ... }: "https://developer.nvidia.com/vulkan-beta-${lib.concatStrings (lib.splitString "." version)}-linux";
    };

    nvidia-weird-xorg = buildNvidiaBinary {
      version = "396.54";
      arch = "x86_64";
      sha256 = "1hzfx4g63h6wbbjq9w4qnrhmvn8h8mmcpy9yc791m8xflsf3qgkw";
    };
  };
}
```

### update script
firefox update script: https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/browsers/firefox-bin/update.nix
http://download.nvidia.com/XFree86/
https://github.com/aaronp24/nvidia-versions

### stdenv.hostplatform
https://github.com/NixOS/nixpkgs/blob/master/lib/systems/inspect.nix

### patchelf
packaging binaries: https://nixos.wiki/wiki/Packaging/Binaries
autopatchelf: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/auto-patchelf.sh

### multi-outputs
https://nixos.org/manual/nixpkgs/stable/#chap-multiple-output

### packaging driver
https://github.com/NVIDIA/yum-packaging-nvidia-driver
https://github.com/NVIDIA/yum-packaging-precompiled-kmod
https://github.com/NVIDIA/ubuntu-packaging-nvidia-driver
https://negativo17.org/nvidia-driver/ (fedora)
https://negativo17.org/category/nvidia/
https://github.com/negativo17/nvidia-driver/blob/master/nvidia-generate-tarballs.sh
https://github.com/negativo17/nvidia-driver/blob/master/nvidia-driver.spec
https://github.com/Frogging-Family/nvidia-all/blob/master/PKGBUILD

### nixpkgs old impl
https://github.com/NixOS/nixpkgs/tree/master/pkgs/os-specific/linux/nvidia-x11
https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/video/nvidia.nix
https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/add-opengl-runpath/setup-hook.sh

### packaging misc
https://github.com/NVIDIA/ubuntu-packaging-nvidia-settings
https://github.com/NVIDIA/yum-packaging-nvidia-settings

### installed components
https://download.nvidia.com/XFree86/Linux-x86_64/352.79/README/installedcomponents.html
https://download.nvidia.com/XFree86/Linux-x86_64/340.108/README/installedcomponents.html
https://download.nvidia.com/XFree86/Linux-x86_64/510.60.02/README/installedcomponents.html

#
https://github.com/aaronp24/nvidia-versions

https://devhints.io/bash#conditionals
https://hackage.haskell.org/package/shell-monad-0.6.10/docs/Control-Monad-Shell.html#t:Arith

validating functionality:
https://github.com/nvpro-samples