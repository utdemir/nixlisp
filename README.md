# nix-lisp

A lisp implementation written in pure Nix.

## Features

* Macros
* Nix interop
  * Shares int, bool and string types with Nix
  * Contains helpers to use Nix lists and attrsets
  * Can call Nix functions
  * TODO: Can export functions that can be called from Nix

### Example

```scheme
(import ./default.nix).eval { inherit pkgs; } ''
  (pkgs 'haskellPackages 'ghcWithPackages (lambda (ps) (list ps.lens)))
''
```

## Thanks

* [nprindle/nix-parsec](https://github.com/nprindle/nix-parsec)
