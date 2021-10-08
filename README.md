# nix-lisp

A lisp implementation written in Nix.

## Features

* No IFD, recursive Nix or anything. Just Nix.
* Macros
* Nix interop
  * Shares most of its data types with Nix
  * Contains syntax support and helpers to use Nix lists and attrsets
  * Can call Nix functions seamlessly
  * Can export functions that can be called from Nix

### Example

```scheme
(import ./default.nix).eval {} ''
  (define nixpkgs
    (fetchTarball
       'url "https://github.com/nixos/nixpkgs/archive/a39ee95a86b1fbdfa9edd65f3810b23d82457241.tar.gz"
       'sha256 "11sk5hz51189g6a5ahq3s1y65145ra8kcgzfjkmrjp1jzn7h68q8"))
  (define pkgs (import nixpkgs (attrs)))

  ((pkgs 'haskellPackages 'ghcWithPackages)
      (lambda (ps) (vector (ps 'relude) (ps 'pipes))))
  ''
```

## Docs

### Standard library

See [stdlib.nixlisp](./stdlib.nixlisp).

### Defining a function

```scheme
(defun myDouble (x) 
  (define two 2)
  (+ x two))
```

`defun` is just a macro; the above function expands to:

```scheme
(define myDouble (lambda (x) 
  (begin
    (define two 2)
    (+ x two))))
```

### Defining a macro

```scheme
(defmacro cond args
  (defun go (xs)
    (if
      (nil? xs) 'nil
      (begin
        (define clause (car xs))
        (define condition (car clause))
        (define value (car (cdr clause)))
        (list 'if condition value (go (cdr xs))))))
  (go args))
```

### Defining an attribute set

```scheme
(attrs
  'firstKey "foo"
  'anotherKey 12
  'yetAnotherKey (vector 1 2 3))
```

### Types

| Nix      | Nixlisp               |
| -------- | --------------------- |
| int      | int                   |
| string   | string                |
| bool     | bool                  |
| null     | nil                   |
| function | nix-function          |
| attrs    | attrs                 |
| list     | vector                |
| -        | lambda                |
| -        | symbol                |
| -        | cons                  |
| -        | macro                 |
| float    | (not implemented yet) |
| path     | (not implemented yet) |

#### Nix compatibility

* Types that are unique to Nixlisp are implemented as attribute sets with a special tag on Nix side. They are not meant to be looked inside, but you can pass them back.
* Nixlisp lambda's can be called as normal functions from the Nix side, but they have to have at least one named parameter, and can not have
variable numbero of arguments. Macros can not be used within Nix. 
* nix-function's can be called just as lambda's within Nixlisp. Since they are curried by default, all of the parameters will be passed to them
one after another.
* Attribute sets behave like functions, where you can pass them a list of string or symbols and they can do a lookup.
* Beware that a Nixlisp "list" (a nil-terminated cons-list) is not a Nix "list". A Nix list is called a "vector", and you can use the `vector`, or `list->vector` functions to construct them.

## Thanks

* [nprindle/nix-parsec](https://github.com/nprindle/nix-parsec)
