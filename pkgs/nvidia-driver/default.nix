{ lib, pkgs, callPackage, fetchurl, system }:
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

  mkPackageSet = { version, src }: lib.makeScope
    pkgs.newScope
    (callPackage ./packages {
      nvidiaVersion = version;
      distTarball = src;
      linuxPackages = pkgs.linuxKernel.packages.linux_5_17; # packageAliases.linux_latest;
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
      dir_overrides = {
        "armv7l-gnueabihf" = {
          # https://download.nvidia.com/XFree86/Linux-32bit-ARM/
          global = "Linux-32bit-ARM";
          # https://us.download.nvidia.com/XFree86/Linux-x86-ARM/
          us = "Linux-x86-ARM";
        };
        "aarch64" = {
          # https://us.download.nvidia.com/XFree86/aarch64/
          us = arch;
        };
      };
      dir = label: lib.attrByPath [ arch label ] "Linux-${arch}" dir_overrides;
    in
    [
      "https://download.nvidia.com/XFree86/${dir "global"}/"
      "https://us.download.nvidia.com/XFree86/${dir "us"}/"
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
          inherit version suffix system;
        };
        sha256 = lookupSavedHash {
          inherit version suffix system;
          defaultHash = lib.fakeSha256;
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
  /*
    production = mkDriverForChannel {
    branch = "current";
    maturity = "long-lived-branch-release";
    };

    latest = mkDriverForChannel {
    branch = "current";
    };

    beta = mkDriverForChannel {
    branch = "current";
    maturity = "beta";
    };

    # GKxxx "Kepler" GPUs
    legacy_470 = mkDriverForChannel {
    branch = "470";
    };

    # GF1xx "Fermi" GPUs
    legacy_390 = mkDriverForChannel {
    branch = "390";
    };

    tesla = mkDriver {
    version = "510.47.03";
    cdnProvider = _: [ "https://us.download.nvidia.com/tesla/" ];
    };

    vulkan_beta = mkDriver {
    version = "470.62.22";
    cdnProvider = _: [ "https://developer.nvidia.com/" ];
    urlProvider = { version, ... }: "vulkan-beta-${lib.concatStrings (lib.splitString "." version)}-linux";
    };

    current = mkDriver {
    version = "470.86";
    };
  */
  old = mkChannelPackage {
    version = "1.0-6106";
    suffix = "pkg2";
  };

  tesla = mkChannelPackage {
    version = "510.47.03";
    downloadMirrors = _: [ "https://us.download.nvidia.com/tesla/" ];
  };

  current = mkChannelPackage {
    version = "470.86";
  };

  defaultPackage = channels.legacy_470;
}
