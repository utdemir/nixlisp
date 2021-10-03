let
sources = import ./deps/sources.nix;
pkgs = import sources.nixpkgs {};
in
pkgs.mkShell {
  name = "nixlisp-shell";
  buildInputs = [ pkgs.python3 pkgs.fd pkgs.entr ];
}
