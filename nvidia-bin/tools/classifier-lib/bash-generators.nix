# Code => string
# Generator => Code -> Code -> [ Code ]
lib:
let
  inherit (lib) concatStringsSep const genAttrs mapAttrsToList flatten;
  inherit (builtins) map;
in
rec {
  # Generator
  alwaysPass = onPass: _: [ onPass ];
  # Generator
  alwaysFail = _: onFail: [ onFail ];
  # if-expr -> Generator
  withIf = expr: onTrue: onFalse: [
    "if [[ ${expr} ]]; then"
    onTrue
    "else"
    onFalse
    "fi"
  ];
  # case-expr -> [ { case-pattern, Code } ] -> Code -> Code
  switchCase = variable: cases: onMiss:
    let
      toSwitchCase = { pattern, onMatch }: [
        "${pattern})"
        onMatch
        ";;"
      ];
    in
    flatten [
      "case ${variable} in"
      (map toSwitchCase cases)
      (toSwitchCase { pattern = "*"; onMatch = onMiss; })
      "esac"
    ];
  # case-expr -> [ case-pattern ] -> Generator
  matchPatterns = variable: options: onMatch:
    let
      patterns = map
        (pattern: {
          inherit pattern onMatch;
        })
        options;
    in
    switchCase variable patterns;
  # Generator -> Generator
  invert = generator: onPass: onFail: generator onFail onPass;
  # var_name -> Generator -> [ Code ]
  writeToVariable = var_name: generator:
    let
      writeResult = result: "local ${var_name}=${toString result}";
    in
    generator (writeResult 1) (writeResult 0);

  # var_name -> var_name -> Generator
  or_expr = a: b: withIf "$(( ${a} + ${b} - ${a} * ${b} )) -ne 0";
  and_expr = a: b: withIf "$(( ${a} * ${b} )) -ne 0";
}
