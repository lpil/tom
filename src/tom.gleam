import gleam/list
import gleam/string
import gleam/map.{type Map}

pub type Toml {
  Int(Int)
  Float(Float)
  Bool(Bool)
  String(String)
  Date(String)
  Time(String)
  DateTime(String)
  Array(List(Toml))
  Table(Map(String, Toml))
}

pub type ParseError {
  Unexpected(got: String, expected: String)
}

type Tokens =
  List(String)

type Parsed(a) =
  Result(#(a, Tokens), ParseError)

pub fn parse(input: String) -> Result(Map(String, Toml), ParseError) {
  let input = string.to_graphemes(input)
  let input = drop_comments(input, [])
  let result = map.new()
  case parse_top(input, result) {
    Ok(#(table, _)) -> Ok(table)
    Error(e) -> Error(e)
  }
}

fn parse_top(
  input: Tokens,
  toml: Map(String, Toml),
) -> Parsed(Map(String, Toml)) {
  let input = skip_whitespace(input)
  let result = case input {
    [] -> Ok(#(toml, []))
    _ -> parse_key_value(input, toml)
  }

  case result {
    Ok(#(toml, [])) -> Ok(#(toml, []))
    Ok(#(toml, input)) -> parse_top(input, toml)
    Error(e) -> Error(e)
  }
}

fn parse_key_value(
  input: Tokens,
  toml: Map(String, Toml),
) -> Parsed(Map(String, Toml)) {
  use key, input <- do(parse_key(input, ""))
  let input = skip_line_whitespace(input)
  use input <- expect(input, "=")
  let input = skip_line_whitespace(input)
  use value, input <- do(parse_value(input))
  use input <- expect_end_of_line(input)
  let toml = map.insert(toml, key, value)
  Ok(#(toml, input))
}

fn expect_end_of_line(input: Tokens, next: fn(Tokens) -> Parsed(a)) -> Parsed(a) {
  case input {
    ["\n", ..input] -> next(input)
    ["\r\n", ..input] -> next(input)
    [g, ..] -> Error(Unexpected(g, "\n"))
    [] -> Error(Unexpected("EOF", "\n"))
  }
}

fn parse_value(input) -> Parsed(Toml) {
  case input {
    ["t", "r", "u", "e", ..input] -> Ok(#(Bool(True), input))
    ["f", "a", "l", "s", "e", ..input] -> Ok(#(Bool(False), input))

    ["+", ..input] -> parse_number(input, 0, Positive)
    ["-", ..input] -> parse_number(input, 0, Negative)
    ["0", ..]
    | ["1", ..]
    | ["2", ..]
    | ["3", ..]
    | ["4", ..]
    | ["5", ..]
    | ["6", ..]
    | ["7", ..]
    | ["8", ..]
    | ["9", ..] -> parse_number(input, 0, Positive)

    ["\"", ..input] -> parse_string(input, "")

    [g, ..] -> Error(Unexpected(g, "value"))
    [] -> Error(Unexpected("EOF", "value"))
  }
}

fn parse_key(input: Tokens, name: String) -> Parsed(String) {
  case input {
    ["=", ..] -> Error(Unexpected("=", expected: "key"))
    ["\"", ..input] -> parse_key_quoted(input, "\"", name)
    ["'", ..input] -> parse_key_quoted(input, "'", name)
    _ -> parse_key_bare(input, name)
  }
}

fn parse_key_quoted(
  input: Tokens,
  close: String,
  name: String,
) -> Parsed(String) {
  case input {
    [g, ..input] if g == close -> Ok(#(name, input))
    [g, ..input] -> parse_key_quoted(input, close, name <> g)
    [] -> Error(Unexpected("EOF", close))
  }
}

fn parse_key_bare(input: Tokens, name: String) -> Parsed(String) {
  case input {
    [" ", ..input] if name != "" -> Ok(#(name, input))
    ["=", ..] if name != "" -> Ok(#(name, input))
    ["\n", ..] if name != "" -> Error(Unexpected("\n", "="))
    ["\r\n", ..] if name != "" -> Error(Unexpected("\n", "="))
    ["\n", ..] -> Error(Unexpected("\n", "key"))
    ["\r\n", ..] -> Error(Unexpected("\n", "key"))
    [g, ..input] -> parse_key_bare(input, name <> g)
    [] -> Error(Unexpected("EOF", "key"))
  }
}

fn skip_line_whitespace(input: Tokens) -> Tokens {
  list.drop_while(input, fn(g) { g == " " || g == "\t" })
}

fn skip_whitespace(input: Tokens) -> Tokens {
  case input {
    [" ", ..input] -> skip_whitespace(input)
    ["\t", ..input] -> skip_whitespace(input)
    ["\n", ..input] -> skip_whitespace(input)
    ["\r\n", ..input] -> skip_whitespace(input)
    input -> input
  }
}

fn drop_comments(input: Tokens, acc: Tokens) -> Tokens {
  case input {
    ["#", ..input] ->
      input
      |> list.drop_while(fn(g) { g != "\n" })
      |> drop_comments(acc)
    [g, ..input] -> drop_comments(input, [g, ..acc])
    [] -> list.reverse(acc)
  }
}

fn do(
  result: Result(#(a, Tokens), ParseError),
  next: fn(a, Tokens) -> Parsed(b),
) -> Parsed(b) {
  case result {
    Ok(#(a, input)) -> next(a, input)
    Error(e) -> Error(e)
  }
}

fn expect(
  input: Tokens,
  expected: String,
  next: fn(Tokens) -> Parsed(a),
) -> Parsed(a) {
  case input {
    [g, ..input] if g == expected -> next(input)
    [g, ..] -> Error(Unexpected(g, expected))
    [] -> Error(Unexpected("EOF", expected))
  }
}

type Sign {
  Positive
  Negative
}

fn parse_number(input: Tokens, number: Int, sign: Sign) -> Parsed(Toml) {
  case input {
    ["_", ..input] -> parse_number(input, number, sign)
    ["0", ..input] -> parse_number(input, number * 10 + 0, sign)
    ["1", ..input] -> parse_number(input, number * 10 + 1, sign)
    ["2", ..input] -> parse_number(input, number * 10 + 2, sign)
    ["3", ..input] -> parse_number(input, number * 10 + 3, sign)
    ["4", ..input] -> parse_number(input, number * 10 + 4, sign)
    ["5", ..input] -> parse_number(input, number * 10 + 5, sign)
    ["6", ..input] -> parse_number(input, number * 10 + 6, sign)
    ["7", ..input] -> parse_number(input, number * 10 + 7, sign)
    ["8", ..input] -> parse_number(input, number * 10 + 8, sign)
    ["9", ..input] -> parse_number(input, number * 10 + 9, sign)

    // Anything else and the number is terminated
    input -> {
      let number = case sign {
        Positive -> number
        Negative -> -number
      }
      Ok(#(Int(number), input))
    }
  }
}

fn parse_string(input: Tokens, string: String) -> Parsed(Toml) {
  case input {
    ["\"", ..input] -> Ok(#(String(string), input))
    ["\\", "t", ..input] -> parse_string(input, string <> "\t")
    ["\\", "n", ..input] -> parse_string(input, string <> "\n")
    ["\\", "r", ..input] -> parse_string(input, string <> "\r")
    ["\\", "\"", ..input] -> parse_string(input, string <> "\"")
    ["\\", "\\", ..input] -> parse_string(input, string <> "\\")
    // ["\\", "u", ..input] -> parse_string_unicode(input, string)
    [g, ..input] -> parse_string(input, string <> g)
    [] -> Error(Unexpected("EOF", "\""))
  }
}
