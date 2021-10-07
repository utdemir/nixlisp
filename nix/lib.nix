rec {
  exprType = expr:
    if builtins.isList expr then "vector"
    else if builtins.isInt expr then "int"
    else if builtins.isNull expr then "nil"
    else if builtins.isString expr then "string"
    else if builtins.isFunction expr then "nix_function"
    else if builtins.isBool expr then "bool"
    else if builtins.isAttrs expr then
      if builtins.hasAttr "__nixlisp_term" expr
      then expr.type
      else "attrs"
    else throw "unexpected type: ${builtins.typeOf expr}";

  mkTerm = ty: val:
    { __nixlisp_term=true; type=ty; value=val; };

  mkSymbol = mkTerm "symbol";

  mkCons = car: cdr:
    mkTerm "cons" { inherit car cdr; };

  # These definitions are copied from nixpkgs/lib/lists.nix to reduce the dependency footprint
  foldl = op: nul: list:
    let
      foldl' = n:
        if n == -1
        then nul
        else op (foldl' (n - 1)) (builtins.elemAt list n);
    in foldl' (builtins.length list - 1);

  sublist =
    # Index at which to start the sublist
    start:
    # Number of elements to take
    count:
    # Input list
    list:
    let len = builtins.length list; in
    builtins.genList
      (n: builtins.elemAt list (n + start))
      (if start >= len then 0
       else if start + count > len then len - start
       else count);

  drop =
    # Number of elements to drop
    count:
    # Input list
    list: sublist count (builtins.length list) list;
}
