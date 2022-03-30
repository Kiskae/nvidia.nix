{ lib }: {
  state = import ./state.nix { inherit lib; };
  manifest = import ./manifest.nix { inherit lib; };
}
