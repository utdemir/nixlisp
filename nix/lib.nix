rec {
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
