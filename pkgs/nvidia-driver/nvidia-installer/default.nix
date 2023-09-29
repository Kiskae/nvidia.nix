{
  lib,
  runCommand,
  python3,
  jq,
  libarchive,
}: let
  extractRunfile = src @ {
    version,
    meta ? {},
    ...
  }:
    runCommand "nvidia-source-${version}" {
      inherit src version meta;

      nativeBuildInputs = [libarchive];

      # Ensure we don't need to keep the tarball around
      disallowedReferences = [src];
    } ''
      skip=$(sed 's/^skip=//; t; d' $src)

      mkdir -p $out
      tail -n +$skip $src | bsdtar xvf - -C $out
    '';
in
  {
    runfile ? null,
    src ? extractRunfile runfile,
    version ? src.version,
    meta ? src.meta,
  }:
    src
