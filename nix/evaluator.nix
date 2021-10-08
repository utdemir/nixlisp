{ lib, parser, printer }:

let

assertSymbol = thr: expr:
  if lib.exprType expr == "symbol"
  then expr.value
  else thr "expected a symbol, but got a ${lib.exprType expr}";

assertMacro = thr: expr:
  if lib.exprType expr == "macro"
  then expr.value
  else thr "expected a macro, but got a ${lib.exprType expr}";

assertLambda = thr: expr:
  if lib.exprType expr == "lambda"
  then expr.value
  else thr "expected a lambda, but got a ${lib.exprType expr}";

assertCons = thr: expr:
  if lib.exprType expr == "cons"
  then expr.value
  else thr "expected a cons, but got a ${lib.exprType expr}";

assertAttrs = thr: expr:
  if lib.exprType expr == "attrs"
  then expr
  else thr "expected an attrs, but got a ${lib.exprType expr}";

assertSymbols = thr: expr:
  if expr == null
  then []
  else
    let c = assertCons thr expr;
    in  [assertSymbol thr c.car] ++ assertSymbols thr c.cdr;

matchList = thr: keys: expr:
  if builtins.length keys == 0
  then if expr == null
       then {}
       else thr "list too long, remaining: ${printer.print expr}"
  else let c = assertCons thr expr;
       in  { "${builtins.elemAt keys 0}" = c.car; } // matchList thr (lib.drop 1 keys) c.cdr;

extendScope = env: scope:
  env // { scope = env.scope // scope; };

addTraceback = env: entry:
  env // { traceback = env.traceback ++ [ entry ]; };

throwWithTraceback = env: msg:
  let traceback = builtins.concatStringsSep "\n" (builtins.map (i: "  ${i}") env.traceback);
  in  throw "Traceback:\n${traceback}\nError:\n  ${msg}";

