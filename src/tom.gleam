import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import splitter.{type Splitter}

/// A token produced by lexing TOML source text.
pub type Token {
  WhitespaceToken(String)
  NewlineToken
  /// A comment starting with `#` and ending with `\n`.
  CommentToken(String)
  /// `=`
  EqualsToken
  /// `.`
  DotToken
  /// `,`
  CommaToken
  /// `{`
  LeftBraceToken
  /// `}`
  RightBraceToken
  /// `[`
  LeftBracketToken
  /// `]`
  RightBracketToken
  /// `[[`
  DoubleLeftBracketToken
  /// `]]`
  DoubleRightBracketToken
  /// A double-quote single-line string.
  BasicStringToken(src: String, value: String)
  /// A double-quote multi-line string.
  MultiLineBasicStringToken(src: String, value: String)
  /// A single-quote single-line string.
  LiteralStringToken(src: String)
  /// A single-quote multi-line string.
  MultiLineLiteralStringToken(src: String, value: String)
  /// An unquoted key segment e.g. `wibble`
  BareKeyToken(value: String)
  /// An int e.g `123`
  IntToken(src: String, value: Int)
  /// A float literal e.g. `123.456`
  FloatToken(src: String, value: Float)
  /// inf, -inf, +inf
  InfinityToken(sign: Option(Sign))
  /// nan, -nan, +nan
  NanToken(sign: Option(Sign))
  /// `true` or `false`.
  BoolToken(value: Bool)
  /// A date-time with an offset.
  OffsetDateTimeToken(String)
  /// A date-time with no offset.
  LocalDateTimeToken(String)
  /// A date.
  LocalDateToken(String)
  /// A time.
  LocalTimeToken(String)
  /// The end!
  EndOfFile
}

pub type Sign {
  Positive
  Negative
}

/// An error that can occur when parsing a TOML document.
pub type TomlError {
  UnterminatedString(byte_position: Int)
  IncompleteFloat(byte_position: Int)
  UnknownSequence(byte_position: Int, got: String)
  // KeyAlreadyInUse(key: List(String))
}

// TODO: document
pub fn to_tokens(src: String) -> Result(List(Token), TomlError) {
  new_lexer(src)
  |> fold_tokens([], fn(tokens, _, token) { Ok([token, ..tokens]) })
  |> result.map(list.reverse)
}

fn new_lexer(src: String) -> Lexer {
  let src = string.replace(src, "\r\n", "\n")
  let splitters =
    Splitters(
      literal_string: splitter.new(["\n", "'"]),
      multiline_literal_string: splitter.new(["\n", "'''"]),
    )
  Lexer(0, src:, splitters:)
}

fn step(lexer: Lexer, src: String) -> Lexer {
  let position =
    lexer.position + string.byte_size(lexer.src) - string.byte_size(src)
  Lexer(..lexer, position:, src:)
}

type Lexer {
  Lexer(position: Int, src: String, splitters: Splitters)
}

type Splitters {
  Splitters(literal_string: Splitter, multiline_literal_string: Splitter)
}

fn fold_tokens(
  lexer: Lexer,
  output: output,
  reduce: fn(output, Int, Token) -> Result(output, TomlError),
) -> Result(output, TomlError) {
  case lex(lexer) {
    Ok(#(lexer, EndOfFile as token)) -> {
      reduce(output, lexer.position, token)
    }
    Ok(#(lexer, token)) -> {
      case reduce(output, lexer.position, token) {
        Ok(output) -> fold_tokens(lexer, output, reduce)
        Error(error) -> Error(error)
      }
    }
    Error(error) -> Error(error)
  }
}

