{ lib, pkgs, callPackage, stdenvNoCC, fetchurl }:
let
  lookupSavedHash =
    let
      hashes = lib.importJSON ./hashes.json;
      archWithSuffix = system: suffix: "${system}${lib.optionalString (suffix != "") "+"}${suffix}";
    in
    { version
    , system
    , suffix ? ""
    , defaultHash ? (throw "no hash found for '${version}'.'${archWithSuffix system suffix}'")
    }: lib.attrByPath
      [ version (archWithSuffix system suffix) ]
      defaultHash
      hashes;

  mkPackageSet1 = callPackage ./packages.nix { };
  mkPackageSet = { version, src }: lib.makeScope
    pkgs.newScope
    (callPackage ./packages {
      nvidiaVersion = version;
      distTarball = src;
      linuxPackages = pkgs.linuxPackages_zen;
      enableCompat32 = true;
    });
  mkPackageSetFor = args: (mkPackageSet args).pkgFarm;

  mapSystemToNvidiaPlatform = system: {
    "x86_64-linux" = "x86_64";
    "i686-linux" = "x86";
    "aarch64-linux" = "aarch64";
    "armv7l-linux" = "armv7l-gnueabihf";
  }.${system} or (throw "");

  teslaMirrors = lib.const [
    "https://us.download.nvidia.com/tesla/"
  ];

  regularMirrors = arch:
    let
      # replace with attrByPath
      d = rec {
        # https://download.nvidia.com/XFree86/Linux-x86_64/
        global = "Linux-${arch}";
        # https://us.download.nvidia.com/XFree86/Linux-x86_64/
        us = global;
      } // (
        # override for specific architectures
        {
          "armv7l-gnueabihf" = {
            # https://download.nvidia.com/XFree86/Linux-32bit-ARM/
            global = "Linux-32bit-ARM";
            # https://us.download.nvidia.com/XFree86/Linux-x86-ARM/
            us = "Linux-x86-ARM/";
          };
          "aarch64" = {
            # https://us.download.nvidia.com/XFree86/aarch64/
            us = arch;
          };
        }.${arch} or { }
      );
    in
    [
      "https://download.nvidia.com/XFree86/${d.global}/"
      "https://us.download.nvidia.com/XFree86/${d.us}/"
    ];

  mkChannelPackage =
    let
      defaultUrlProvider = mirrorProvider:
        { version
        , system
        , suffix ? ""
        }:
        let
          arch = mapSystemToNvidiaPlatform system;
          # 340.108/NVIDIA-Linux-armv7l-gnueabihf-340.108.run
          path = "${version}/${lib.concatStringsSep "-" ([
            "NVIDIA-Linux"
            arch
            version
          ] ++ lib.optional (suffix != "") suffix)}.run";
        in
        map (m: "${m}${path}") (mirrorProvider arch);
    in
    { version
    , suffix ? lib.optionalString (!(lib.versionOlder "200" version)) "pkg2"
    , downloadMirrors ? regularMirrors
    , urlsProvider ? defaultUrlProvider downloadMirrors
    }: mkPackageSetFor {
      inherit version;
      src = fetchurl {
        urls = urlsProvider {
          inherit version suffix;
          system = "x86_64-linux";
        };
        sha256 = lookupSavedHash {
          inherit version suffix;
          defaultHash = lib.fakeSha256;
          system = "x86_64-linux";
        };
      };
    };

  channels =
    let
      inherit (lib) listToAttrs importJSON nameValuePair concatStringsSep optionals;
      mapChannel = { channel, status, version }:
        let
          simplifyVersion = x: lib.elemAt (lib.splitString "." x) 0;
          name = lib.concatStringsSep "_" (
            lib.singleton (if channel == "current" then "latest" else "legacy") ++
            lib.optional (channel != "current") (simplifyVersion channel) ++
            {
              "official" = [ ];
              "long-lived-branch-release" = [ "production" ];
            }.${status} or [ status ]
          );
        in
        nameValuePair name (mkChannelPackage { inherit version; });
    in
    listToAttrs (map mapChannel (importJSON ./channels.json));
in
channels // {
  tesla = mkPackageSetFor rec {
    version = "510.47.03";
    src = fetchurl {
      url = "https://us.download.nvidia.com/tesla/${version}/NVIDIA-Linux-aarch64-${version}.run";
      sha256 = lookupSavedHash {
        inherit version;
        system = "aarch64-linux";
      };
    };
  };
  old = mkChannelPackage {
    version = "1.0-6106";
    suffix = "pkg2";
  };
  vulkan_beta = mkPackageSetFor rec {
    version = "470.62.22";
    src = fetchurl {
      url = "https://developer.nvidia.com/vulkan-beta-4706222-linux";
      sha256 = "sha256-ZD60SIwZ3lezN7FBj1GAJBaK/t4WobnLMkqQf10BQQs=";
    };
  };

  defaultPackage = mkChannelPackage {
    version = "470.86";
  };
}
