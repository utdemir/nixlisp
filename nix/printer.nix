{ lib }:

let
printLambdaArgs = args: # FIXME: This is not correct at all
  if lib.exprType args == "cons"
  then "(${print args.value.car} ${printLambdaArgs args.value.cdr})"
  else print args;

print = expr:
  let ty = lib.exprType expr;
  in  if ty == "symbol" then "'${expr.value}"
      else if ty == "int" then builtins.toString expr
      else if ty == "bool" then if expr then "true" else "false"
      else if ty == "string" then "\"${expr}\"" # FIXME: escaping
      else if ty == "nil" then "nil"
      else if ty == "lambda" then "<lambda>"
      else if ty == "macro" then "<macro>"
      else if ty == "nix_function" then "<nix_function>"
      else if ty == "attr" then "{ ${ builtins.toJSON (builtins.attrNames expr) } }"
      else if ty == "cons" then "(cons ${print expr.value.car} ${print expr.value.cdr})"
      else if ty == "vector" then "[" + builtins.concatStringsSep " " (builtins.map print expr) + "]"
      else throw "[print] Unknown type: ${ty}"; # TODO: Add the rest

in

{ inherit print; }