fn lex(lexer: Lexer) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "" -> Ok(#(lexer, EndOfFile))

    "[[" <> src -> lexed(lexer, src, DoubleLeftBracketToken)
    "]]" <> src -> lexed(lexer, src, DoubleRightBracketToken)
    "\n" <> src -> lexed(lexer, src, NewlineToken)
    "[" <> src -> lexed(lexer, src, LeftBracketToken)
    "]" <> src -> lexed(lexer, src, RightBracketToken)
    "{" <> src -> lexed(lexer, src, LeftBraceToken)
    "}" <> src -> lexed(lexer, src, RightBraceToken)
    "." <> src -> lexed(lexer, src, DotToken)
    "," <> src -> lexed(lexer, src, CommaToken)
    "=" <> src -> lexed(lexer, src, EqualsToken)

    "true" <> src -> lexed(lexer, src, BoolToken(True))
    "false" <> src -> lexed(lexer, src, BoolToken(False))

    "nan" <> src -> lexed(lexer, src, NanToken(None))
    "-nan" <> src -> lexed(lexer, src, NanToken(Some(Negative)))
    "+nan" <> src -> lexed(lexer, src, NanToken(Some(Positive)))

    "inf" <> src -> lexed(lexer, src, InfinityToken(None))
    "-inf" <> src -> lexed(lexer, src, InfinityToken(Some(Negative)))
    "+inf" <> src -> lexed(lexer, src, InfinityToken(Some(Positive)))

    " " <> _ | "\t" <> _ -> lex_whitespace(lexer)
    "'''" <> src -> lex_multiline_literal_string(step(lexer, src))
    "'" <> src -> lex_literal_string(step(lexer, src))
    "#" <> src -> lex_comment(src, lexer)

    "0" <> src -> lex_number(step(lexer, src), 0, "0")
    "1" <> src -> lex_number(step(lexer, src), 1, "1")
    "2" <> src -> lex_number(step(lexer, src), 2, "2")
    "3" <> src -> lex_number(step(lexer, src), 3, "3")
    "4" <> src -> lex_number(step(lexer, src), 4, "4")
    "5" <> src -> lex_number(step(lexer, src), 5, "5")
    "6" <> src -> lex_number(step(lexer, src), 6, "6")
    "7" <> src -> lex_number(step(lexer, src), 7, "7")
    "8" <> src -> lex_number(step(lexer, src), 8, "8")
    "9" <> src -> lex_number(step(lexer, src), 9, "9")
    "+0" <> src -> lex_number(step(lexer, src), 0, "+0")
    "+1" <> src -> lex_number(step(lexer, src), 1, "+1")
    "+2" <> src -> lex_number(step(lexer, src), 2, "+2")
    "+3" <> src -> lex_number(step(lexer, src), 3, "+3")
    "+4" <> src -> lex_number(step(lexer, src), 4, "+4")
    "+5" <> src -> lex_number(step(lexer, src), 5, "+5")
    "+6" <> src -> lex_number(step(lexer, src), 6, "+6")
    "+7" <> src -> lex_number(step(lexer, src), 7, "+7")
    "+8" <> src -> lex_number(step(lexer, src), 8, "+8")
    "+9" <> src -> lex_number(step(lexer, src), 9, "+9")
    "-0" <> src -> lex_number(step(lexer, src), 0, "-0")
    "-1" <> src -> lex_number(step(lexer, src), 1, "-1")
    "-2" <> src -> lex_number(step(lexer, src), 2, "-2")
    "-3" <> src -> lex_number(step(lexer, src), 3, "-3")
    "-4" <> src -> lex_number(step(lexer, src), 4, "-4")
    "-5" <> src -> lex_number(step(lexer, src), 5, "-5")
    "-6" <> src -> lex_number(step(lexer, src), 6, "-6")
    "-7" <> src -> lex_number(step(lexer, src), 7, "-7")
    "-8" <> src -> lex_number(step(lexer, src), 8, "-8")
    "-9" <> src -> lex_number(step(lexer, src), 9, "-9")

    _ -> lex_bare_key(lexer, "")
  }
}

fn lex_number(
  lexer: Lexer,
  int: Int,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "_" <> src -> lex_number(step(lexer, src), int, text <> "_")
    "0" <> src -> lex_number(step(lexer, src), int * 10 + 0, text <> "0")
    "1" <> src -> lex_number(step(lexer, src), int * 10 + 1, text <> "1")
    "2" <> src -> lex_number(step(lexer, src), int * 10 + 2, text <> "2")
    "3" <> src -> lex_number(step(lexer, src), int * 10 + 3, text <> "3")
    "4" <> src -> lex_number(step(lexer, src), int * 10 + 4, text <> "4")
    "5" <> src -> lex_number(step(lexer, src), int * 10 + 5, text <> "5")
    "6" <> src -> lex_number(step(lexer, src), int * 10 + 6, text <> "6")
    "7" <> src -> lex_number(step(lexer, src), int * 10 + 7, text <> "7")
    "8" <> src -> lex_number(step(lexer, src), int * 10 + 8, text <> "8")
    "9" <> src -> lex_number(step(lexer, src), int * 10 + 9, text <> "9")

    "." <> src -> {
      let float = int.to_float(int)
      lex_float(step(lexer, src), float, 0.1, text <> ".")
    }

    "e+" <> src -> {
      let float = int.to_float(int)
      lex_exponent(step(lexer, src), float, text <> "e+", 0, Positive)
    }
    "e-" <> src -> {
      let float = int.to_float(int)
      lex_exponent(step(lexer, src), float, text <> "e-", 0, Negative)
    }
    "e" <> src -> {
      let float = int.to_float(int)
      lex_exponent(step(lexer, src), float, text <> "e", 0, Positive)
    }
    "E+" <> src -> {
      let float = int.to_float(int)
      lex_exponent(step(lexer, src), float, text <> "E+", 0, Positive)
    }
    "E-" <> src -> {
      let float = int.to_float(int)
      lex_exponent(step(lexer, src), float, text <> "E-", 0, Negative)
    }
    "E" <> src -> {
      let float = int.to_float(int)
      lex_exponent(step(lexer, src), float, text <> "E", 0, Positive)
    }

    src -> {
      let value = case text {
        "-" <> _ -> -int
        _ -> int
      }
      lexed(lexer, src, IntToken(text, value:))
    }
  }
}

