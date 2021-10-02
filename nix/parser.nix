{ lib, nix-parsec }:

let
lexer = nix-parsec.lexer;
parsec = nix-parsec.parsec;
in

let
space =
  lexer.space
    (parsec.many1 (parsec.satisfy (i: i == " " || i == "\n" || i == "\t"))) # whitespace
    (lexer.skipLineComment ";;") # line comments
    parsec.fail; # we don't have block comments

symbol =
  parsec.fmap
    (xs: { __nixlisp_term = true; type = "symbol"; value = builtins.concatStringsSep "" xs; })
    (lexeme (parsec.many1 (parsec.satisfy (i:
      (i >= "a" && i <= "z")
        || (i >= "A" && i <= "Z")
        || i == "_" || i == "-" || i == "?"
    ))));

lexeme = lexer.lexeme space;
string = lexer.symbol space;

number =
  lexeme lexer.decimal;

stringLit =
  lexeme lexer.stringLit;

bool =
  (parsec.alt
    (parsec.fmap (_: true) (string "true"))
    (parsec.fmap (_: false) (string "false")));

atom =
  parsec.choice
    [ symbol
      stringLit
      number
    ];

list =
  let inner =
        parsec.alt
          (parsec.fmap (_: null) (string ")"))
          (parsec.bind
            expression
            (car:
              (parsec.fmap
                (cdr: lib.mkCons car cdr)
                (parsec.alt
                  (parsec.between (string ".") (string ")") expression)
                  inner
                )
              )
            )
          );
   in parsec.skipThen (string "(") inner;

expression = parsec.choice [ atom list quoted_expression ];

quoted_expression =
  parsec.fmap
    (expr: lib.mkCons (lib.mkSymbol "quote") (lib.mkCons expr null))
    (parsec.skipThen (parsec.string "'") expression);

program =
  parsec.sepBy expression space;

parser =
  parsec.thenSkip
    (parsec.between space space program)
    parsec.eof;

in  rec {
  parseString = s:
    let result = parsec.runParser parser s;
    in  if result.type == "success"
        then result.value
        else throw "parse failed; ${result.value}";

  parseFile = f: parseString (builtins.readFile f);

  parse = i:
   if builtins.isString i then parseString i
   else if builtins.isPath i then parseFile i
   else throw "Expecting a string or a path, but got ${builtins.typeOf i}.";
}
