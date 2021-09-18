{ lib, nix-parsec }:

let
lexer = nix-parsec.lexer;
parsec = nix-parsec.parsec;
in

let
space =
  lexer.space
    (parsec.many1 (parsec.satisfy (i: i == " " || i == "\n"))) # whitespace
    (lexer.skipLineComment ";;") # line comments
    parsec.fail; # we don't have block comments

symbol =
  parsec.fmap
    (xs: { __nixlisp_term = true; type = "symbol"; value = builtins.concatStringsSep "" xs; })
    (parsec.many1 (parsec.satisfy (i:
      (i >= "a" && i <= "z")
        || i == "_"
    )));

nil =
  parsec.fmap
    (_: null)
    (parsec.string "nil");

number =
  lexer.decimal;

bool =
  (parsec.alt
    (parsec.fmap (_: true) (parsec.string "true"))
    (parsec.fmap (_: false) (parsec.string "false")));

atom =
  parsec.choice
    [ nil
      symbol
      number
    ];

list =
  (parsec.between
    (parsec.skipThen (parsec.string "(") space)
    (parsec.skipThen space (parsec.string ")"))
    ((parsec.sepBy expression space)));

expression = parsec.alt atom list;

parser =
  parsec.thenSkip
    (parsec.between space space expression)
    parsec.eof;

in

rec {
  parseString = s:
    let result = parsec.runParser parser s;
    in  if result.type == "success"
        then result.value
        else throw "parse failed: ${builtins.toJSON result.value};";

  parseFile = f: parseString (builtins.readFile f);

  parse = i:
   if builtins.isString i then parseString i
   else if builtins.isPath i then parseFile i
   else throw "Expecting a string or a path, but got ${builtins.typeOf i}.";
}
