# StateR[s, a] => { state :: s, value :: a }
# State[s, a] => { runState :: s -> StateR[s, a]}
{ lib }:
let
  # (s -> StateR[s, a]) -> State[s, a]
  mkState = runState: {
    inherit runState;
  };
  # State[s, a] -> (s -> StateR[s, a])
  runState = stateM: stateM.runState;
  # StateR[s, a] -> a
  toValue = stateR: stateR.value;
  # State[s, a] -> StateR[s, _] -> StateR[s, a]
  runStateWithPrev = state: prev: runState state prev.state;
in
rec {
  # a -> State[s, a]
  return = value: mkState (state: {
    inherit state value;
  });
  # State[s, a] -> (a -> State[s, b]) -> State[s, b]
  bind = p: k: mkState (s0:
    let
      s1 = runState p s0;
    in
    runStateWithPrev (k (toValue s1)) s1);
  # (a -> State[s, b]) -> State[s, a] -> State[s, b]
  compose = lib.flip bind;
  # State[s, s]
  get = mkState (state: {
    inherit state;
    value = state;
  });
  # s -> State[s, _]
  put = state: mkState (_: {
    inherit state;
    value = abort "Value not available after `put`";
  });
  # (a -> b) -> State[s, a] -> State[s, b]
  fmap = f: compose (x: return (f x));
  # (a -> b -> c) -> State[s, a] -> State[s, b] -> State[s, c]
  lift = f: a:
    let
      t1 = fmap f a; # State[s, (b -> c)]
    in
    b: mkState (s0:
      let
        s1 = runState t1 s0; # StateR[s, (b -> c)]
        t2 = fmap (toValue s1) b; # State[s, c]
      in
      runStateWithPrev t2 s1);
  # State[s, a] -> State[s, b] -> State[s, a]
  apF = lift (a: _: a);
  # State[s, a] -> State[s, b] -> State[s, b]
  apS = lift (_: b: b);
  # State[s, a] -> s -> a
  evalState = state: initialState:
    let
      s1 = runState state initialState;
    in
    toValue s1;

  # Utils
  # State[s + 1, s]
  getAndIncrement = bind get (value: apS (put (value + 1)) (return value));
}
