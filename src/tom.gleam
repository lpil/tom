import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar.{
  type Month, April, August, December, February, January, July, June, March, May,
  November, October, September,
}
import gleam/time/duration.{type Duration}
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
  OffsetDateTimeToken(
    src: String,
    date: calendar.Date,
    time: calendar.TimeOfDay,
    offset: Duration,
  )
  /// A date-time with no offset.
  LocalDateTimeToken(src: String, date: calendar.Date, time: calendar.TimeOfDay)
  /// A date.
  LocalDateToken(src: String, date: calendar.Date)
  /// A time.
  LocalTimeToken(src: String, time: calendar.TimeOfDay)
  /// The end!
  EndOfFileToken
}

pub type Symbol {
  WhitespaceSymbol(postition: Int, src: String)
  NewlineSymbol(position: Int)
  /// A comment starting with `#` and ending with `\n`.
  CommentSymbol(position: Int, src: String)
  /// `=`
  EqualsSymbol(position: Int)
  /// `,`
  CommaSymbol(position: Int)
  /// `{`
  InlineTableStartSymbol(position: Int)
  /// `}`
  InlineTableEndSymbol(position: Int)
  /// `[`
  ArrayStartSymbol(position: Int)
  /// `]`
  ArrayEndSymbol(position: Int)
  /// `[wibble]`
  TableHeader(position: Int)
  /// `[[wibble]]`
  ArrayTableHeader(position: Int)
  /// An key
  KeySymbol(position: Int, value: String)
  /// A double-quote single-line string.
  BasicStringSymbol(position: Int, src: String, value: String)
  /// A double-quote multi-line string.
  MultiLineBasicStringSymbol(position: Int, src: String, value: String)
  /// A single-quote single-line string.
  LiteralStringSymbol(position: Int, src: String)
  /// A single-quote multi-line string.
  MultiLineLiteralStringSymbol(position: Int, src: String, value: String)
  /// An int e.g `123`
  IntSymbol(position: Int, src: String, value: Int)
  /// A float literal e.g. `123.456`
  FloatSymbol(position: Int, src: String, value: Float)
  /// inf, -inf, +inf
  InfinitySymbol(position: Int, sign: Option(Sign))
  /// nan, -nan, +nan
  NanSymbol(position: Int, sign: Option(Sign))
  /// `true` or `false`.
  BoolSymbol(position: Int, value: Bool)
  /// A date-time with an offset.
  OffsetDateTimeSymbol(
    position: Int,
    src: String,
    date: calendar.Date,
    time: calendar.TimeOfDay,
    offset: Duration,
  )
  /// A date-time with no offset.
  LocalDateTimeSymbol(
    position: Int,
    src: String,
    date: calendar.Date,
    time: calendar.TimeOfDay,
  )
  /// A date.
  LocalDateSymbol(position: Int, src: String, date: calendar.Date)
  /// A time.
  LocalTimeSymbol(position: Int, src: String, time: calendar.TimeOfDay)
}

pub type Sign {
  Positive
  Negative
}

/// An error that can occur when parsing a TOML document.
pub type TomlError {
  UnterminatedString(byte_position: Int)
  IncompleteFloat(byte_position: Int)
  IncompleteDate(byte_position: Int)
  IncompleteTime(byte_position: Int)
  UnknownSequence(byte_position: Int)
  InvalidEscapeSequence(byte_position: Int)
  UnknownEscapeSequence(byte_position: Int)
  // KeyAlreadyInUse(key: List(String))
}

// TODO: document
pub fn to_tokens(src: String) -> Result(List(Token), TomlError) {
  new_lexer(src)
  |> fold_tokens([], fn(tokens, _, token) { Ok([token, ..tokens]) })
  |> result.map(list.reverse)
}

// TODO: document
pub fn to_symbols(src: String) -> Result(List(Symbol), TomlError) {
  new_lexer(src)
  |> fold_symbols([], fn(symbols, symbol) { Ok([symbol, ..symbols]) })
  |> result.map(list.reverse)
}

fn new_lexer(src: String) -> Lexer {
  let src = string.replace(src, "\r\n", "\n")
  let splitters =
    Splitters(
      literal_string: splitter.new(["\n", "'"]),
      basic_string: splitter.new(["\n", "\"", "\\"]),
      multiline_basic_string: splitter.new(["\"\"\"", "\\"]),
    )
  Lexer(0, src:, splitters:)
}

fn lex_step(lexer: Lexer, src: String) -> Lexer {
  let position =
    lexer.position + string.byte_size(lexer.src) - string.byte_size(src)
  Lexer(..lexer, position:, src:)
}

type Lexer {
  Lexer(position: Int, src: String, splitters: Splitters)
}

