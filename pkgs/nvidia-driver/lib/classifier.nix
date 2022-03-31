{ lib, state, codegen }:
let
  # Classifier => onMatch -> onMiss -> CodeGen
  # Matcher => State[int, Classifier]

  # concat: Options -> Matcher -> Matcher -> Matcher
  concatM =
    { resolver
      # (left_result -> right_result -> CodeGen)
    , shortcircuit ? _: lib.id
      # (left_result -> Classifier -> Classifier)
    }:
    let
      inherit (state) fmap apply lift;
      # State[int, String]
      randomVarName = fmap (x: "_${toString x}") state.getAndIncrement;

      # Bound => { var_name :: String , code :: CodeGen }
      # State[int, (Classifier -> Bound)]
      writeMatchToResult = fmap
        (var_name: classifier: {
          inherit var_name;
          code = codegen.writeToVariable var_name (set: classifier (set 1) (set 0));
        })
        randomVarName;

      # State[int, Classifier] -> State[int, Bound]
      resolveLeft = apply writeMatchToResult;

      # State[int, Classifier] -> State[int, (left_result) -> Bound]
      resolveRight = lift
        # (Classifier -> Bound) -> Classifier -> (left_result) -> Bound
        (make_bound: right: left_result: make_bound (
          shortcircuit left_result right
        ))
        writeMatchToResult;

      # State[int, Bound] -> State[int, (left_bound) -> Bound] -> State[int, Classifier]
      merge = lift (left: make_right:
        let
          right = make_right left.var_name;
          final = resolver left.var_name right.var_name;
        in
        onPass: onFail: codegen.concat [
          left.code
          right.code
          (final onPass onFail)
        ]);
    in
    left: right: merge (resolveLeft left) (resolveRight right);
  foldM = options: default: lib.foldl (concatM options) (state.return default);

  # instead of concat, use an accumulator to collect the codegen objects
  # (State[int, acc] -> State[int, Classifier] -> State[int, acc]) -> State[int, acc]
  #   acc => { deps :: [ CodeGen ], tail :: Classifier }
  #   value is carried by short-circuiting behavior, either always passing on true, or always failing on false
  # turn classifier into (name, bound) pair, previous value is used for short-circuiting behavior
  foldM2 = lib.foldl';
in
{
  matchers =
    let
      inherit (lib) const attrValues;
      inherit (state) return fmap;
      inherit (codegen) ifExpr;
      # Required for any / all implementations
      or_options = {
        resolver = a: b: ifExpr "\$${a} || \$${b}";
        # (left_result -> Classifier -> Classifier)
        shortcircuit = name: original: onPass: onFail: inline: ifExpr
          "\$${name}"
          onPass
          (original onPass onFail inline)
          inline;
      };
      and_options = {
        resolver = a: b: ifExpr "\$${a} && \$${b}";
        # (left_result -> Classifier -> Classifier)
        shortcircuit = name: original: onPass: onFail: inline: ifExpr
          "\$${name}"
          (original onPass onFail inline)
          onFail
          inline;
      };

      alwaysPass = onPass: _: const onPass;
      alwaysFail = _: onFail: const onFail;

      passAsList = f: x:
        if (builtins.isAttrs x) then
          f (attrValues x)
        else f x;
    in
    {
      # matchVariable: variable -> pattern -> Matcher
      # if [[ $variable == $pattern ]];
      matchVariable = variable: pattern: return (ifExpr "${variable} == ${pattern}");
      # onPass: (Code -> Code) -> Matcher -> Matcher
      #   allows changing of the code run if this classifier passes
      doOnMatch = f: fmap (g: onMatch: g (f onMatch));
      matchAny = passAsList (foldM or_options alwaysFail);
      matchAll = passAsList (foldM and_options alwaysPass);
    };
  eval = lib.flip state.evalState 0;
}
