{ lib, callPackage, system, srcOnly, linkFarmFromDrvs, pkgs }:
let
  inherit (callPackage ./redist {
    product = "cuda";
  }) loadManifestFromFile;

  loadManifestFromCache = label: loadManifestFromFile "${./cache}/redistrib_${label}.json";

  defineCudaToolkit = callPackage ./packages.nix { };
  mkToolkit = callPackage ./pkgs.nix { };
in
rec {
  cudatoolkit_11_4 = mkToolkit (loadManifestFromCache "11.6.1") // {
    recurseForDerivations = true;
  };
  cudatest =
    let
      isDerivation = with lib; filterAttrs (const lib.isDerivation);
      supportedBySystem = with lib; filterAttrs (const (drv: elem system drv.meta.platforms));
    in
    linkFarmFromDrvs "cudatest" (lib.attrValues (supportedBySystem (isDerivation cudatoolkit_11_4)));
  #cudatoolkit_11 = cudatoolkit_11_4;
  #cudatoolkit_11_4 = defineCudaToolkit {
  #  manifest = loadManifestFromCache "11.4.4";
  #};
  #cudatoolkit_11_5 = defineCudaToolkit {
  #  manifest = loadManifestFromCache "11.5.2";
  #};
  #cudatoolkit_11_6 = defineCudaToolkit {
  #  manifest = loadManifestFromCache "11.6.1";
  #};
}
