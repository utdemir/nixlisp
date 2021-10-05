# nix-lisp

A lisp implementation written in Nix.

## Features

* No IFD, recursive Nix or anything. Just Nix.
* Macros
* Nix interop
  * Shares int, bool and string types with Nix
  * Contains syntax support and helpers to use Nix lists and attrsets
  * Can call Nix functions seamlessly
  * Can export functions that can be called from Nix (TODO)

### Example

```scheme
(import ./default.nix).eval { inherit pkgs; } ''
  (define nixpkgs
    (fetchTarball
      'url    "https://github.com/nixos/nixpkgs/archive/a39ee95a86b1fbdfa9edd65f3810b23d82457241.tar.gz"
      'sha256 "11sk5hz51189g6a5ahq3s1y65145ra8kcgzfjkmrjp1jzn7h68q8"))
  (define pkgs (import nixpkgs (attrs)))
  (pkgs 'hello 'pname)
''
```

## Thanks

* [nprindle/nix-parsec](https://github.com/nprindle/nix-parsec)
