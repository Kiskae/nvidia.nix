let
  lib = import <nixpkgs/lib>;
  nvlib = import ./. {
    inherit lib;
  };

  # ((a -> CodeGen) -> CodeGen) -> [ String ]
  outputForTesting =
    let
      inherit (lib) singleton;
      inherit (nvlib.codegen) fromCode;

      indent = "|   ";
      helpers = {
        indent = map (line: "${indent}${line}");
        fromCode = singleton;
      };
      writeToReturn = value: fromCode "return ${toString value}";
    in
    f: f writeToReturn helpers;

  generatorTests = with nvlib.codegen; {
    test_CodeGen_echo = {
      expr = outputForTesting (return: return 0);
      expected = [ "return 0" ];
    };
    test_CodeGen_ifExpr = {
      expr = outputForTesting (return: ifExpr "$stuff" (return 0) (return 1));
      expected = [
        "if [[ $stuff ]]; then"
        "|   return 0"
        "else"
        "|   return 1"
        "fi"
      ];
    };
    test_CodeGen_matchPatterns = {
      expr = outputForTesting (return: matchPatterns "$test" [ "b" "a" "c" ] (return 0) (return 1));
      expected = [
        "case $test in"
        "|   b)"
        "|   |   return 0"
        "|   ;;"
        "|   a)"
        "|   |   return 0"
        "|   ;;"
        "|   c)"
        "|   |   return 0"
        "|   ;;"
        "|   *)"
        "|   |   return 1"
        "|   ;;"
        "esac"
      ];
    };
    test_CodeGen_writeToVariable = {
      expr = outputForTesting (_: writeToVariable "test" (set: set 0));
      expected = [
        "local test=0"
      ];
    };
    test_CodeGen_nested = {
      expr = outputForTesting (return: writeToVariable "winner" (set: concatOutput [
        (ifExpr "\$wins" (set 0) (set 1))
        (return "\$winner")
      ]));
      expected = [
        "if [[ $wins ]]; then"
        "|   local winner=0"
        "else"
        "|   local winner=1"
        "fi"
        "return $winner"
      ];
    };
  };

  stateTests = with nvlib.state; let
    eval = s: evaluate s 0;
  in
  {
    test_State_return = {
      expr = eval (return 1);
      expected = 1;
    };
    test_State_bind = {
      expr = eval (bind (return 10) (x: return (x + 10)));
      expected = 20;
    };
    test_State_compose = {
      expr = eval (compose (x: return (x + 25)) get);
      expected = 25;
    };
    test_State_lift = {
      expr = eval (lift (builtins.add) (return 10) (return 15));
      expected = 25;
    };
    test_State_put = {
      expr = eval (apS (put 10) get);
      expected = 10;
    };
    test_State_getAndIncrement = {
      expr = eval (lift (a: b: [ a b ]) getAndIncrement get);
      expected = [ 0 1 ];
    };
    test_State_apply = {
      expr = eval (apply (return (a: a + 30)) (return 10));
      expected = 40;
    };
  };

  classifierTests = with nvlib.classifier.matchers; let
    toScript = classifier: outputForTesting (return:
      (nvlib.state.evaluate classifier 0) (return 0) (return 1)
    );
    matchType = matchVariable "\$type";
  in
  {
    test_Classifier_matchVariable = {
      expr = toScript (matchType "TLS_LIB");
      expected = [
        "if [[ $type == TLS_LIB ]]; then"
        "|   return 0"
        "else"
        "|   return 1"
        "fi"
      ];
    };
    test_Classifier_matchAny = {
      expr = toScript (matchAny [
        (matchType "A")
        (matchType "B")
        (matchType "C")
      ]);
      expected = [
        "declare _carry_0"
        "if [[ $type == A ]]; then"
        "|   _carry_0=1"
        "else"
        "|   _carry_0=0"
        "fi"
        ""
        "declare _carry_1"
        "if [[ $_carry_0 == 0 ]]; then"
        "|   if [[ $type == B ]]; then"
        "|   |   _carry_1=1"
        "|   else"
        "|   |   _carry_1=0"
        "|   fi"
        "else"
        "|   _carry_1=1"
        "fi"
        ""
        "if [[ $_carry_1 == 0 ]]; then"
        "|   if [[ $type == C ]]; then"
        "|   |   return 0"
        "|   else"
        "|   |   return 1"
        "|   fi"
        "else"
        "|   return 0"
        "fi"
      ];
    };
    test_Classifier_matchAnyBase = {
      expr = toScript (matchAny [ ]);
      expected = [ "return 1" ];
    };
    test_Classifier_matchAll = {
      expr = toScript (matchAll [
        (matchType "A")
        (matchType "B")
        (matchType "C")
      ]);
      expected = [
        "declare _carry_0"
        "if [[ $type == A ]]; then"
        "|   _carry_0=1"
        "else"
        "|   _carry_0=0"
        "fi"
        ""
        "declare _carry_1"
        "if [[ $_carry_0 == 1 ]]; then"
        "|   if [[ $type == B ]]; then"
        "|   |   _carry_1=1"
        "|   else"
        "|   |   _carry_1=0"
        "|   fi"
        "else"
        "|   _carry_1=0"
        "fi"
        ""
        "if [[ $_carry_1 == 1 ]]; then"
        "|   if [[ $type == C ]]; then"
        "|   |   return 0"
        "|   else"
        "|   |   return 1"
        "|   fi"
        "else"
        "|   return 1"
        "fi"
      ];
    };
    test_Classifier_matchAllBase = {
      expr = toScript (matchAll [ ]);
      expected = [ "return 0" ];
    };
    test_Classifier_invert = {
      expr = toScript (invert (matchType "TLS_LIB"));
      expected = [
        "if [[ $type == TLS_LIB ]]; then"
        "|   return 1"
        "else"
        "|   return 0"
        "fi"
      ];
    };
  };
in
lib.runTests generatorTests
++ lib.runTests stateTests
++ lib.runTests classifierTests