fn symbolise(lexer: Lexer) -> Result(#(Lexer, List(Symbol)), TomlError) {
  case lex(lexer) {
    Ok(#(lexer, token)) ->
      case token {
        NewlineToken -> Ok(#(lexer, [NewlineSymbol(lexer.position)]))
        WhitespaceToken(src) ->
          Ok(#(lexer, [WhitespaceSymbol(lexer.position, src)]))

        BareKeyToken(value:) -> symbolise_key(lexer, [value], value)

        CommentToken(_) -> todo
        EqualsToken -> todo
        DotToken -> todo
        CommaToken -> todo
        LeftBraceToken -> todo
        RightBraceToken -> todo
        LeftBracketToken -> todo
        RightBracketToken -> todo
        DoubleLeftBracketToken -> todo
        DoubleRightBracketToken -> todo
        BasicStringToken(src:, value:) -> todo
        MultiLineBasicStringToken(src:, value:) -> todo
        LiteralStringToken(src:) -> todo
        MultiLineLiteralStringToken(src:, value:) -> todo
        IntToken(src:, value:) -> todo
        FloatToken(src:, value:) -> todo
        InfinityToken(sign:) -> todo
        NanToken(sign:) -> todo
        BoolToken(value:) -> todo
        OffsetDateTimeToken(src:, date:, time:, offset:) -> todo
        LocalDateTimeToken(src:, date:, time:) -> todo
        LocalDateToken(src:, date:) -> todo
        LocalTimeToken(src:, time:) -> todo
        EndOfFileToken -> todo
      }
    Error(e) -> Error(e)
  }
}

fn symbolise_key(
  lexer: Lexer,
  segments: List(String),
  src: String,
) -> Result(#(Lexer, List(Symbol)), TomlError) {
  case lex(lexer) {
    Error(e) -> Error(e)
    Ok(#(lexer, BareKeyToken(value:))) ->
      symbolise_key(lexer, [value, ..segments], src <> value)

    Ok(#(lexer, token)) -> todo as string.inspect(token)
  }
  // WhitespaceToken(_) -> todo
  // NewlineToken -> todo
  // CommentToken(_) -> todo
  // EqualsToken -> todo
  // DotToken -> todo
  // CommaToken -> todo
  // LeftBraceToken -> todo
  // RightBraceToken -> todo
  // LeftBracketToken -> todo
  // RightBracketToken -> todo
  // DoubleLeftBracketToken -> todo
  // DoubleRightBracketToken -> todo
  // BasicStringToken(src:, value:) -> todo
  // MultiLineBasicStringToken(src:, value:) -> todo
  // LiteralStringToken(src:) -> todo
  // MultiLineLiteralStringToken(src:, value:) -> todo
  // IntToken(src:, value:) -> todo
  // FloatToken(src:, value:) -> todo
  // InfinityToken(sign:) -> todo
  // NanToken(sign:) -> todo
  // BoolToken(value:) -> todo
  // OffsetDateTimeToken(src:, date:, time:, offset:) -> todo
  // LocalDateTimeToken(src:, date:, time:) -> todo
  // LocalDateToken(src:, date:) -> todo
  // LocalTimeToken(src:, time:) -> todo
  // EndOfFileToken -> todo
}

type Splitters {
  Splitters(
    literal_string: Splitter,
    basic_string: Splitter,
    multiline_basic_string: Splitter,
  )
}

fn fold_symbols(
  lexer: Lexer,
  output: output,
  reduce: fn(output, Symbol) -> Result(output, TomlError),
) -> Result(output, TomlError) {
  case symbolise(lexer) {
    Ok(#(_lexer, [])) -> Ok(output)
    Ok(#(lexer, symbols)) -> {
      case list.try_fold(symbols, output, reduce) {
        Ok(output) -> fold_symbols(lexer, output, reduce)
        Error(error) -> Error(error)
      }
    }
    Error(error) -> Error(error)
  }
}

fn fold_tokens(
  lexer: Lexer,
  output: output,
  reduce: fn(output, Int, Token) -> Result(output, TomlError),
) -> Result(output, TomlError) {
  case lex(lexer) {
    Ok(#(lexer, EndOfFileToken as token)) -> {
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
    "" -> Ok(#(lexer, EndOfFileToken))

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
    "#" <> src -> lex_comment(src, lexer)

    "'''" <> src -> lex_multiline_literal_string(lex_step(lexer, src))
    "'" <> src -> lex_literal_string(lex_step(lexer, src))

    "\"\"\"" <> src -> lex_multiline_basic_string(lex_step(lexer, src), "", "")
    "\"" <> src -> lex_basic_string(lex_step(lexer, src), "", "")

    "0" <> src -> lex_number(lex_step(lexer, src), 0, "0")
    "1" <> src -> lex_number(lex_step(lexer, src), 1, "1")
    "2" <> src -> lex_number(lex_step(lexer, src), 2, "2")
    "3" <> src -> lex_number(lex_step(lexer, src), 3, "3")
    "4" <> src -> lex_number(lex_step(lexer, src), 4, "4")
    "5" <> src -> lex_number(lex_step(lexer, src), 5, "5")
    "6" <> src -> lex_number(lex_step(lexer, src), 6, "6")
    "7" <> src -> lex_number(lex_step(lexer, src), 7, "7")
    "8" <> src -> lex_number(lex_step(lexer, src), 8, "8")
    "9" <> src -> lex_number(lex_step(lexer, src), 9, "9")
    "+0" <> src -> lex_number(lex_step(lexer, src), 0, "+0")
    "+1" <> src -> lex_number(lex_step(lexer, src), 1, "+1")
    "+2" <> src -> lex_number(lex_step(lexer, src), 2, "+2")
    "+3" <> src -> lex_number(lex_step(lexer, src), 3, "+3")
    "+4" <> src -> lex_number(lex_step(lexer, src), 4, "+4")
    "+5" <> src -> lex_number(lex_step(lexer, src), 5, "+5")
    "+6" <> src -> lex_number(lex_step(lexer, src), 6, "+6")
    "+7" <> src -> lex_number(lex_step(lexer, src), 7, "+7")
    "+8" <> src -> lex_number(lex_step(lexer, src), 8, "+8")
    "+9" <> src -> lex_number(lex_step(lexer, src), 9, "+9")
    "-0" <> src -> lex_number(lex_step(lexer, src), 0, "-0")
    "-1" <> src -> lex_number(lex_step(lexer, src), 1, "-1")
    "-2" <> src -> lex_number(lex_step(lexer, src), 2, "-2")
    "-3" <> src -> lex_number(lex_step(lexer, src), 3, "-3")
    "-4" <> src -> lex_number(lex_step(lexer, src), 4, "-4")
    "-5" <> src -> lex_number(lex_step(lexer, src), 5, "-5")
    "-6" <> src -> lex_number(lex_step(lexer, src), 6, "-6")
    "-7" <> src -> lex_number(lex_step(lexer, src), 7, "-7")
    "-8" <> src -> lex_number(lex_step(lexer, src), 8, "-8")
    "-9" <> src -> lex_number(lex_step(lexer, src), 9, "-9")

    _ -> lex_bare_key(lexer, "")
  }
}

fn lex_number(
  lexer: Lexer,
  int: Int,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "_" <> src -> lex_number(lex_step(lexer, src), int, text <> "_")
    "0" <> src -> lex_number(lex_step(lexer, src), int * 10 + 0, text <> "0")
    "1" <> src -> lex_number(lex_step(lexer, src), int * 10 + 1, text <> "1")
    "2" <> src -> lex_number(lex_step(lexer, src), int * 10 + 2, text <> "2")
    "3" <> src -> lex_number(lex_step(lexer, src), int * 10 + 3, text <> "3")
    "4" <> src -> lex_number(lex_step(lexer, src), int * 10 + 4, text <> "4")
    "5" <> src -> lex_number(lex_step(lexer, src), int * 10 + 5, text <> "5")
    "6" <> src -> lex_number(lex_step(lexer, src), int * 10 + 6, text <> "6")
    "7" <> src -> lex_number(lex_step(lexer, src), int * 10 + 7, text <> "7")
    "8" <> src -> lex_number(lex_step(lexer, src), int * 10 + 8, text <> "8")
    "9" <> src -> lex_number(lex_step(lexer, src), int * 10 + 9, text <> "9")

    "-" <> src -> lex_date(lex_step(lexer, src), int, text <> "-")
    ":" <> src if int < 24 ->
      lex_time_minute(lex_step(lexer, src), int, text <> ":")

    "." <> src -> {
      let float = int.to_float(int)
      lex_float(lex_step(lexer, src), float, 0.1, text <> ".")
    }

    "e+" <> src -> {
      let float = int.to_float(int)
      lex_exponent(lex_step(lexer, src), float, text <> "e+", 0, Positive)
    }
    "e-" <> src -> {
      let float = int.to_float(int)
      lex_exponent(lex_step(lexer, src), float, text <> "e-", 0, Negative)
    }
    "e" <> src -> {
      let float = int.to_float(int)
      lex_exponent(lex_step(lexer, src), float, text <> "e", 0, Positive)
    }
    "E+" <> src -> {
      let float = int.to_float(int)
      lex_exponent(lex_step(lexer, src), float, text <> "E+", 0, Positive)
    }
    "E-" <> src -> {
      let float = int.to_float(int)
      lex_exponent(lex_step(lexer, src), float, text <> "E-", 0, Negative)
    }
    "E" <> src -> {
      let float = int.to_float(int)
      lex_exponent(lex_step(lexer, src), float, text <> "E", 0, Positive)
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

fn lex_date(
  lexer: Lexer,
  year: Int,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "01-" <> src -> lex_day(lex_step(lexer, src), year, January, text <> "01-")
    "02-" <> src -> lex_day(lex_step(lexer, src), year, February, text <> "02-")
    "03-" <> src -> lex_day(lex_step(lexer, src), year, March, text <> "03-")
    "04-" <> src -> lex_day(lex_step(lexer, src), year, April, text <> "04-")
    "05-" <> src -> lex_day(lex_step(lexer, src), year, May, text <> "05-")
    "06-" <> src -> lex_day(lex_step(lexer, src), year, June, text <> "06-")
    "07-" <> src -> lex_day(lex_step(lexer, src), year, July, text <> "07-")
    "08-" <> src -> lex_day(lex_step(lexer, src), year, August, text <> "08-")
    "09-" <> src ->
      lex_day(lex_step(lexer, src), year, September, text <> "09-")
    "10-" <> src -> lex_day(lex_step(lexer, src), year, October, text <> "10-")
    "11-" <> src -> lex_day(lex_step(lexer, src), year, November, text <> "11-")
    "12-" <> src -> lex_day(lex_step(lexer, src), year, December, text <> "12-")
    _ -> Error(IncompleteDate(lexer.position))
  }
}

fn lex_day(
  lexer: Lexer,
  year: Int,
  month: Month,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "01" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 1, text <> "01")
    "02" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 2, text <> "02")
    "03" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 3, text <> "03")
    "04" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 4, text <> "04")
    "05" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 5, text <> "05")
    "06" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 6, text <> "06")
    "07" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 7, text <> "07")
    "08" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 8, text <> "08")
    "09" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 9, text <> "09")
    "10" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 10, text <> "10")
    "11" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 11, text <> "11")
    "12" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 12, text <> "12")
    "13" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 13, text <> "13")
    "14" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 14, text <> "14")
    "15" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 15, text <> "15")
    "16" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 16, text <> "16")
    "17" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 17, text <> "17")
    "18" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 18, text <> "18")
    "19" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 19, text <> "19")
    "20" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 20, text <> "20")
    "21" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 21, text <> "21")
    "22" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 22, text <> "22")
    "23" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 23, text <> "23")
    "24" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 24, text <> "24")
    "25" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 25, text <> "25")
    "26" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 26, text <> "26")
    "27" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 27, text <> "27")
    "28" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 28, text <> "28")
    "29" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 29, text <> "29")
    "30" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 30, text <> "30")
    "31" <> src ->
      lex_date_end(lex_step(lexer, src), year, month, 31, text <> "31")
    _ -> Error(IncompleteDate(lexer.position))
  }
}

