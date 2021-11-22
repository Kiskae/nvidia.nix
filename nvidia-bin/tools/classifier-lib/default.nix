{ lib
, stateMonad ? import ./state-monad.nix lib
, generators ? import ./bash-generators.nix lib
}:
let
  inherit (stateMonad) return fmap;
  inherit (generators) withIf matchPatterns invert alwaysPass alwaysFail and_expr or_expr;
  # State[int, var_name]
  # (var_name -> var_name -> Generator) -> State[int, Generator] -> State[int, Generator] -> State[int, Generator]
  concatClassifiers =
    let
      # TmpState => { var_name :: str, code :: [ Code ] }
      inherit (stateMonad) getAndIncrement bind lift;
      randomVarName = fmap (x: "_${toString x}") getAndIncrement;
      # Generator -> State[s, TmpState]
      writeToRandomName = input: fmap
        (var_name: {
          inherit var_name;
          code = generators.writeToVariable var_name input;
        })
        randomVarName;
    in
    resolver:
    let
      # State[int, TmpState] -> State[int, TmpState] -> State[int, Generator]
      merge = lift (left: right:
        let
          final = resolver left.var_name right.var_name;
        in
        onPass: onFail: left.code ++ right.code ++ (final onPass onFail));
    in
    left: right:
      let
        # State[s, TmpState]
        left' = bind left writeToRandomName;
        # State[s, TmpState]
        right' = bind right writeToRandomName;
      in
      merge left' right';
  # (var_name -> var_name -> Generator) -> Generator -> [ State[int, Generator] ] -> State[int, Generator]
  foldClassifiers = resolver: default: lib.foldr (concatClassifiers resolver) (return default);
in
{
  # Each matcher should end up returning
  #   Classifier => State[int, Generator]
  lib =
    let
      toList = x:
        if (builtins.isAttrs x) then
          (lib.attrValues x)
        else x;
    in
    {
      # var_name -> pattern -> Classifier
      matchVariable = variable: pattern: return (withIf "${variable} == ${pattern}");
      # var_name -> [ pattern ] -> Classifier
      matchVariableMulti = var: options: return (matchPatterns var options);
      # Classifier -> Classifier
      dontMatch = fmap invert;
      # [ Classifier ] -> Classifier
      matchAny = input: foldClassifiers or_expr alwaysFail (toList input);
      # [ Classifier ] -> Classifier
      matchAll = input: foldClassifiers and_expr alwaysPass (toList input);
    };
  # State[int, Generator] -> Generator
  eval = lib.flip stateMonad.evalState 0;
}
