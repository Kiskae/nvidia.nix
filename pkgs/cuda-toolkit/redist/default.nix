{ lib
, fetchurl
, product
, domain ? "https://developer.download.nvidia.com"
}:
let
  inherit (import ./lib.nix { inherit lib; }) loadRedistributableManifest;
  fetchData = { relative_path, sha256, ... }: fetchurl {
    url = "${domain}/compute/${product}/redist/${relative_path}";
    inherit sha256;
  };
  loadManifestFromFile = path: loadRedistributableManifest fetchData (lib.importJSON path);
in
{
  # path -> loaded_manifest
  inherit loadManifestFromFile;

  # { label :: string, sha256 :: string } -> loaded_manifest
  #   requires 'allow-import-from-derivation'
  loadManifestFromNetwork = { label, sha256 }: loadManifestFromFile (fetchData {
    relative_path = "redistrib_${label}.json";
    inherit sha256;
  });
}
