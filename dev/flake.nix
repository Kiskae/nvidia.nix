{
  description = "nvidia.nix dev flake";

  inputs = {
    call-flake.url = "github:divnix/call-flake";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    blank.url = "github:divnix/blank";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
  };

  outputs = inputs @ {
    flake-parts,
    call-flake,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {
      inputs = inputs // {
        flake = call-flake ../.;
      };
    } ({self, inputs, ...}: {
      flake = {
        inherit (inputs.flake) nixosModules overlays;
      };
      debug = true;
      systems = import systems;
      imports = [
        ./treefmt.nix
        ./updater/module.nix
      ];
      perSystem = {pkgs, ...}: {
        packages = let
          nvPkgs = (pkgs.extend self.overlays.default).nvidiaPackages;
        in {driver = nvPkgs.driver.test2;};
      };
    });

  /*

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    alejandra,
    ...
  }:
    flake-utils.lib.simpleFlake
    {
      inherit self nixpkgs;
      name = "nvidiaPackages";
      config.allowUnfree = true;
      overlay = self: super: {
        nvidiaPackages = self.callPackage ./nvidia-driver {};
      };
      shell = {pkgs}:
        with pkgs;
          mkShell {
            packages = [
              nil
              bintools
              patchelf
              file
              nix-index
              jq
              tree
              (python3.withPackages (pkgs: [
                pkgs.flake8
                pkgs.black
                pkgs.more-itertools
                pkgs.pyparsing
              ]))
            ];
          };
      systems = [
        #"i686-linux"
        "x86_64-linux"
        "aarch64-linux"
      ];
    }
    // {
      formatter.x86_64-linux = alejandra.packages.x86_64-linux.default;
    };
  */
}
