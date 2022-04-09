{ lib
, pkgs
, pkgsi686Linux
, nvidiaPkgs
  #TODO: lib32
, classifierToInstallPhase
}:
let
  inherit (nvidiaPkgs) sources manifest;
  baseLayer = classifier: { pname, ... }: {
    inherit (sources) version;
    inherit sources manifest;

    # Disable building phases
    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      source ${classifierToInstallPhase {
        inherit pname classifier;
        manifest = "$manifest";
        source = "$sources";
      }}

      runHook postInstall
    '';
  };
  libraryLayer =
    let

    in
    dependencies:
    if dependencies != null
    then
      let
        pkgs1 = dependencies (pkgs // nvidiaPkgs);
        pkgs2 = dependencies (
          pkgsi686Linux //
          lib.mapAttrs (lib.const (lib.getOutput "lib32")) nvidiaPkgs
        );
      in
      { outputs ? [ "out" ]
      , fixupOutput ? ""
      , ...
      }: {
        outputs = outputs ++ [ "lib32" ];
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = (pkgs1.build or [ ]) ++ (pkgs2.build ++ [ ]);
        runtimeDependencies = (pkgs1.runtime or [ ]);
        lib32runtimeDependencies = (pkgs2.runtime or [ ]);
        dontAutoPatchelf = true;
        fixupOutput = ''
          ${fixupOutput}

          if [[ $prefix == $lib32 ]]; then
            NIX_BINTOOLS=${pkgsi686Linux.bintools} \
              runtimeDependencies=$lib32runtimeDependencies \
              autoPatchelf -- $prefix
          elif [[ -e $prefix/lib ]]; then
            autoPatchelf -- $prefix
          fi
        '';
      }
    else _: { };
in
lib.makeOverridable (
  { pname
  , classifier
  , dependencies ? null
  , stdenv ? pkgs.stdenv
  , ...
  }@args:
  let
    layers = lib.composeManyExtensions
      (map lib.const [
        (baseLayer classifier)
        (libraryLayer dependencies)
      ]);
  in
  stdenv.mkDerivation (lib.extends
    layers
    lib.id
    (removeAttrs args [
      "classifier"
      "dependencies"
    ]))
)