fn lex_float(
  lexer: Lexer,
  float: Float,
  unit: Float,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "_" <> src -> lex_float(step(lexer, src), float, unit, text <> "_")
    "0" <> src -> lex_float(step(lexer, src), float, unit *. 0.1, text <> "0")
    "1" <> src -> {
      let float = float +. 1.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "1")
    }
    "2" <> src -> {
      let float = float +. 2.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "2")
    }
    "3" <> src -> {
      let float = float +. 3.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "3")
    }
    "4" <> src -> {
      let float = float +. 4.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "4")
    }
    "5" <> src -> {
      let float = float +. 5.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "5")
    }
    "6" <> src -> {
      let float = float +. 6.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "6")
    }
    "7" <> src -> {
      let float = float +. 7.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "7")
    }
    "8" <> src -> {
      let float = float +. 8.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "8")
    }
    "9" <> src -> {
      let float = float +. 9.0 *. unit
      lex_float(step(lexer, src), float, unit *. 0.1, text <> "9")
    }

    "e+" <> src ->
      lex_exponent(step(lexer, src), float, text <> "e+", 0, Positive)
    "e-" <> src ->
      lex_exponent(step(lexer, src), float, text <> "e-", 0, Negative)
    "e" <> src ->
      lex_exponent(step(lexer, src), float, text <> "e", 0, Positive)
    "E+" <> src ->
      lex_exponent(step(lexer, src), float, text <> "E+", 0, Positive)
    "E-" <> src ->
      lex_exponent(step(lexer, src), float, text <> "E-", 0, Negative)
    "E" <> src ->
      lex_exponent(step(lexer, src), float, text <> "E", 0, Positive)

    _ if unit == 0.1 -> Error(IncompleteFloat(lexer.position - 1))

    src -> {
      let value = case text {
        "-" <> _ -> -1.0 *. float
        _ -> float
      }
      lexed(lexer, src, FloatToken(text, value:))
    }
  }
}

fn lex_exponent(
  lexer: Lexer,
  n: Float,
  text: String,
  ex: Int,
  sign: Sign,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "_" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "_", ex, sign)
    }
    "0" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "0", ex * 10, sign)
    }
    "1" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "1", ex * 10 + 1, sign)
    }
    "2" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "2", ex * 10 + 2, sign)
    }
    "3" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "3", ex * 10 + 3, sign)
    }
    "4" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "4", ex * 10 + 4, sign)
    }
    "5" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "5", ex * 10 + 5, sign)
    }
    "6" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "6", ex * 10 + 6, sign)
    }
    "7" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "7", ex * 10 + 7, sign)
    }
    "8" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "8", ex * 10 + 8, sign)
    }
    "9" <> src -> {
      let lexer = step(lexer, src)
      lex_exponent(lexer, n, text <> "9", ex * 10 + 9, sign)
    }

    // Anything else and the number is terminated
    src -> {
      let n = case text {
        "-" <> _ -> n *. -1.0
        _ -> n
      }
      let exponent =
        int.to_float(case sign {
          Positive -> ex
          Negative -> -ex
        })
      let multiplier = case float.power(10.0, exponent) {
        Ok(multiplier) -> multiplier
        Error(_) -> 1.0
      }
      lexed(lexer, src, FloatToken(text, n *. multiplier))
    }
  }
}

fn lex_whitespace(lexer: Lexer) -> Result(#(Lexer, Token), TomlError) {
  let #(whitespace, src) = take_whitespace("", lexer.src)
  lexed(lexer, src, WhitespaceToken(whitespace))
}

