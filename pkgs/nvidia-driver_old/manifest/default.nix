{ lib
, runCommand
, python3
, sources
}:
let
  toOpArgsPair = op: args: {
    inherit op args;
  };
  matchers = import ./matchers.nix {
    match = variable: pattern: toOpArgsPair "match" {
      inherit variable pattern;
    };
    all = toOpArgsPair "all";
    any = toOpArgsPair "any";
    not = toOpArgsPair "not";
  };
  locations = import ./locations.nix {
    match = variable: pattern: toOpArgsPair "match" {
      inherit variable pattern;
    };
  };
  python = python3.withPackages (pkgs: [
    pkgs.more-itertools
  ]);
in
runCommand "manifest"
{
  matchers = builtins.toJSON matchers;
  locations = builtins.toJSON locations;
  passAsFile = [ "matchers" "locations" ];
  disallowedReferences = [ sources ];
  inherit sources;
  inherit (sources) version;
} ''
  if [ ! -f "$sources/.manifest" ]; then
    echo "$sources is not an nvidia-installer distribution"
    exit 1
  fi

  mkdir -p $out

  ${python}/bin/python3 ${./process-manifest.py} \
    --locations "$locationsPath" \
    --matchers "$matchersPath" \
    --outpath "$out" \
    "$sources/.manifest"
''
