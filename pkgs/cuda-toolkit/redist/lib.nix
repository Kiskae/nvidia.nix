{ lib }: rec {
  # mkSystemFromPlatform: string -> system
  mkSystemFromPlatform = platform:
    let
      inherit (lib) elemAt splitString;
      inherit (lib.systems.parse) mkSystemFromSkeleton;
      nvidiaPlatformToSkeleton = l:
        let
          cpuAlias = cpu: {
            "ppc64le" = "powerpc64le";
            # sbsa should be armv8-a 64-bit
            "sbsa" = "aarch64";
          }.${cpu} or cpu;
        in
        {
          kernel = elemAt l 0;
          cpu = cpuAlias (elemAt l 1);
        };
    in
    mkSystemFromSkeleton (nvidiaPlatformToSkeleton (splitString "-" platform));

  /*
    loadRedistributableManifest
  */
  loadRedistributableManifest = fetchSource:
    let
      inherit (builtins) removeAttrs;
      inherit (lib) mapAttrs mapAttrs' nameValuePair;
      inherit (lib.systems.parse) doubleFromSystem;
      loadPlatform = platform: data: nameValuePair (doubleFromSystem (mkSystemFromPlatform platform)) (fetchSource data);
      loadComponent = package_name: { name, license, version, ... }@component:
        let
          platforms = removeAttrs component [ "name" "license" "version" ];
        in
        {
          inherit name license version;
          srcs = mapAttrs' loadPlatform platforms;
        };
    in
    { release_date, ... }@manifest:
    let
      components = removeAttrs manifest [ "release_date" ];
    in
    {
      inherit release_date;
      pkgs = mapAttrs loadComponent components;
    };
}
