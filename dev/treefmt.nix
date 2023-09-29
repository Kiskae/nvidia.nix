{
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {
    pkgs,
    config,
    ...
  }: {
    treefmt = {
      inherit (config.flake-root) projectRootFile;

      # Nix
      programs.alejandra.enable = true;
      programs.statix.enable = true;

      # Python
      programs.black.enable = true;
      programs.isort = {
        enable = true;
        profile = "black";
      };
    };
  };
}