fn lex_bare_key(
  lexer: Lexer,
  content: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "A" as c <> src
    | "B" as c <> src
    | "C" as c <> src
    | "D" as c <> src
    | "E" as c <> src
    | "F" as c <> src
    | "G" as c <> src
    | "H" as c <> src
    | "I" as c <> src
    | "J" as c <> src
    | "K" as c <> src
    | "L" as c <> src
    | "M" as c <> src
    | "N" as c <> src
    | "O" as c <> src
    | "P" as c <> src
    | "Q" as c <> src
    | "R" as c <> src
    | "S" as c <> src
    | "T" as c <> src
    | "U" as c <> src
    | "V" as c <> src
    | "W" as c <> src
    | "X" as c <> src
    | "Y" as c <> src
    | "Z" as c <> src
    | "a" as c <> src
    | "b" as c <> src
    | "c" as c <> src
    | "d" as c <> src
    | "e" as c <> src
    | "f" as c <> src
    | "g" as c <> src
    | "h" as c <> src
    | "i" as c <> src
    | "j" as c <> src
    | "k" as c <> src
    | "l" as c <> src
    | "m" as c <> src
    | "n" as c <> src
    | "o" as c <> src
    | "p" as c <> src
    | "q" as c <> src
    | "r" as c <> src
    | "s" as c <> src
    | "t" as c <> src
    | "u" as c <> src
    | "v" as c <> src
    | "w" as c <> src
    | "x" as c <> src
    | "y" as c <> src
    | "z" as c <> src
    | "0" as c <> src
    | "1" as c <> src
    | "2" as c <> src
    | "3" as c <> src
    | "4" as c <> src
    | "5" as c <> src
    | "6" as c <> src
    | "7" as c <> src
    | "8" as c <> src
    | "9" as c <> src
    | "-" as c <> src
    | "_" as c <> src -> lex_bare_key(step(lexer, src), content <> c)

    src if content != "" -> lexed(lexer, src, BareKeyToken(content))
    src -> {
      let got = case string.pop_grapheme(src) {
        Ok(#(got, _)) -> got
        Error(_) -> ""
      }
      Error(UnknownSequence(lexer.position, got))
    }
  }
}

fn lex_comment(src: String, lexer: Lexer) -> Result(#(Lexer, Token), TomlError) {
  case string.split_once(src, "\n") {
    Ok(#(comment, src)) -> {
      let token = CommentToken(comment <> "\n")
      lexed(lexer, src, token)
    }

    Error(_) -> {
      let token = CommentToken(src)
      lexed(lexer, "", token)
    }
  }
}

fn lex_multiline_literal_string(
  lexer: Lexer,
) -> Result(#(Lexer, Token), TomlError) {
  case string.split_once(lexer.src, "'''") {
    Ok(#(content, src)) -> {
      let value = drop_leading_newline(content)
      lexed(lexer, src, MultiLineLiteralStringToken(content, value:))
    }
    Error(_) -> {
      Error(UnterminatedString(lexer.position - 3))
    }
  }
}

fn drop_leading_newline(src: String) -> String {
  case src {
    "\n" <> src -> src
    src -> src
  }
}

fn lex_literal_string(lexer: Lexer) -> Result(#(Lexer, Token), TomlError) {
  let start_position = lexer.position - 1
  let #(lexer, before, split) =
    run_splitter(lexer, lexer.splitters.literal_string, lexer.src)
  case split {
    "'" -> Ok(#(lexer, LiteralStringToken(before)))
    "\n" -> Error(UnterminatedString(start_position))
    _ -> Error(UnterminatedString(start_position))
  }
}

fn run_splitter(
  lexer: Lexer,
  splitter: Splitter,
  src: String,
) -> #(Lexer, String, String) {
  let #(before, split, after) = splitter.split(splitter, src)
  let lexer = step(lexer, after)
  #(lexer, before, split)
}

fn lexed(
  lexer: Lexer,
  src: String,
  token: Token,
) -> Result(#(Lexer, Token), TomlError) {
  Ok(#(step(lexer, src), token))
}

fn take_whitespace(taken: String, src: String) -> #(String, String) {
  case src {
    // Process indentation in 4 space batches, to reduce loop iterations.
    "    " <> src -> take_whitespace(taken <> "    ", src)
    " " <> src -> take_whitespace(taken <> " ", src)
    "\t" <> src -> take_whitespace(taken <> "\t", src)
    _ -> #(taken, src)
  }
}