fn lex_date_end(
  lexer: Lexer,
  year: Int,
  month: Month,
  day: Int,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  let date = calendar.Date(year, month, day)
  case lexer.src {
    " " as delimeter <> src | "T" as delimeter <> src -> {
      let lexer = lex_step(lexer, src)
      let text = text <> delimeter
      use #(lexer, text, time) <- result.try(lex_time_value(lexer, text))
      lex_datetime_offset(lexer, date, time, text)
    }

    _ -> Ok(#(lexer, LocalDateToken(text, date)))
  }
}

fn lex_datetime_offset(
  lexer: Lexer,
  date: calendar.Date,
  time: calendar.TimeOfDay,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "Z" <> src -> {
      let lexer = lex_step(lexer, src)
      let text = text <> "Z"
      let offset = calendar.utc_offset
      let token = OffsetDateTimeToken(src: text, date:, time:, offset:)
      Ok(#(lexer, token))
    }
    "+" <> src -> {
      let lexer = lex_step(lexer, src)
      let text = text <> "+"
      use #(lexer, text, offset) <- result.try(lex_offset(lexer, text, Positive))
      let token = OffsetDateTimeToken(src: text, date:, time:, offset:)
      Ok(#(lexer, token))
    }
    "-" <> src -> {
      let lexer = lex_step(lexer, src)
      let text = text <> "-"
      use #(lexer, text, offset) <- result.try(lex_offset(lexer, text, Negative))
      let token = OffsetDateTimeToken(src: text, date:, time:, offset:)
      Ok(#(lexer, token))
    }

    _ -> Ok(#(lexer, LocalDateTimeToken(text, date:, time:)))
  }
}

fn lex_offset(
  lexer: Lexer,
  text: String,
  sign: Sign,
) -> Result(#(Lexer, String, Duration), TomlError) {
  use #(lexer, text, hours, minutes) <- result.try(lex_hour_minute(lexer, text))
  let duration = case sign {
    Positive -> duration.add(duration.hours(hours), duration.minutes(minutes))
    Negative -> duration.add(duration.hours(-hours), duration.minutes(-minutes))
  }
  Ok(#(lexer, text, duration))
}

fn lex_time_value(
  lexer: Lexer,
  text: String,
) -> Result(#(Lexer, String, calendar.TimeOfDay), TomlError) {
  use #(lexer, text, hours, minutes) <- result.try(lex_hour_minute(lexer, text))
  use #(lexer, text, seconds, ns) <- result.try(lex_seconds(lexer, text))
  let time = calendar.TimeOfDay(hours, minutes, seconds, ns)
  Ok(#(lexer, text, time))
}

fn lex_hour_minute(
  lexer: Lexer,
  text: String,
) -> Result(#(Lexer, String, Int, Int), TomlError) {
  use #(lexer, hours, text) <- result.try(case lexer.src {
    "00:" as t <> src -> Ok(#(lex_step(lexer, src), 0, text <> t))
    "01:" as t <> src -> Ok(#(lex_step(lexer, src), 1, text <> t))
    "02:" as t <> src -> Ok(#(lex_step(lexer, src), 2, text <> t))
    "03:" as t <> src -> Ok(#(lex_step(lexer, src), 3, text <> t))
    "04:" as t <> src -> Ok(#(lex_step(lexer, src), 4, text <> t))
    "05:" as t <> src -> Ok(#(lex_step(lexer, src), 5, text <> t))
    "06:" as t <> src -> Ok(#(lex_step(lexer, src), 6, text <> t))
    "07:" as t <> src -> Ok(#(lex_step(lexer, src), 7, text <> t))
    "08:" as t <> src -> Ok(#(lex_step(lexer, src), 8, text <> t))
    "09:" as t <> src -> Ok(#(lex_step(lexer, src), 9, text <> t))
    "10:" as t <> src -> Ok(#(lex_step(lexer, src), 10, text <> t))
    "11:" as t <> src -> Ok(#(lex_step(lexer, src), 11, text <> t))
    "12:" as t <> src -> Ok(#(lex_step(lexer, src), 12, text <> t))
    "13:" as t <> src -> Ok(#(lex_step(lexer, src), 13, text <> t))
    "14:" as t <> src -> Ok(#(lex_step(lexer, src), 14, text <> t))
    "15:" as t <> src -> Ok(#(lex_step(lexer, src), 15, text <> t))
    "16:" as t <> src -> Ok(#(lex_step(lexer, src), 16, text <> t))
    "17:" as t <> src -> Ok(#(lex_step(lexer, src), 17, text <> t))
    "18:" as t <> src -> Ok(#(lex_step(lexer, src), 18, text <> t))
    "19:" as t <> src -> Ok(#(lex_step(lexer, src), 19, text <> t))
    "20:" as t <> src -> Ok(#(lex_step(lexer, src), 20, text <> t))
    "21:" as t <> src -> Ok(#(lex_step(lexer, src), 21, text <> t))
    "22:" as t <> src -> Ok(#(lex_step(lexer, src), 22, text <> t))
    "23:" as t <> src -> Ok(#(lex_step(lexer, src), 23, text <> t))
    _ -> Error(IncompleteTime(lexer.position))
  })
  use #(lexer, text, minutes) <- result.try(lex_number_under_60(lexer, text))
  Ok(#(lexer, text, hours, minutes))
}

fn lex_time_minute(
  lexer: Lexer,
  hours: Int,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  use #(lexer, text, minutes) <- result.try(lex_number_under_60(lexer, text))
  use #(lexer, text, seconds, ns) <- result.try(lex_seconds(lexer, text))
  let time = calendar.TimeOfDay(hours, minutes, seconds, ns)
  Ok(#(lexer, LocalTimeToken(text, time)))
}

fn lex_seconds(
  lexer: Lexer,
  text: String,
) -> Result(#(Lexer, String, Int, Int), TomlError) {
  case lexer.src {
    ":" <> src -> {
      let text = text <> ":"
      let lexer = lex_step(lexer, src)
      use #(lexer, text, seconds) <- result.try(lex_number_under_60(lexer, text))
      case lexer.src {
        "." <> src -> {
          let lexer = lex_step(lexer, src)
          let text = text <> "."
          parse_time_ns(lexer, text, seconds, 0, 0)
        }
        _ -> Ok(#(lexer, text, seconds, 0))
      }
    }

    _ -> Ok(#(lexer, text, 0, 0))
  }
}

fn parse_time_ns(
  lexer: Lexer,
  text: String,
  seconds: Int,
  ns: Int,
  digits_count: Int,
) -> Result(#(Lexer, String, Int, Int), TomlError) {
  case lexer.src {
    "0" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "0", seconds, ns * 10 + 0, digits_count + 1)
    }
    "1" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "1", seconds, ns * 10 + 1, digits_count + 1)
    }
    "2" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "2", seconds, ns * 10 + 2, digits_count + 1)
    }
    "3" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "3", seconds, ns * 10 + 3, digits_count + 1)
    }
    "4" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "4", seconds, ns * 10 + 4, digits_count + 1)
    }
    "5" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "5", seconds, ns * 10 + 5, digits_count + 1)
    }
    "6" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "6", seconds, ns * 10 + 6, digits_count + 1)
    }
    "7" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "7", seconds, ns * 10 + 7, digits_count + 1)
    }
    "8" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "8", seconds, ns * 10 + 8, digits_count + 1)
    }
    "9" <> src if digits_count < 9 -> {
      let lexer = lex_step(lexer, src)
      parse_time_ns(lexer, text <> "9", seconds, ns * 10 + 9, digits_count + 1)
    }

    _ if digits_count == 0 -> Error(IncompleteTime(lexer.position))

    _ -> {
      let exponent = int.to_float(9 - digits_count)
      let assert Ok(multiplier) = float.power(10.0, exponent)
      Ok(#(lexer, text, seconds, ns * float.truncate(multiplier)))
    }
  }
}

fn lex_number_under_60(
  lexer: Lexer,
  text: String,
) -> Result(#(Lexer, String, Int), TomlError) {
  case lexer.src {
    "00" <> src -> Ok(#(lex_step(lexer, src), text <> "00", 0))
    "01" <> src -> Ok(#(lex_step(lexer, src), text <> "01", 1))
    "02" <> src -> Ok(#(lex_step(lexer, src), text <> "02", 2))
    "03" <> src -> Ok(#(lex_step(lexer, src), text <> "03", 3))
    "04" <> src -> Ok(#(lex_step(lexer, src), text <> "04", 4))
    "05" <> src -> Ok(#(lex_step(lexer, src), text <> "05", 5))
    "06" <> src -> Ok(#(lex_step(lexer, src), text <> "06", 6))
    "07" <> src -> Ok(#(lex_step(lexer, src), text <> "07", 7))
    "08" <> src -> Ok(#(lex_step(lexer, src), text <> "08", 8))
    "09" <> src -> Ok(#(lex_step(lexer, src), text <> "09", 9))
    "10" <> src -> Ok(#(lex_step(lexer, src), text <> "10", 10))
    "11" <> src -> Ok(#(lex_step(lexer, src), text <> "11", 11))
    "12" <> src -> Ok(#(lex_step(lexer, src), text <> "12", 12))
    "13" <> src -> Ok(#(lex_step(lexer, src), text <> "13", 13))
    "14" <> src -> Ok(#(lex_step(lexer, src), text <> "14", 14))
    "15" <> src -> Ok(#(lex_step(lexer, src), text <> "15", 15))
    "16" <> src -> Ok(#(lex_step(lexer, src), text <> "16", 16))
    "17" <> src -> Ok(#(lex_step(lexer, src), text <> "17", 17))
    "18" <> src -> Ok(#(lex_step(lexer, src), text <> "18", 18))
    "19" <> src -> Ok(#(lex_step(lexer, src), text <> "19", 19))
    "20" <> src -> Ok(#(lex_step(lexer, src), text <> "20", 20))
    "21" <> src -> Ok(#(lex_step(lexer, src), text <> "21", 21))
    "22" <> src -> Ok(#(lex_step(lexer, src), text <> "22", 22))
    "23" <> src -> Ok(#(lex_step(lexer, src), text <> "23", 23))
    "24" <> src -> Ok(#(lex_step(lexer, src), text <> "24", 24))
    "25" <> src -> Ok(#(lex_step(lexer, src), text <> "25", 25))
    "26" <> src -> Ok(#(lex_step(lexer, src), text <> "26", 26))
    "27" <> src -> Ok(#(lex_step(lexer, src), text <> "27", 27))
    "28" <> src -> Ok(#(lex_step(lexer, src), text <> "28", 28))
    "29" <> src -> Ok(#(lex_step(lexer, src), text <> "29", 29))
    "30" <> src -> Ok(#(lex_step(lexer, src), text <> "30", 30))
    "31" <> src -> Ok(#(lex_step(lexer, src), text <> "31", 31))
    "32" <> src -> Ok(#(lex_step(lexer, src), text <> "32", 32))
    "33" <> src -> Ok(#(lex_step(lexer, src), text <> "33", 33))
    "34" <> src -> Ok(#(lex_step(lexer, src), text <> "34", 34))
    "35" <> src -> Ok(#(lex_step(lexer, src), text <> "35", 35))
    "36" <> src -> Ok(#(lex_step(lexer, src), text <> "36", 36))
    "37" <> src -> Ok(#(lex_step(lexer, src), text <> "37", 37))
    "38" <> src -> Ok(#(lex_step(lexer, src), text <> "38", 38))
    "39" <> src -> Ok(#(lex_step(lexer, src), text <> "39", 39))
    "40" <> src -> Ok(#(lex_step(lexer, src), text <> "40", 40))
    "41" <> src -> Ok(#(lex_step(lexer, src), text <> "41", 41))
    "42" <> src -> Ok(#(lex_step(lexer, src), text <> "42", 42))
    "43" <> src -> Ok(#(lex_step(lexer, src), text <> "43", 43))
    "44" <> src -> Ok(#(lex_step(lexer, src), text <> "44", 44))
    "45" <> src -> Ok(#(lex_step(lexer, src), text <> "45", 45))
    "46" <> src -> Ok(#(lex_step(lexer, src), text <> "46", 46))
    "47" <> src -> Ok(#(lex_step(lexer, src), text <> "47", 47))
    "48" <> src -> Ok(#(lex_step(lexer, src), text <> "48", 48))
    "49" <> src -> Ok(#(lex_step(lexer, src), text <> "49", 49))
    "50" <> src -> Ok(#(lex_step(lexer, src), text <> "50", 50))
    "51" <> src -> Ok(#(lex_step(lexer, src), text <> "51", 51))
    "52" <> src -> Ok(#(lex_step(lexer, src), text <> "52", 52))
    "53" <> src -> Ok(#(lex_step(lexer, src), text <> "53", 53))
    "54" <> src -> Ok(#(lex_step(lexer, src), text <> "54", 54))
    "55" <> src -> Ok(#(lex_step(lexer, src), text <> "55", 55))
    "56" <> src -> Ok(#(lex_step(lexer, src), text <> "56", 56))
    "57" <> src -> Ok(#(lex_step(lexer, src), text <> "57", 57))
    "58" <> src -> Ok(#(lex_step(lexer, src), text <> "58", 58))
    "59" <> src -> Ok(#(lex_step(lexer, src), text <> "59", 59))
    _ -> Error(IncompleteTime(lexer.position))
  }
}

fn lex_float(
  lexer: Lexer,
  float: Float,
  unit: Float,
  text: String,
) -> Result(#(Lexer, Token), TomlError) {
  case lexer.src {
    "_" <> src -> lex_float(lex_step(lexer, src), float, unit, text <> "_")
    "0" <> src ->
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "0")
    "1" <> src -> {
      let float = float +. 1.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "1")
    }
    "2" <> src -> {
      let float = float +. 2.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "2")
    }
    "3" <> src -> {
      let float = float +. 3.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "3")
    }
    "4" <> src -> {
      let float = float +. 4.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "4")
    }
    "5" <> src -> {
      let float = float +. 5.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "5")
    }
    "6" <> src -> {
      let float = float +. 6.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "6")
    }
    "7" <> src -> {
      let float = float +. 7.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "7")
    }
    "8" <> src -> {
      let float = float +. 8.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "8")
    }
    "9" <> src -> {
      let float = float +. 9.0 *. unit
      lex_float(lex_step(lexer, src), float, unit *. 0.1, text <> "9")
    }

    "e+" <> src ->
      lex_exponent(lex_step(lexer, src), float, text <> "e+", 0, Positive)
    "e-" <> src ->
      lex_exponent(lex_step(lexer, src), float, text <> "e-", 0, Negative)
    "e" <> src ->
      lex_exponent(lex_step(lexer, src), float, text <> "e", 0, Positive)
    "E+" <> src ->
      lex_exponent(lex_step(lexer, src), float, text <> "E+", 0, Positive)
    "E-" <> src ->
      lex_exponent(lex_step(lexer, src), float, text <> "E-", 0, Negative)
    "E" <> src ->
      lex_exponent(lex_step(lexer, src), float, text <> "E", 0, Positive)

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
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "_", ex, sign)
    }
    "0" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "0", ex * 10, sign)
    }
    "1" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "1", ex * 10 + 1, sign)
    }
    "2" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "2", ex * 10 + 2, sign)
    }
    "3" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "3", ex * 10 + 3, sign)
    }
    "4" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "4", ex * 10 + 4, sign)
    }
    "5" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "5", ex * 10 + 5, sign)
    }
    "6" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "6", ex * 10 + 6, sign)
    }
    "7" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "7", ex * 10 + 7, sign)
    }
    "8" <> src -> {
      let lexer = lex_step(lexer, src)
      lex_exponent(lexer, n, text <> "8", ex * 10 + 8, sign)
    }
    "9" <> src -> {
      let lexer = lex_step(lexer, src)
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
    | "_" as c <> src -> lex_bare_key(lex_step(lexer, src), content <> c)

    src if content != "" -> lexed(lexer, src, BareKeyToken(content))
    _ -> Error(UnknownSequence(lexer.position))
  }
}

fn lex_comment(
  src: String,
  lexer: Lexer,
) -> Result(#(Lexer, Token), TomlError) {
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

fn lex_basic_string(
  lexer: Lexer,
  text: String,
  value: String,
) -> Result(#(Lexer, Token), TomlError) {
  let start_position = lexer.position - 1
  let #(lexer, before, split) =
    run_splitter(lexer, lexer.splitters.basic_string, lexer.src)
  let text = text <> before
  let value = value <> before
  case split {
    "\\" -> {
      let text = text <> "\\"
      case lex_escape(lexer, text, value) {
        Ok(#(lexer, text, value)) -> lex_basic_string(lexer, text, value)
        Error(e) -> Error(e)
      }
    }
    "\"" -> Ok(#(lexer, BasicStringToken(src: text, value:)))
    "\n" -> Error(UnterminatedString(start_position))
    _ -> Error(UnterminatedString(start_position))
  }
}

fn lex_multiline_basic_string(
  lexer: Lexer,
  text: String,
  value: String,
) -> Result(#(Lexer, Token), TomlError) {
  let start_position = lexer.position - 3
  let #(lexer, before, split) =
    run_splitter(lexer, lexer.splitters.multiline_basic_string, lexer.src)
  let text = text <> before
  let value = value <> before
  case split {
    "\\" -> {
      let text = text <> "\\"
      case lex_escape(lexer, text, value) {
        Ok(#(lexer, text, value)) ->
          lex_multiline_basic_string(lexer, text, value)
        Error(e) -> Error(e)
      }
    }
    "\"\"\"" -> {
      let value = drop_leading_newline(value)
      Ok(#(lexer, MultiLineBasicStringToken(src: text, value:)))
    }
    _ -> Error(UnterminatedString(start_position))
  }
}

fn lex_escape(
  lexer: Lexer,
  text: String,
  value: String,
) -> Result(#(Lexer, String, String), TomlError) {
  case lexer.src {
    "x" <> src ->
      lex_unicode_escape(lex_step(lexer, src), text <> "x", value, 2)
    "u" <> src ->
      lex_unicode_escape(lex_step(lexer, src), text <> "u", value, 4)
    "U" <> src ->
      lex_unicode_escape(lex_step(lexer, src), text <> "U", value, 8)
    "t" <> src -> Ok(#(lex_step(lexer, src), text <> "t", value <> "\t"))
    "e" <> src -> Ok(#(lex_step(lexer, src), text <> "e", value <> "\u{001b}"))
    "b" <> src -> Ok(#(lex_step(lexer, src), text <> "b", value <> "\u{0008}"))
    "n" <> src -> Ok(#(lex_step(lexer, src), text <> "n", value <> "\n"))
    "r" <> src -> Ok(#(lex_step(lexer, src), text <> "r", value <> "\r"))
    "f" <> src -> Ok(#(lex_step(lexer, src), text <> "f", value <> "\f"))
    "\"" <> src -> Ok(#(lex_step(lexer, src), text <> "\"", value <> "\""))
    "\\" <> src -> Ok(#(lex_step(lexer, src), text <> "\\", value <> "\\"))
    "\n" <> src -> {
      let #(whitespace, src) = take_whitespace("\n", src)
      let lexer = lex_step(lexer, src)
      Ok(#(lexer, text <> whitespace, value))
    }
    _ -> Error(UnknownEscapeSequence(lexer.position))
  }
}

fn lex_unicode_escape(
  lexer: Lexer,
  text: String,
  value: String,
  digits: Int,
) -> Result(#(Lexer, String, String), TomlError) {
  let hex = string.slice(lexer.src, 0, digits)
  use <- bool.guard(
    when: string.byte_size(hex) != digits,
    return: Error(InvalidEscapeSequence(lexer.position)),
  )
  let src = string.slice(lexer.src, digits, string.byte_size(lexer.src))

  use codepoint <- result.try(
    int.base_parse(hex, 16)
    |> result.try(string.utf_codepoint)
    |> result.replace_error(InvalidEscapeSequence(lexer.position)),
  )

  let lexer = lex_step(lexer, src)
  let text = text <> hex
  let value = value <> string.from_utf_codepoints([codepoint])
  Ok(#(lexer, text, value))
}

fn run_splitter(
  lexer: Lexer,
  splitter: Splitter,
  src: String,
) -> #(Lexer, String, String) {
  let #(before, split, after) = splitter.split(splitter, src)
  let lexer = lex_step(lexer, after)
  #(lexer, before, split)
}

fn lexed(
  lexer: Lexer,
  src: String,
  token: Token,
) -> Result(#(Lexer, Token), TomlError) {
  Ok(#(lex_step(lexer, src), token))
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
