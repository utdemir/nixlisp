let
sources = import ./nix/sources.nix;

lib = (import sources.nixpkgs {}).lib;
nix-parsec = import sources.nix-parsec;

parser = import ./nix/parser.nix { inherit lib nix-parsec; };
evaluator = import ./nix/evaluator.nix { inherit lib parser; };
in

{
  inherit parser evaluator;
  eval = i: evaluator.eval (parser.parse i);
}
