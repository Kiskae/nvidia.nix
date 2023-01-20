{
  lib,
  buildPackages,
  pkgs,
  stdenv,
  fetchurl,
  jq,
}: let
  systemToNvidiaPlatform = system:
    {
      "x86_64-linux" = "Linux-x86_64";
      "i686-linux" = "Linux-x86";
      "aarch64-linux" = "Linux-aarch64";
      "armv7l-linux" = "Linux-armv7l-gnueabihf";
      "powerpc64le-linux" = "Linux-ppc64le";
      "x86_64-freebsd" = "FreeBSD-x86_64";
      "i686-freebsd" = "FreeBSD-x86";
    }
    .${system}
    or (throw "Unknown system '${system}'");

  defaultMirrors = system: let
    platform = systemToNvidiaPlatform system;
    withOverrides = overrides: overrides.${system} or platform;
  in [
    "https://download.nvidia.com/XFree86/${withOverrides {
      # https://download.nvidia.com/XFree86/Linux-32bit-ARM/
      "armv7l-linux" = "Linux-32bit-ARM";
    }}"
    "https://us.download.nvidia.com/XFree86/${withOverrides {
      # https://us.download.nvidia.com/XFree86/Linux-x86-ARM/
      "armv7l-linux" = "Linux-x86-ARM";
      # https://us.download.nvidia.com/XFree86/aarch64/
      "aarch64-linux" = "aarch64";
    }}"
  ];

  defaultPath = {
    system,
    version,
    suffix ? [],
  }: "${version}/${lib.concatStringsSep "-" ([
      "NVIDIA"
      (systemToNvidiaPlatform system)
      version
    ]
    ++ suffix)}.run";

  fetchNvidiaBinary = {
    version,
    system ? stdenv.hostPlatform.system,
    hash,
    suffix ? [],
    pathProvider ? defaultPath,
    mirrorProvider ? defaultMirrors,
  }:
    fetchurl {
      urls = let
        path = pathProvider {inherit system version suffix;};
      in
        map (mirror: "${mirror}/${path}") (mirrorProvider system);

      inherit hash;

      passthru = {
        inherit version;
      };
    };

  mkPackageSet = buildPackages.callPackage ./nvidia-installer;

  createPackages = pname: src: let
    components = mkPackageSet {
      inherit src;
    };
  in
    components.report;
in
  lib.mapAttrs createPackages {
    probe = fetchNvidiaBinary {
      version = "337.25";
      hash = "sha256-gygPdzj2W7LnkOdTCjiXjPC9CqdB7aUWKcnpsGgSivA=";
    };

    legacy71 = fetchNvidiaBinary {
      version = "71.86.15";
      hash = "sha256-ARBKXYBOIdPwiY8j0ss9/8i3gkUhdiaeBxymJdPhyUQ=";
      suffix = ["pkg2"];
    };

    legacy96 = fetchNvidiaBinary {
      version = "96.43.23";
      hash = "sha256-zo2CU+fat9pj+9rESevxkM0MEMv//qD40BZVFfhRvGQ=";
      suffix = ["pkg2"];
    };

    legacy173 = fetchNvidiaBinary {
      version = "173.14.39";
      hash = "sha256-FalTZm1WgbpUyXSYtXj/0oah3JbWBfOwIRDz+ZgTEA4=";
      suffix = ["pkg2"];
    };

    legacy304 = fetchNvidiaBinary {
      version = "304.137";
      hash = "sha256-6x9W2zor6hPjzN57WuFKvozWxtvmmvTHHGimI8yW4+I=";
    };

    legacy340 = fetchNvidiaBinary {
      version = "340.108";
      hash = "sha256-xnHU8bfAm8GvB5uYtEetsG1wSwT4AvcEWmEfpQEztxs=";
    };

    legacy390 = fetchNvidiaBinary {
      version = "390.157";
      hash = "sha256-W+u8puj+1da52BBw+541HxjtxTSVJVPL3HHo/QubMoo=";
    };

    tesla450 = fetchurl {
      passthru = {
        version = "450.216.04";
      };
      url = "https://us.download.nvidia.com/tesla/450.216.04/NVIDIA-Linux-x86_64-450.216.04.run";
      hash = "sha256-B+CrLBBnRqXpC0xY+VMLHuIYLWx6VdnsPYDRmC3oKAE=";
    };

    legacy470 = fetchNvidiaBinary {
      version = "470.161.03";
      hash = "sha256-Xagqf4x254Hn1/C+e3mNtNNE8mvU+s+avPPHHHH+dkA=";
    };

    tesla525 = fetchurl {
      passthru = {
        version = "525.60.13";
      };
      url = "https://us.download.nvidia.com/tesla/525.60.13/NVIDIA-Linux-x86_64-525.60.13.run";
      hash = "sha256-3OHBhPnwOL5yI3zNKcZrsVEHf2A38cFYyD1YK9LbqMo=";
    };

    vulkan_dev = fetchurl rec {
      passthru = {
        version = "525.47.04";
      };
      url = "https://developer.nvidia.com/downloads/vulkan-beta-${lib.concatStrings (lib.splitString "." passthru.version)}-linux";
      hash = "sha256-PcDRM39s4vh5++4TocIJKI3wsxWxJdy3p3KAenpdIc0=";
    };

    latest = fetchNvidiaBinary {
      version = "525.85.05";
      hash = "sha256-6mO0JTQDsiS7cxOol3qSDf6dID1mHdX2/CZYWnAXkUA=";
    };
  }
