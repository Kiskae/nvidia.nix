{ lib
, stdenvNoCC
, fetchurl
, runCommand
, callPackage

# Tools
, tools ? callPackage ./tools { }
, packagesFor ? callPackage ./packages.nix { inherit tools; } }:
let
    sources = callPackage ./sources.nix { };
in (sources.sourcesForChannel { channel = "current"; }).${"x86_64"}