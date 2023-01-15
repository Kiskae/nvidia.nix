{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    alejandra = {
      url = "github:kamadorueda/alejandra/3.0.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flakeCompat.follows = "flake-compat";
      };
    };
  };

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
}
