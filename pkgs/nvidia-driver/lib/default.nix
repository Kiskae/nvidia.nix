{ lib }: rec {
  state = import ./state.nix { inherit lib; };
  manifest = import ./manifest.nix { inherit lib; };
  codegen = import ./codegen.nix { inherit lib; };
  classifier = import ./classifier.nix { inherit lib state codegen; };
}
