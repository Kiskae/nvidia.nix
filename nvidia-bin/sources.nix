{ lib
, stdenvNoCC
, fetchurl
, sourceData ? lib.importJSON ./sources.json
}: let 
  inherit (lib) mapAttrs;
  fetchNvidiaBinary =
    let
      inherit (lib.strings) optionalString;
      defaultUrlBuilder =
        { arch
        , version
        , noCompat32 ? false
        }: "https://download.nvidia.com/XFree86/Linux-${arch}/${version}/NVIDIA-Linux-${arch}-${version}${optionalString noCompat32 "-no-compat32"}.run";
    in
    { arch, version, sha256, urlBuilder ? defaultUrlBuilder, noCompat32 ? false }: stdenvNoCC.mkDerivation {
      pname = "nvidia-src-${arch}-unpacked";
      inherit version;
      src = fetchurl {
        url = urlBuilder {
          inherit arch version noCompat32;
        };
        inherit sha256;
      };

      phases = [ "unpackPhase" "patchPhase" ];

      unpackCmd = ''
        mkdir -p $out
        skip=$(sed 's/^skip=//; t; d' $curSrc)
        tail -n +$skip $curSrc | xz -d | tar xvf - -C $out
        sourceRoot=$out
      '';
    };
in rec {
    blobs = mapAttrs (version: mapAttrs (arch: sha256: fetchNvidiaBinary {
        inherit version arch sha256;
    })) sourceData.hashes.nvidia-bin;
    channels = mapAttrs (_: mapAttrs (_: version: blobs.${version})) sourceData.channels;
    sourcesForChannel = { channel, edition ? "official" }: channels.${channel}.${edition};
}