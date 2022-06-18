{ lib, callPackage, fetchurl }:
let
  nvidiaLicense = {
    shortName = "nvidia";
    fullName = "This License For Customer Use of NVIDIA Software";
    url = "https://www.nvidia.com/en-us/drivers/nvidia-license/";
    free = false;
    redistributable = true;
  };

  tmpMkPackages = { version, hash, url }: callPackage ./runfile {
    distTarball = fetchurl {
      inherit url hash;
      passthru = {
        inherit version;
      };
      meta = {
        license = nvidiaLicense;
        sourceProvenance = lib.sourceTypes.binaryNativeCode;
      };
    };
  };
in
{
  driver = tmpMkPackages rec {
    version = "515.48.07";
    hash = "sha256-4odkzFsTwy52NwUT2ur8BcKJt37gURVSRQ8aAOMa4eM=";
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}.run";
  };

  driver_oldest = tmpMkPackages rec {
    version = "390.151";
    hash = "sha256-UibkhCBEz/2Qlt6tr2iTTBM9p04FuAzNISNlhLOvsfw=";
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}.run";
  };

  driver_weird = tmpMkPackages rec {
    version = "340.108";
    hash = "sha256-xnHU8bfAm8GvB5uYtEetsG1wSwT4AvcEWmEfpQEztxs=";
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}.run";
  };

  driver_ancient = tmpMkPackages rec {
    version = "71.86.15";
    hash = "sha256-ARBKXYBOIdPwiY8j0ss9/8i3gkUhdiaeBxymJdPhyUQ=";
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}-pkg2.run";
  };
}
