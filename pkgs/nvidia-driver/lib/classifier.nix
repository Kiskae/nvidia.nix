{ lib, state, codegen }:
let
  # Classifier => onMatch -> onMiss -> CodeGen
  # Matcher => State[int, Classifier]

  # String -> State[int, String]
  randomVarName =
    let
      inherit (state) fmap getAndIncrement;
    in
    prefix: fmap (x: "_${prefix}${toString x}") getAndIncrement;


  foldM =
    let
      inherit (lib) singleton;
      inherit (state) return fmap compose apply;
      inherit (codegen) writeToVariable concatOutput;

      # stage1: (var_name -> Classifier -> Classifier)
      #      -> Acc
      #      -> State[int, (Classifier -> Acc)]
      stage1 =
        combiner:
        { deps ? [ ]
          # [ CodeGen ]
        , tail ? null
          # Classifier
        }:
        if tail == null then
          return
            (next: {
              inherit deps;
              # The result entirely depends on the value of tail
              tail = next;
            })
        else
          fmap
            (var_name: next: {
              # write previous tail out to 'var_name' and append
              #  generated code to deps
              deps = deps ++ singleton (
                writeToVariable var_name (set: tail (set 1) (set 0))
              );
              # wrap next head to depend on result through 'var_name'
              tail = combiner var_name next;
            })
            (randomVarName "carry_");
      # stage2: Classifier
      #      -> Acc
      #      -> Classifier
      stage2 = default:
        { deps ? [ ]
        , tail ? default
        }: onPass: onFail: concatOutput (lib.intersperse (codegen.fromCode "") (
          deps ++ singleton (tail onPass onFail)
        ));
    in
    { combiner
    , base ? (throw "no default provided")
    }:
    let
      # stage3: State[int, Acc]
      #      -> State[int, (Classifier -> Acc)]
      stage3 = compose (stage1 combiner);
      # stage4: State[int, Acc]
      #      -> State[int, Classifier]
      #      -> State[int, Acc]
      stage4 = acc: apply (stage3 acc);
    in
    input: lib.pipe input [
      # [ State[int, Classifier ]] -> State[int, Acc]
      (lib.foldl' stage4 (return { }))
      # State[int, Acc] -> State[int, Classifier]
      (fmap (stage2 base))
    ];

  # (Classifier -> Classifier) -> Matcher -> Matcher
  intercept = modifier: state.fmap modifier;
in
{
  matchers =
    let
      inherit (lib) const attrValues;
      inherit (state) return fmap;
      inherit (codegen) ifExpr matchPatterns;

      # TODO: for non-shortcircuiting, the tree needs to be inverted
      #  execute the original, then in the winning branch, check if the
      #  previous result was acceptable
      passAsList = f: x:
        if (builtins.isAttrs x) then
          f (attrValues x)
        else f x;
    in
    {
      # matchVariable: variable -> pattern -> Matcher
      # if [[ $variable == $pattern ]];
      matchVariable = variable: pattern: return (ifExpr "${variable} == ${pattern}");

      matchVariableMany = variable: patterns: return (matchPatterns variable patterns);

      # doOnMatch: (CodeGen -> CodeGen) -> Matcher -> Matcher
      doOnMatch = f: fmap (g: onMatch: g (f onMatch));

      matchAny = passAsList (foldM {
        combiner = prev_result: original:
          onPass: onFail:
            ifExpr
              "\$${prev_result} == 0"
              (original onPass onFail)
              onPass;
        base = _: onFail: onFail;
      });

      matchAll = passAsList (foldM {
        combiner = prev_result: original:
          onPass: onFail:
            ifExpr
              "\$${prev_result} == 1"
              (original onPass onFail)
              onFail;
        base = onPass: _: onPass;
      });

      # Matcher -> Matcher
      invert = fmap (f: onPass: onFail: f onFail onPass);
    };
  inherit intercept;
  eval = lib.flip state.evaluate 0;
}
