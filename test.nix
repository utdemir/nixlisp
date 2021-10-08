(import ./default.nix).eval {} ''
  (define nixpkgs
    (fetchTarball
       'url "https://github.com/nixos/nixpkgs/archive/a39ee95a86b1fbdfa9edd65f3810b23d82457241.tar.gz"
       'sha256 "11sk5hz51189g6a5ahq3s1y65145ra8kcgzfjkmrjp1jzn7h68q8"))
  (define pkgs (import nixpkgs (attrs)))

  ((pkgs 'haskellPackages 'ghcWithPackages)
      (lambda (ps) (vector (ps 'relude) (ps 'pipes))))
  ''