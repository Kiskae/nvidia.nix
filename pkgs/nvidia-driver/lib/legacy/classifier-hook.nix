{ lib
, classifierLib ? import ./classifier-lib { inherit lib; }
, manifestLib
, writeScript
}:
let
  inherit (lib.strings) concatStringsSep escapeShellArg;
  inherit (lib.attrsets) mapAttrsToList mapAttrs nameValuePair genAttrs;
  inherit (lib.lists) drop;
  inherit (builtins) listToAttrs head tail;

  # import defined classifiers
  defs = import ./classifiers.nix {
    inherit lib;
    inherit (classifierLib.lib) matchVariable matchVariableMulti matchAny matchAll dontMatch;
    vars = genAttrs (manifestLib.variables ++ [ "version" ]) (var: "\$${var}");
  };

  generateClassifierScript = name:
    let
      funcName = "_classifier_${name}";
      genCode = classifier: concatStringsSep "\n" (classifierLib.eval classifier ''
        classifier="${name}"
        return 0
      '' "return 1");
    in
    classifier: writeScript "classifier-${name}.sh" ''
      classifierHooks+=(${funcName})
      ${funcName}() {
        ${manifestLib.variableDefinitions {}}
        local version=$version

        ${genCode classifier}
      }
    '';

  # generate a derivation for each handler
  scriptFiles = mapAttrs generateClassifierScript defs.classifiers;
in
(writeScript "classifier-hook.sh" ''
  declare -a classifierHooks

  # Defer loading of classifiers until stdenv is loaded
  postHooks+=(_classifier)
  _classifier () {
    # Only do if we havent loaded classifiers yet
    if [[ ''${classifierHooks[@]:+''${classifierHooks[@]}} ]]; then
      return 0
    fi

    ${defs.order (mapAttrs (_: value: "source ${value}") scriptFiles)}

    echo "''${#classifierHooks[@]} classifier definitions loaded"
  }

  runClassifier() {
    runOneHook "classifierHook" $@
  }
'').overrideAttrs (oldAttrs: {
  # attach known classifiers for introspection
  passthru = (oldAttrs.passthru or { }) // {
    known-classifiers = builtins.attrNames scriptFiles;
  };
})
