{
  description = "A very basic flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.flake-compat = {
    url = github:edolstra/flake-compat;
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, ... }: flake-utils.lib.simpleFlake {
    inherit self nixpkgs;
    name = "nvidiaPackages";
    config.allowUnfree = true;
    overlay = self: super: {
      nvidiaPackages = self.callPackage ./pkgs { };
    };
    shell = { pkgs }: with pkgs; mkShell {
      outputs = [ "lib" "out" "dev" "lib32" ];
      nativeBuildInputs = [ bashInteractive nixpkgs-fmt bintools patchelf file nix-index jq ];
      buildInputs = [ ];
    };
    systems = [
      #"i686-linux"
      "x86_64-linux"
      # "aarch64-linux"
    ];
  };
}
