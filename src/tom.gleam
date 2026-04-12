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
  BasicStringToken(String)
  /// A double-quote multi-line string.
  MultiLineBasicStringToken(String)
  /// A single-quote single-line string.
  LiteralStringToken(String)
  /// A single-quote multi-line string.
  MultiLineLiteralStringToken(String)
  /// An unquoted key segment e.g. `wibble`
  BareKeyToken(String)
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
  /// An unexpected character was encountered when parsing the document.
  Unexpected(byte_position: Int, got: String, expected: String)
  // /// More than one items have the same key in the document.
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
  let splitters = Splitters(next: splitter.new(["\n", " ", "="]))
  Lexer(0, src:, splitters:)
}

fn advance(lexer: Lexer, src: String) -> Lexer {
  let position =
    lexer.position + string.byte_size(lexer.src) - string.byte_size(src)
  Lexer(..lexer, position:, src:)
}

type Lexer {
  Lexer(position: Int, src: String, splitters: Splitters)
}

type Splitters {
  Splitters(next: Splitter)
}

fn fold_tokens(
  lexer: Lexer,
  output: output,
  reduce: fn(output, Int, Token) -> Result(output, TomlError),
) -> Result(output, TomlError) {
  case next_token(lexer) {
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

fn next_token(lexer: Lexer) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "" -> Ok(#(lexer, EndOfFile))

    "[[" <> src -> Ok(#(advance(lexer, src), DoubleLeftBracketToken))
    "]]" <> src -> Ok(#(advance(lexer, src), DoubleRightBracketToken))
    "\n" <> src -> Ok(#(advance(lexer, src), NewlineToken))
    "[" <> src -> Ok(#(advance(lexer, src), LeftBracketToken))
    "]" <> src -> Ok(#(advance(lexer, src), RightBracketToken))
    "{" <> src -> Ok(#(advance(lexer, src), LeftBraceToken))
    "}" <> src -> Ok(#(advance(lexer, src), RightBraceToken))
    "." <> src -> Ok(#(advance(lexer, src), DotToken))
    "=" <> src -> Ok(#(advance(lexer, src), EqualsToken))

    "true" <> src -> Ok(#(advance(lexer, src), BoolToken(True)))
    "false" <> src -> Ok(#(advance(lexer, src), BoolToken(False)))

    "nan" <> src -> Ok(#(advance(lexer, src), NanToken(None)))
    "-nan" <> src -> Ok(#(advance(lexer, src), NanToken(Some(Negative))))
    "+nan" <> src -> Ok(#(advance(lexer, src), NanToken(Some(Positive))))

    "inf" <> src -> Ok(#(advance(lexer, src), InfinityToken(None)))
    "-inf" <> src -> Ok(#(advance(lexer, src), InfinityToken(Some(Negative))))
    "+inf" <> src -> Ok(#(advance(lexer, src), InfinityToken(Some(Positive))))

    "#" <> src -> {
      case string.split_once(src, "\n") {
        Ok(#(comment, src)) -> {
          Ok(#(advance(lexer, src), CommentToken(comment)))
        }
        Error(_) -> todo
      }
    }

    src -> {
      todo as src
    }
  }
}
