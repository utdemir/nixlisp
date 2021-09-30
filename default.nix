let
  sources = import ./nix/sources.nix;
  nix-parsec = import sources.nix-parsec;

  lib = import ./nix/lib.nix;
  parser = import ./nix/parser.nix { inherit lib nix-parsec; };
  evaluator = import ./nix/evaluator.nix { inherit lib parser; };
in

{
  inherit parser evaluator;
  eval = env: prg: evaluator.eval env (parser.parse prg);
}
