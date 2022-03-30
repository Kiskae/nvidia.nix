let
  lib = import <nixpkgs/lib>;
  stateMonad = import ./state-monad.nix lib;
  bashGenerators = import ./bash-generators.nix lib;
  classifiers = import ./default.nix {
    inherit lib stateMonad;
    generators = bashGenerators;
  };
  writeToResult = bashGenerators.writeToVariable "result";
  doPipe = lib.flip lib.pipe;
  exampleToResult =
    let
      removeEmptyStrings = lib.filter (x: x != "");
    in
    doPipe [
      (lib.splitString "\n")
      (map (doPipe [
        (lib.splitString " ")
        removeEmptyStrings
        (lib.concatStringsSep " ")
      ]))
      removeEmptyStrings
    ];
  # State[int, Generator] -> [ Code ]
  evalClassifier = doPipe [
    classifiers.eval
    writeToResult
  ];
  generatorTests = with bashGenerators; {
    testAlwaysPass = {
      expr = writeToResult alwaysPass;
      expected = exampleToResult "local result=1";
    };
    testAlwaysFail = {
      expr = writeToResult alwaysFail;
      expected = exampleToResult "local result=0";
    };
    testInvert = {
      expr = writeToResult (invert alwaysFail);
      expected = exampleToResult "local result=1";
    };
    testMatch = {
      expr = writeToResult (matchPatterns "$test" [ "b" "a" "c" ]);
      expected = exampleToResult ''
        case $test in
            b)
                local result=1
                ;;
            a)
                local result=1
                ;;
            c)
                local result=1
                ;;
            *)
                local result=0
                ;;
        esac
      '';
    };
    testIf = {
      expr = writeToResult (withIf "$stuff");
      expected = exampleToResult ''
        if [[ $stuff ]]; then
            local result=1
        else
            local result=0
        fi
      '';
    };
  };
  classifierTests = with classifiers.lib; let
    matchType = matchVariable "$type";
    checkExecutes = test: {
      expr = builtins.trace (lib.concatStringsSep "\n" (evalClassifier test)) 0;
      expected = 0;
    };
  in
  {
    testMatchVariable = {
      expr = evalClassifier (matchType "TLS_LIB");
      expected = exampleToResult ''
        if [[ $type == TLS_LIB ]]; then
            local result=1
        else
            local result=0
        fi
      '';
    };
    testDontMatch = {
      expr = evalClassifier (dontMatch (matchType "TLS_LIB"));
      expected = exampleToResult ''
        if [[ $type == TLS_LIB ]]; then
            local result=0
        else
            local result=1
        fi
      '';
    };
    testMatchAnyList = checkExecutes (matchAny [
      (matchType "A")
      (matchType "B")
    ]);
    testMatchAnySet = checkExecutes (matchAny {
      test = matchType "A";
      test2 = matchType "B";
    });
    testMatchAllList = checkExecutes (matchAll [
      (matchType "A")
      (matchType "B")
    ]);
    testMatchAllSet = checkExecutes (matchAll {
      test = matchType "A";
      test2 = matchType "B";
    });
  };
  stateTests = with stateMonad; let
  in
  {
    testReturn = {
      expr = evalState (return 1) 0;
      expected = 1;
    };
    testBind = {
      expr = evalState (bind (return 10) (x: return (x + 10))) 0;
      expected = 20;
    };
    testCompose = {
      expr = evalState (compose (x: return (x + 25)) get) 5;
      expected = 30;
    };
    testLift = {
      expr = evalState (lift (builtins.add) (return 10) (return 15)) 0;
      expected = 25;
    };
    testPut = {
      expr = evalState (apS (put 10) get) 0;
      expected = 10;
    };
    testGetAndIncrement = {
      expr = evalState (lift (a: b: [ a b ]) getAndIncrement get) 10;
      expected = [ 10 11 ];
    };
  };
in
lib.runTests generatorTests ++
lib.runTests classifierTests ++
lib.runTests stateTests
