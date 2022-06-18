{ lib
, pkgs
, manifest
}:
let
  inherit (manifest) sources version;
  baseLayer = category: _: _: {
    inherit manifest sources version;

    # disable build phases
    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      source $manifest/install.sh $sources ${category}

      runHook postInstall
    '';

    succeedOnFailure = true;
    failureHook = ''
      for prefix in $outputs; do
        mkdir ''${!prefix}
      done
    '';
  };
  libraryLayer = _: _: {
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  };
in
lib.makeOverridable (
  { category
  , pname ? category
  , stdenv ? pkgs.stdenv
  , ...
  } @ args:
  let
    layers = lib.composeManyExtensions [
      (baseLayer category)
      libraryLayer
    ];
  in
  stdenv.mkDerivation (lib.extends
    layers
    lib.id
    (removeAttrs args [
      "category"
    ]))
)
