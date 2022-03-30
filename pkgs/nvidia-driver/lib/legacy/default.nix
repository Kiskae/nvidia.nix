{ lib
, callPackage
, python3
, runCommand
}:
let
  manifestLib = callPackage ./manifest-lib { };
in
rec {
  prepareManifest = manifestLib.convertManifest;
  bashManifestVariables = manifestLib.variableDefinitions;
  bashHandlerDefinition = manifestLib.bashHandlerDefinition;
  classifierHook = callPackage ./classifier-hook.nix {
    inherit manifestLib;
  };
}
