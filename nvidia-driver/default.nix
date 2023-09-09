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
      version = "470.199.02";
      hash = "sha256-/fggDt8RzjLDW0JiGjr4aV4RGnfEKL8MTTQ4tCjXaP0=";
    };

    powerd_support = fetchNvidiaBinary {
      version = "510.39.01";
      hash = "sha256-Lj7cOvulhApeuRycIiyYy5kcPv3ZlM8qqpPUWl0bmRs=";
    };

    tesla535 = fetchurl {
      passthru = {
        version = "535.54.03";
      };
      url = "https://us.download.nvidia.com/tesla/535.54.03/NVIDIA-Linux-x86_64-535.54.03.run";
      hash = "sha256-RUdk9X6hueGRZqNw94vhDnHwYmQ4+xl/cm3DyvBbQII=";
    };

    vulkan_dev = fetchurl rec {
      passthru = {
        version = "535.43.09";
      };
      url = "https://developer.nvidia.com/downloads/vulkan-beta-${lib.concatStrings (lib.splitString "." passthru.version)}-linux";
      hash = "sha256-7QDp+VDgxH7RGW40kbQp4F/luh0DCYb4BS0gU/6wn+c=";
    };

    latest = fetchNvidiaBinary {
      version = "535.104.05";
      hash = "sha256-L51gnR2ncL7udXY2Y1xG5+2CU63oh7h8elSC4z/L7ck=";
    };
  }
