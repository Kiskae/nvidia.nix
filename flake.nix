{
  description = "nvidia.nix flake";

  outputs = {self}: {
    overlays.default = import ./pkgs/overlay.nix;

    modules.nixos = import ./nixos;

    nixosModules = self.modules.nixos;

    nixci.dev = {
      dir = "./dev";
      overrideInputs.flake = ./.;
    };
  };
}
