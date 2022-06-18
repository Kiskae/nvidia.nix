{ lib, callPackage, stdenvNoCC, distTarball }:
let
  unpackedDriver = stdenvNoCC.mkDerivation {
    name = lib.removeSuffix ".run" distTarball.name;
    inherit (distTarball) version meta;

    src = distTarball;
    buildCommand = ''
      skip=$(grep -a ^skip= $src | cut -d= -f2)
      install -d $out
      tail -n +$skip $src | tar -Jxvf - --directory $out
    '';
  };
in
callPackage ./packages.nix {
  src = unpackedDriver;
}
