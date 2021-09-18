{ lib, parser }:

let

exprType = expr:
  if builtins.isList expr then "list"
  else if builtins.isInt expr then "number"
  else if builtins.isNull expr then "nil"
  else if builtins.isString expr then "string"
  else if builtins.isFunction expr then "nix_function"
  else if builtins.isAttrs expr then
    if builtins.hasAttr "__nixlisp_term" expr
    then expr.type
    else "attrset"
  else throw "unexpected type: ${builtins.typeOf expr}";

assertSymbol = expr:
  if exprType expr == "symbol"
  then expr.value
  else throw "expected a symbol, but got a ${exprType expr}";

assertSymbols = expr:
  if exprType expr == "list"
  then builtins.map assertSymbol expr
  else throw "expected a list of symbols, but got a ${exprType expr}";

evaluate = env: expr:
  if exprType expr == "number" then { inherit env; result = expr; }
  else if exprType expr == "nil" then { inherit env; result = null; }
  else if exprType expr == "symbol" then { inherit env; result = env.${expr.value}; }
  else if exprType expr == "list" then
    let
      initialSym = assertSymbol (builtins.elemAt expr 0);
    in
      if initialSym == "define" then
        let name = assertSymbol (builtins.elemAt expr 1);
            value = (evaluate env (builtins.elemAt expr 2)).result;
        in  { env = env // { ${name} = value; }; result = null; }
      else if initialSym == "lambda" then
        let
          args = assertSymbols (builtins.elemAt expr 1);
          body = builtins.elemAt expr 2;
        in
          { inherit env;
            result = { __nixlisp_term = true; type = "lambda"; value = { inherit args body; }; };
          }
      else
        let fun = env."${initialSym}";
            evaluatedArgs = builtins.map (i: (evaluate env i).result) (lib.drop 1 expr);
        in  if exprType fun == "nix_function" then
              { inherit env; result = lib.foldr (x: f: f x) fun evaluatedArgs; }
            else if exprType fun == "lambda" then
              let zipped = lib.zipLists fun.value.args evaluatedArgs;
                  innerEnv = lib.foldl (e: x: e // { "${x.fst}" = x.snd; }) env zipped;
              in  evaluate innerEnv fun.value.body
            else
              throw "Tried to call ${initialSym}, but it is a ${exprType fun}."
  else throw "Unexpected type: ${builtins.typeOf expr}.";

prims = {
  __prim_plus = i: j: i + j;
  __prim_product = i: j: i * j;
  __prim_minus = i: j: i - j;
};

stdenv =
  (evaluate prims (parser.parseFile ../stdlib.nixlisp)).env;

in

{
  eval = i: (evaluate stdenv i).result;
}
