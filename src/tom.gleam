import gleam/int
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
  KeyAlreadyInUse(List(String))
}

type Tokens =
  List(String)

type Parsed(a) =
  Result(#(a, Tokens), ParseError)

pub fn parse(input: String) -> Result(Map(String, Toml), ParseError) {
  let input = string.to_graphemes(input)
  let input = drop_comments(input, [])
  let input = skip_whitespace(input)
  use toml, input <- do(parse_table(input, map.new()))
  parse_tables(input, toml)
}

fn parse_tables(
  input: Tokens,
  toml: Map(String, Toml),
) -> Result(Map(String, Toml), ParseError) {
  case input {
    ["[", ..input] -> {
      case parse_table_and_header(input) {
        Error(e) -> Error(e)
        Ok(#(#(key, table), input)) -> {
          case insert(toml, key, Table(table)) {
            Ok(toml) -> parse_tables(input, toml)
            Error(e) -> Error(e)
          }
        }
      }
    }
    [g, ..] -> Error(Unexpected(g, "["))
    [] -> Ok(toml)
  }
}

fn parse_table_header(input: Tokens) -> Parsed(List(String)) {
  let input = skip_line_whitespace(input)
  use key, input <- do(parse_key(input, []))
  use input <- expect(input, "]")
  use input <- expect_end_of_line(input)
  Ok(#(key, input))
}

fn parse_table_and_header(
  input: Tokens,
) -> Parsed(#(List(String), Map(String, Toml))) {
  use key, input <- do(parse_table_header(input))
  use table, input <- do(parse_table(input, map.new()))
  Ok(#(#(key, table), input))
}

fn parse_table(
  input: Tokens,
  toml: Map(String, Toml),
) -> Parsed(Map(String, Toml)) {
  let input = skip_whitespace(input)
  case input {
    ["[", ..] | [] -> Ok(#(toml, input))
    _ ->
      case parse_key_value(input, toml) {
        Ok(#(toml, input)) -> parse_table(input, toml)
        e -> e
      }
  }
}

fn parse_key_value(
  input: Tokens,
  toml: Map(String, Toml),
) -> Parsed(Map(String, Toml)) {
  use key, input <- do(parse_key(input, []))
  let input = skip_line_whitespace(input)
  use input <- expect(input, "=")
  let input = skip_line_whitespace(input)
  use value, input <- do(parse_value(input))
  use input <- expect_end_of_line(input)
  case insert(toml, key, value) {
    Ok(toml) -> Ok(#(toml, input))
    Error(e) -> Error(e)
  }
}

fn insert(
  table: Map(String, Toml),
  key: List(String),
  value: Toml,
) -> Result(Map(String, Toml), ParseError) {
  case insert_loop(table, key, value) {
    Ok(table) -> Ok(table)
    Error(path) -> Error(KeyAlreadyInUse(path))
  }
}

fn insert_loop(
  table: Map(String, Toml),
  key: List(String),
  value: Toml,
) -> Result(Map(String, Toml), List(String)) {
  case key {
    [] -> panic as "unreachable"
    [k] -> {
      case map.get(table, k) {
        Error(Nil) -> Ok(map.insert(table, k, value))
        Ok(_) -> Error([k])
      }
    }
    [k, ..key] -> {
      case map.get(table, k) {
        Error(Nil) -> {
          case insert_loop(map.new(), key, value) {
            Ok(inner) -> Ok(map.insert(table, k, Table(inner)))
            Error(path) -> Error([k, ..path])
          }
        }
        Ok(Table(inner)) -> {
          case insert_loop(inner, key, value) {
            Ok(inner) -> Ok(map.insert(table, k, Table(inner)))
            Error(path) -> Error([k, ..path])
          }
        }
        Ok(_) -> Error([k])
      }
    }
  }
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

    ["[", ..input] -> parse_array(input, [])
    ["{", ..input] -> parse_inline_table(input, map.new())

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

fn parse_key(input: Tokens, segments: List(String)) -> Parsed(List(String)) {
  use segment, input <- do(parse_key_segment(input))
  let segments = [segment, ..segments]
  let input = skip_line_whitespace(input)

  case input {
    [".", ..input] -> parse_key(input, segments)
    _ -> Ok(#(list.reverse(segments), input))
  }
}

fn parse_key_segment(input: Tokens) -> Parsed(String) {
  let input = skip_line_whitespace(input)
  case input {
    ["=", ..] -> Error(Unexpected("=", "Key"))
    ["\n", ..] -> Error(Unexpected("\n", "Key"))
    ["\r\n", ..] -> Error(Unexpected("\r\n", "Key"))
    ["[", ..] -> Error(Unexpected("[", "Key"))
    ["\"", ..input] -> parse_key_quoted(input, "\"", "")
    ["'", ..input] -> parse_key_quoted(input, "'", "")
    _ -> parse_key_bare(input, "")
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
    [".", ..] if name != "" -> Ok(#(name, input))
    ["]", ..] if name != "" -> Ok(#(name, input))
    [",", ..] if name != "" -> Error(Unexpected(",", "="))
    ["\n", ..] if name != "" -> Error(Unexpected("\n", "="))
    ["\r\n", ..] if name != "" -> Error(Unexpected("\r\n", "="))
    ["\n", ..] -> Error(Unexpected("\n", "key"))
    ["\r\n", ..] -> Error(Unexpected("\r\n", "key"))
    ["]", ..] -> Error(Unexpected("]", "key"))
    [",", ..] -> Error(Unexpected(",", "key"))
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
  next: fn(a, Tokens) -> Result(b, ParseError),
) -> Result(b, ParseError) {
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

fn parse_inline_table(
  input: Tokens,
  properties: Map(String, Toml),
) -> Parsed(Toml) {
  let input = skip_whitespace(input)
  case input {
    ["}", ..input] -> Ok(#(Table(properties), input))
    _ ->
      case parse_inline_table_property(input, properties) {
        Ok(#(properties, input)) -> {
          let input = skip_whitespace(input)
          case input {
            ["}", ..input] -> Ok(#(Table(properties), input))
            [",", ..input] -> {
              let input = skip_whitespace(input)
              parse_inline_table(input, properties)
            }
            [g, ..] -> Error(Unexpected(g, "}"))
            [] -> Error(Unexpected("EOF", "}"))
          }
        }
        Error(e) -> Error(e)
      }
  }
}

fn parse_inline_table_property(
  input: Tokens,
  properties: Map(String, Toml),
) -> Parsed(Map(String, Toml)) {
  let input = skip_whitespace(input)
  use key, input <- do(parse_key(input, []))
  let input = skip_line_whitespace(input)
  use input <- expect(input, "=")
  let input = skip_line_whitespace(input)
  use value, input <- do(parse_value(input))
  case insert(properties, key, value) {
    Ok(properties) -> Ok(#(properties, input))
    Error(e) -> Error(e)
  }
}

fn parse_array(input: Tokens, elements: List(Toml)) -> Parsed(Toml) {
  let input = skip_whitespace(input)
  case input {
    ["]", ..input] -> Ok(#(Array(list.reverse(elements)), input))
    _ -> {
      use element, input <- do(parse_value(input))
      let elements = [element, ..elements]
      let input = skip_whitespace(input)
      case input {
        ["]", ..input] -> Ok(#(Array(list.reverse(elements)), input))
        [",", ..input] -> {
          let input = skip_whitespace(input)
          parse_array(input, elements)
        }
        [g, ..] -> Error(Unexpected(g, "]"))
        [] -> Error(Unexpected("EOF", "]"))
      }
    }
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

    [".", ..input] -> parse_float(input, int.to_float(number), sign, 0.1)

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

fn parse_float(
  input: Tokens,
  number: Float,
  sign: Sign,
  unit: Float,
) -> Parsed(Toml) {
  case input {
    ["_", ..input] -> parse_float(input, number, sign, unit)
    ["0", ..input] -> parse_float(input, number, sign, unit *. 0.1)
    ["1", ..input] ->
      parse_float(input, number +. 1.0 *. unit, sign, unit *. 0.1)
    ["2", ..input] ->
      parse_float(input, number +. 2.0 *. unit, sign, unit *. 0.1)
    ["3", ..input] ->
      parse_float(input, number +. 3.0 *. unit, sign, unit *. 0.1)
    ["4", ..input] ->
      parse_float(input, number +. 4.0 *. unit, sign, unit *. 0.1)
    ["5", ..input] ->
      parse_float(input, number +. 5.0 *. unit, sign, unit *. 0.1)
    ["6", ..input] ->
      parse_float(input, number +. 6.0 *. unit, sign, unit *. 0.1)
    ["7", ..input] ->
      parse_float(input, number +. 7.0 *. unit, sign, unit *. 0.1)
    ["8", ..input] ->
      parse_float(input, number +. 8.0 *. unit, sign, unit *. 0.1)
    ["9", ..input] ->
      parse_float(input, number +. 9.0 *. unit, sign, unit *. 0.1)

    // Anything else and the number is terminated
    input -> {
      let number = case sign {
        Positive -> number
        Negative -> number *. -1.0
      }
      Ok(#(Float(number), input))
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
    [] -> Error(Unexpected("EOF", "\""))
    ["\n", ..] -> Error(Unexpected("\n", "\""))
    ["\r\n", ..] -> Error(Unexpected("\r\n", "\""))
    // ["\\", "u", ..input] -> parse_string_unicode(input, string)
    [g, ..input] -> parse_string(input, string <> g)
  }
}
