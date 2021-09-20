(import ./default.nix).eval
  { pkgs = import <nixpkgs> {}; } ''
  ((attr pkgs "haskellPackages" "ghcWithPackages")
     (lambda (ps) __builtins_empty_list)
  )
''