lambdaFunctor = self:
  let go = env: bindings: arg:
        if lib.exprType bindings == "cons"
        then let name = assertSymbol throw bindings.value.car;
                 env' = extendScope env { ${name} = arg; };
             in  if bindings.value.cdr == null
                 then (evaluate env' self.value.body).result
                 else go env' bindings.value.cdr
        else throw "can not export a function with zero or variable number of arguments.";
   in go (extendScope emptyEnv self.value.scope) self.value.args;

mkLambda = { args, body, scope }:
  lib.mkTerm "lambda" { inherit args body scope; }
    // { __functor = lambdaFunctor; };

mapList = thr: f: xs:
  if xs == null
  then null
  else
    let c = assertCons thr xs;
    in  lib.mkCons (f c.car) (mapList thr f c.cdr);

evaluateList = env: mapList (throwWithTraceback env) (x: (evaluate env x).result);

apply = env: funish: args:
  if lib.exprType funish == "nix_function" then
     # when we have a nix function, we simply pass all the evaluated arguments one after another
     let go = f: x:
       if x == null then f
         else let c = assertCons (throwWithTraceback env) x;
              in go (f c.car) c.cdr;
       in { inherit env; result = go funish args; }
  else if lib.exprType funish == "lambda" then
     # when we have a lambda, we create a new env; assigning arguments to the bindings.
     # if the last binding is null (for a list), every argument is assigned to a binding.
     # if the last binding is not null (dotted pair), rest of the arguments is assigned to last binding (varargs).
     let go = env: bindings: args:
           if bindings == null then
             if args == null
             then env
             else throwWithTraceback env "too many arguments: ${printer.print args}"
           else if lib.exprType bindings == "cons" then
             let b = assertCons (throwWithTraceback env) bindings;
                 c = assertCons (throwWithTraceback env) args;
                 name = assertSymbol (throwWithTraceback env) b.car;
              in go (extendScope env { "${name}" = c.car; }) b.cdr c.cdr
           else
             # varargs
             let binding = assertSymbol (throwWithTraceback env ) bindings;
             in extendScope env { "${binding}" = args; };
         innerEnv = go (extendScope env funish.value.scope) funish.value.args args;
     in # builtins.trace "Called ${printer.print funish} with ${printer.print args}"
           { inherit env; result = (evaluate innerEnv funish.value.body).result; }
   else
     throwWithTraceback env "apply was expecting a function-ish, but got a ${printer.print funish}";

evaluate = env: expr:
  if lib.exprType expr == "int" then { inherit env; result = expr; }
  else if lib.exprType expr == "nil" then { inherit env; result = null; }
  else if lib.exprType expr == "symbol" then
    ( if builtins.hasAttr "${expr.value}" env.scope
      then { inherit env; result = env.scope."${expr.value}"; }
      else (throwWithTraceback env "Symbol not found: ${expr.value}")
    )
  else if lib.exprType expr == "string" then { inherit env; result = expr; }
  else if lib.exprType expr == "vector" then { inherit env; result = expr; }
  else if lib.exprType expr == "lambda" then { inherit env; result = expr; }
  else if lib.exprType expr == "bool" then { inherit env; result = expr; }
  else if lib.exprType expr == "nix_function" then { inherit env; result = expr; }
  else if lib.exprType expr == "macro" then { inherit env; result = expr; }
  else if lib.exprType expr == "cons" then
    let
      car = expr.value.car;
      cdr = expr.value.cdr;
    in
      if car == lib.mkSymbol "define" then
        # 'define' evaluates the second arguments and assigns it to the first symbol
        let c  = matchList (throwWithTraceback (addTraceback env "in a define block")) ["name" "value"] cdr;
            name = assertSymbol (throwWithTraceback env) c.name;
            value = (evaluate (extendScope (addTraceback env "at the definition of '${name}") { ${name} = value; }) c.value).result;
        in  { env = extendScope env { ${name} = value; }; result = null; }
      else if car == lib.mkSymbol "quote" then
        # 'quote ' returns the only argument without evaluating
        let c  = matchList (throwWithTraceback env) ["arg"] cdr;
        in  { inherit env; result = c.arg; }
      else if car == lib.mkSymbol "eval" then
        # 'eval' evaluates its only argument, dual of quote
        let c = matchList (throwWithTraceback env) ["arg"] cdr;
        in  evaluate env (evaluate env c.arg).result
      else if car == lib.mkSymbol "apply" then
        # 'apply' applies the function to unevaluated parameters
        let c = matchList (throwWithTraceback env) ["fun" "params"] cdr;
            fun = (evaluate env c.fun).result;
        in  apply env fun c.params
      else if car == lib.mkSymbol "__throw" then
        # 'throw' throws an exception
        let c = matchList (throwWithTraceback env) ["msg"] cdr;
            msg = (evaluate env c.msg).result;
        in  throwWithTraceback env msg
      else if car == lib.mkSymbol "define-macro" then
        # 'define-macro' creates a 'macro' object carrying the lambda.
        let c = matchList (throwWithTraceback env) ["name" "lambda"] cdr;
            name = assertSymbol (throwWithTraceback env) c.name;
            lambda = (evaluate env c.lambda).result; # TODO: error out when this is not actually a lambda
            value = lib.mkTerm "macro" lambda;
        in { env = extendScope env { ${name} = value; }; result = null; }
      else if car == lib.mkSymbol "__prim_if" then
        # if evaluates the first argument, if null or false, evaluates & returns the third; else the second
        let c = matchList (throwWithTraceback env) ["cond" "if_t" "if_f"] cdr;
            cond = (evaluate env c.cond).result;
            branch = if cond == true then c.if_t else c.if_f;
            result = (evaluate env branch).result;
        in { inherit env result; }
      else if car == lib.mkSymbol "begin" then
        # evaluates all arguments one after another in the same environment
        let go = prev: xs:
              if xs == null
              then prev
              else let c = assertCons (throwWithTraceback env) xs;
                       curr = evaluate prev.env c.car;
                   in  builtins.seq curr.result (go curr c.cdr);
            result = (go { inherit env; result = null; } cdr).result;
        in { inherit env result; }
      else if car == lib.mkSymbol "lambda" then
        # 'lambda' creates a 'lambda' object carrying the arguments and the body.
        let c = matchList (throwWithTraceback env) ["args" "body"] cdr;
            args = c.args;
            body = c.body;
            result = mkLambda { inherit args body; scope = env.scope; };
        in { inherit env result; }
      else
        let fun = (evaluate env expr.value.car).result;
        in  if lib.exprType fun == "nix_function" || lib.exprType fun == "lambda" then
              let innerEnv = addTraceback env "while calling ${printer.print expr.value.car} with ${printer.print expr.value.cdr}";
                  paramEnv = addTraceback env "while evaluating the parameters of ${printer.print expr.value.car}";
                  result = (apply innerEnv fun (evaluateList paramEnv cdr)).result;
              in  { inherit env result; }
            else if lib.exprType fun == "macro" then
              let
                expansion =
                  let env' = addTraceback env "while expanding the macro ${printer.print expr.value.car}";
                  in  (apply env' fun.value cdr).result;
              in  evaluate env expansion
            else if lib.exprType fun == "attrs" then
              # attr's should behave like functions, they take a string or a symbol and do a lookup.
              # this is implemented in stdlib, so we simply wrap that in an "getattr" call.
              evaluate env (lib.mkCons (lib.mkSymbol "getattr") expr)
            else
              throwWithTraceback env "Expecting a function call, but got ${printer.print fun}."
  else throw "Unexpected expression: ${printer.print expr}.";

evaluateProgram = env: program:
  if builtins.isList program
  then lib.foldl (acc: x: evaluate acc.env x) { inherit env; result = null; } (program)
  else throw "invariant violation: program is not a list";

nixify = x:
  let ty = lib.exprType x;
  in if ty == "symbol" then x.value
      else if ty == "cons" then throw "TODO"
      else throw "TODO";

# Build the standard environment

prims = {
  # values
  __prim_null = null;
  __prim_true = true;
  __prim_false = false;
  __prim_vector_empty = [];
  __prim_vector_singleton = x: [ x ];
  __prim_name_value_pair = name: value: { inherit name value; };

  __prim_symbol_name = x: x.value;
  __prim_expr_type = x: lib.exprType x;
  __prim_cons = ca: cd: lib.mkCons ca cd;

  __prim_macro_to_lambda = macro: macro.value;

  # operators
  __prim_plus = i: j: i + j;
  __prim_product = i: j: i * j;
  __prim_minus = i: j: i - j;
  __prim_equals = i: j: i == j;
  __prim_and = i: j: i && j;
  __prim_or = i: j: i || j;
  __prim_lt = i: j: i < j;
  __prim_gt = i: j: i > j;
  __prim_append = i: j: i ++ j;
  __prim_merge = i: j: assertAttrs throw i // assertAttrs throw j;

  # accessors
  __prim_car = xs: xs.value.car;
  __prim_cdr = xs: xs.value.cdr;

  # builtins
  __builtins = builtins;
  __prim_get_attr = builtins.getAttr; # we need this directly to access the builtins
};

emptyEnv =
  { scope = prims;
    traceback = [];
  };

stdenv =
  (evaluateProgram emptyEnv (parser.parseFile ../stdlib.nixlisp)).env;

initialEnv = scope: stdenv // { scope = stdenv.scope // scope; };

in

{
  eval = scope: i: (evaluateProgram (initialEnv scope) i).result;
}
