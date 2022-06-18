{ lib }:
let
  inherit (lib) const concatMap isFunction singleton;

  # Helpers => {
  #   indent: [ a ] -> [ a ]
  #   fromCode: String -> [ a ]
  # }
  # CodeGen => Helpers -> [ a ]

  # indent: CodeGen -> CodeGen
  indent = code: h: h.indent (code h);
  # asCodeGen: [ (String | CodeGen) ] -> CodeGen
  asCodeGen =
    let
      # Helpers -> (String | CodeGen) -> [ a ]
      toResult = h: val: if isFunction val then (val h) else (h.fromCode val);
    in
    lib.flip (helpers: concatMap (toResult helpers));
  fromCode = code: h: h.fromCode code;
in
rec {
  # ifExpr: if-expr -> CodeGen -> CodeGen -> CodeGen
  ifExpr = expr: onTrue: onFalse: asCodeGen [
    "if [[ ${expr} ]]; then"
    (indent onTrue)
    "else"
    (indent onFalse)
    "fi"
  ];

  # switchCase: case-expr -> [ { pattern :: case-pattern, onMatch :: CodeGen } ]
  #                       -> CodeGen -> CodeGen
  switchCase = expr: cases: onMiss:
    let
      toSwitchCase = { pattern, onMatch }: [
        "${pattern})"
        (indent onMatch)
        ";;"
      ];
      genCases = cases: asCodeGen (concatMap toSwitchCase cases);
    in
    asCodeGen [
      "case ${expr} in"
      (indent (genCases (cases ++ [{
        # include catchall so something always matches
        pattern = "*";
        onMatch = onMiss;
      }])))
      "esac"
    ];

  # matchPatterns: case-expr -> [ case-pattern ] -> CodeGen -> CodeGen -> CodeGen
  matchPatterns = expr: patterns: onMatch: switchCase expr (map
    (pattern: {
      inherit pattern onMatch;
    })
    patterns
  );

  /*
    # regularVar: var_name -> {
    #   prelude :: CodeGen
    #   get :: string
    #   set :: value -> CodeGen
    # }
  */
  mkRegularVar = var_name: {
    prelude = fromCode "declare ${var_name}";
    get = "\$${var_name}";
    set = value: fromCode "${var_name}=${toString value}";
  };

  # writeToVariable: var_name -> ((value -> CodeGen) -> CodeGen) -> CodeGen
  # TODO: not sure if the scoping really helps, since the var_name is user-provided
  writeToVariable = var_name: subject:
    let
      writeToResult = result: fromCode "local ${var_name}=${toString result}";
    in
    subject writeToResult;

  # [ CodeGen ] -> CodeGen
  concatOutput = asCodeGen;

  # String -> CodeGen
  inherit fromCode;
}
