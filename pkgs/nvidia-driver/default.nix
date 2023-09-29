{
  lib,
  buildPackages,
  fetchurl,
  writeText,
  linkFarm,
}: let
  components = let
    evalComponent = pname: {profile ? lib.const {}, ...} @ src:
      (builtins.removeAttrs src ["profile"]) // (profile ({inherit pname;} // src));
  in
    lib.mapAttrs evalComponent (import ./components.nix {inherit lib;});
  mkRunfilePackageSet = buildPackages.callPackage ./nvidia-installer {
    # TODO: inject components data
  };
in {
  test = mkRunfilePackageSet {
    runfile = fetchurl {
      passthru = {
        version = "450.216.04";
      };
      url = "https://us.download.nvidia.com/tesla/450.216.04/NVIDIA-Linux-x86_64-450.216.04.run";
      hash = "sha256-B+CrLBBnRqXpC0xY+VMLHuIYLWx6VdnsPYDRmC3oKAE=";
    };
  };

  components = linkFarm "nvidia-report" {
    "final-components.nix" = writeText "final-components.nix" (lib.generators.toPretty {} components);
  };
}
