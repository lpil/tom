// - [x] Bare key
//   - [ ] error tests
// - [ ] Quoted key
//   - [ ] error tests
// - [ ] String
//   - [ ] error tests
// - [ ] Integer
//   - [ ] error tests
// - [ ] Float
//   - [ ] error tests
// - [x] Boolean
//   - [ ] error tests
// - [ ] Offset Date-Time
//   - [ ] error tests
// - [ ] Local Date-Time
//   - [ ] error tests
// - [ ] Local Date
//   - [ ] error tests
// - [ ] Local Time
//   - [ ] error tests
// - [ ] Array
//   - [ ] error tests
// - [ ] Inline Table
//   - [ ] error tests

import gleam/list
import gleam/string
import gleam/map.{type Map}

pub type Toml {
  Int(Int)
  Float(Float)
  Bool(Bool)
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
  use input <- expect(input, "=")
  let input = skip_line_whitespace(input)
  use value, input <- do(parse_value(input))
  let toml = map.insert(toml, key, value)
  Ok(#(toml, input))
}

fn parse_value(input) -> Parsed(Toml) {
  case input {
    ["t", "r", "u", "e"] -> Ok(#(Bool(True), []))
    ["f", "a", "l", "s", "e"] -> Ok(#(Bool(False), []))
    [g, ..] -> Error(Unexpected(g, "value"))
    [] -> Error(Unexpected("EOF", "value"))
  }
}

fn parse_key(input: Tokens, name: String) -> Parsed(String) {
  case input {
    ["=", ..] -> Error(Unexpected("=", expected: "key"))
    ["\"", ..input] -> parse_key_quoted(input, name)
    _ -> parse_key_bare(input, name)
  }
}

fn parse_key_quoted(input: Tokens, name: String) -> Parsed(String) {
  todo
}

fn parse_key_bare(input: Tokens, name: String) -> Parsed(String) {
  case input {
    [" ", ..input] if name != "" -> Ok(#(name, skip_whitespace(input)))
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
