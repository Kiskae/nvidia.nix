{
  description = "A very basic flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat = {
    url = github:edolstra/flake-compat;
    flake = false;
  };
  inputs.nix-eval-jobs = {
    url = "github:nix-community/nix-eval-jobs/v2.9.0";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , nix-eval-jobs
    , ...
    }: flake-utils.lib.simpleFlake
      {
        inherit self nixpkgs;
        name = "nvidiaPackages";
        config.allowUnfree = true;
        overlay = self: super: {
          nvidiaPackages = self.callPackage ./pkgs { };
        };
        shell = { pkgs }: with pkgs; mkShell {
          outputs = [ "lib" "out" "dev" "lib32" ];
          nativeBuildInputs = [
            (nix-eval-jobs.packages.${pkgs.system}.default)
            bashInteractive
            nixpkgs-fmt
            bintools
            patchelf
            file
            nix-index
            jq
            (python3.withPackages (pkgs: [
              pkgs.flake8
              pkgs.black
              pkgs.more-itertools
              pkgs.pyparsing
            ]))
            #(haskellPackages.ghcWithPackages (pkgs: [pkgs.strong-path pkgs.deque]))
            #haskell-language-server
          ];
          buildInputs = [ ];
        };
        systems = [
          #"i686-linux"
          "x86_64-linux"
          "aarch64-linux"
        ];
      } // {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
