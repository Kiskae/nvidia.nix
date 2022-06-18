{ lib, nvlib, writeScript, runCommand, python3 }:
let
  useManifestVariables =
    let
      inherit (nvlib.codegen) mkRegularVar;
      inherit (nvlib.manifest) variables;
    in
    { func
    , extraVariables ? [ ]
    }: lib.genAttrs
      (variables ++ extraVariables)
      (var: func ((mkRegularVar var).get));

  writeCodeToScript = name: code: lib.pipe code [
    # CodeGen
    (x: x {
      indent = map (l: "  ${l}");
      fromCode = lib.splitString "\n";
    })
    # [ string ]
    (lib.concatStringsSep "\n")
    # string
    (writeScript "${name}.sh")
    # derivation
  ];

  noop = nvlib.codegen.fromCode ":";

  # { * :: Classifier }
  classifiers =
    let
      raw = import ./classifications.nix {
        match =
          let
            inherit (nvlib.classifier.matchers)
              matchVariableMany
              matchVariable
              matchAll
              matchAny
              invert;
          in
          useManifestVariables
            {
              func = var: value:
                if lib.isList
                then matchVariableMany var value
                else matchVariable var value;
            }
          // {
            all = matchAll;
            any = matchAny;
            not = invert;
          };
      };

      isClassifier = nvlib.state.isState;

      intercept_path =
        let
          inherit (nvlib.classifier) intercept;
          inherit (nvlib.codegen) concatOutput fromCode;
        in
        path: intercept (original: _: onFail: original
          (concatOutput [
            (fromCode "matches+=(${lib.escapeShellArg (lib.concatStringsSep "." path)}")
            onFail
          ])
          onFail);

      mapToClassifier = path: lib.mapAttrs (n: v:
        let
          inherit (nvlib.classifier.matchers) matchAny;
          new_path = path ++ [ n ];
          next = x: matchAny (f new_path x);
        in
        if isClassifier v
        then intercept_path new_path v
        else next v
      );
    in
    mapToClassifier [ ] raw;

  determine-file-locations =
    let
      inherit (nvlib.codegen) ifExpr mkRegularVar concatOutput;
      overrides = lib.genAttrs
        [
          "prefix"
          "dir"
          "ln_override"
        ]
        mkRegularVar;
      ruleToCodeGen = rule: lib.pipe rule [
        # Rule
        (x: removeAttrs x [ "check" ])
        # { * :: string }
        (lib.mapAttrsToList (n: overrides.${n}.set))
        # [ CodeGen ]
        concatOutput
        # CodeGen (onPass)
        (x: rule.check x noop)
        # CodeGen
      ];
    in
    lib.pipe
      (import ./locations.nix {
        match = useManifestVariables {
          func = var: value: ifExpr "${var} == ${value}";
          extraVariables = [ "class" ];
        };
      })
      [
        # [ Rule ]
        (map ruleToCodeGen)
        # [ CodeGen ]
        (rules: concatOutput (
          (lib.mapAttrsToList (_: v: v.prelude) overrides)
          ++ [
            (overrides.prefix.set "$outputLib")
            (overrides.dir.set "/lib")
          ]
          ++ rules
        ))
        # CodeGen
        (codeGenToScript "determine-file-locations")
        # derivation
      ];
  TODO = throw "Not Yet Implemented";
in
{
  # (Extracted Distribution) -> Manifest
  mkManifest = sources: runCommand "manifest-${sources.version}.sh"
    {
      inherit sources;
      passthru = {
        # Keep in sync with python script
        variables = [
          "src_path"
          "target_path"
          "perms"
          "type"
          "module"
          "arch"
          "extra"
        ];
        hookName = "manifest_entry";
      };
    }
    ''
      if [ ! -f "$sources/.manifest" ]; then
        echo "$sources is not an nvidia-installer distribution"
        exit 1
      fi

      ${python3}/bin/python3 ${./convert-manifest.py} "$sources/.manifest" > $out
    '';
  # TODO: variables required to generate classifiers?
  # Classifier -> { Manifest, onMatch, onMiss } -> derivation
}
