{ lib }:
let
  inherit (lib) const concatMap isFunction singleton;
  # Code => [ String ]
  # CodeGen => (Code -> Code) -> Code
in
rec {
  # ifExpr: if-expr -> Code -> Code -> CodeGen
  ifExpr = expr: onTrue: onFalse: indent: [
    "if [[ ${expr} ]]; then"
    (indent onTrue)
    "else"
    (indent onFalse)
    "fi"
  ];

  # switchCase: case-expr -> [ { pattern :: case-pattern, onMatch :: Code } ]
  #                       -> Code -> CodeGen
  switchCase = expr: cases: onMiss: indent:
    let
      toSwitchCase = { pattern, onMatch }: [
        "${pattern})"
        (indent onMatch)
        ";;"
      ];
    in
    [
      "case ${expr} in"
      (indent (concatMap toSwitchCase (cases ++ [{
        # include catchall so something always matches
        pattern = "*";
        onMatch = onMiss;
      }])))
      "esac"
    ];

  # matchPatterns: case-expr -> [ case-pattern ] -> Code -> Code -> CodeGen
  matchPatterns = expr: patterns: onMatch: switchCase expr (map
    (pattern: {
      inherit pattern onMatch;
    })
    patterns
  );

  # writeToVariable: var_name -> ((value -> Code) -> CodeGen) -> CodeGen
  writeToVariable = var_name: subject:
    let
      writeToResult = result: [ "local ${var_name}=${toString result}" ];
    in
    subject writeToResult;

  # [ CodeGen ] -> CodeGen
  concat = lib.flip (inline: map (g: g inline));
}
