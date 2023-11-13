//// A (not quite complete) pure Gleam TOML parser!
////
//// ```gleam
//// import tom
//// 
//// const config = "
////   [person]
////   name = \"Lucy\"
////   is_cool = true
//// "
//// 
//// pub fn main() {
////   // Parse a string of TOML
////   let assert Ok(parsed) = tom.parse(config)
//// 
////   // Now you can work with the data directly, or you can use the `get_*`
////   // functions to retrieve values.
//// 
////   tom.get_string(parsed, ["person", "name"])
////   // -> Ok("Lucy")
//// 
////   let is_cool = tom.get_bool(parsed, ["person", "is_cool"])
////   // -> Ok(True)
//// }
//// ```

import gleam/int
import gleam/list
import gleam/string
import gleam/result
import gleam/map.{type Map}

/// A TOML document.
pub type Toml {
  Int(Int)
  Float(Float)
  /// Infinity is a valid number in TOML but Gleam does not support it, so this
  /// variant represents the infinity values.
  Infinity(Sign)
  /// NaN is a valid number in TOML but Gleam does not support it, so this
  /// variant represents the NaN values.
  Nan(Sign)
  Bool(Bool)
  String(String)
  Date(String)
  Time(String)
  DateTime(String)
  Array(List(Toml))
  ArrayOfTables(List(Map(String, Toml)))
  Table(Map(String, Toml))
  InlineTable(Map(String, Toml))
}

pub type Sign {
  Positive
  Negative
}

/// An error that can occur when parsing a TOML document.
pub type ParseError {
  /// An unexpected character was encountered when parsing the document.
  Unexpected(got: String, expected: String)
  /// More than one items have the same key in the document.
  KeyAlreadyInUse(key: List(String))
}

type Tokens =
  List(String)

type Parsed(a) =
  Result(#(a, Tokens), ParseError)

/// A number of any kind, returned by the `get_number` function.
pub type Number {
  NumberInt(Int)
  NumberFloat(Float)
  NumberInfinity(Sign)
  NumberNan(Sign)
}

/// An error that can occur when retrieving a value from a TOML document with
/// one of the `get_*` functions.
pub type GetError {
  /// There was no value at the given key.
  NotFound(key: List(String))
  /// The value at the given key was not of the expected type.
  WrongType(key: List(String), expected: String, got: String)
}

// TODO: test
/// Get a value of any type from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = 1")
/// get(parsed, ["a", "b", "c"])
/// // -> Ok(Int(1))
/// ```
///
pub fn get(toml: Map(String, Toml), key: List(String)) -> Result(Toml, GetError) {
  case key {
    [] -> Error(NotFound([]))
    [k] -> result.replace_error(map.get(toml, k), NotFound([k]))
    [k, ..key] -> {
      case map.get(toml, k) {
        Ok(Table(t)) -> push_key(get(t, key), k)
        Ok(other) -> Error(WrongType([k], "Table", classify(other)))
        Error(_) -> Error(NotFound([k]))
      }
    }
  }
}

// TODO: test
/// Get an int from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = 1")
/// get_int(parsed, ["a", "b", "c"])
/// // -> Ok(1)
/// ```
///
pub fn get_int(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(Int, GetError) {
  case get(toml, key) {
    Ok(Int(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "Int", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a float from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = 1.1")
/// get_float(parsed, ["a", "b", "c"])
/// // -> Ok(1.1)
/// ```
///
pub fn get_float(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(Float, GetError) {
  case get(toml, key) {
    Ok(Float(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "Float", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a bool from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = true")
/// get_bool(parsed, ["a", "b", "c"])
/// // -> Ok(True)
/// ```
///
pub fn get_bool(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(Bool, GetError) {
  case get(toml, key) {
    Ok(Bool(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "Bool", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a string from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = \"ok\"")
/// get_string(parsed, ["a", "b", "c"])
/// // -> Ok("ok")
/// ```
///
pub fn get_string(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(String, GetError) {
  case get(toml, key) {
    Ok(String(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "String", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a date from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = 1979-05-27")
/// get_date(parsed, ["a", "b", "c"])
/// // -> Ok("1979-05-27")
/// ```
///
pub fn get_date(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(String, GetError) {
  case get(toml, key) {
    Ok(Date(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "Date", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a time from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = 07:32:00")
/// get_time(parsed, ["a", "b", "c"])
/// // -> Ok("07:32:00")
/// ```
///
pub fn get_time(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(String, GetError) {
  case get(toml, key) {
    Ok(Time(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "Time", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a date-time from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = 1979-05-27T07:32:00")
/// get_date_time(parsed, ["a", "b", "c"])
/// // -> Ok("1979-05-27T07:32:00")
/// ```
///
pub fn get_date_time(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(String, GetError) {
  case get(toml, key) {
    Ok(DateTime(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "DateTime", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get an array from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = [1, 2]")
/// get_array(parsed, ["a", "b", "c"])
/// // -> Ok([Int(1), Int(2)])
/// ```
///
pub fn get_array(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(List(Toml), GetError) {
  case get(toml, key) {
    Ok(Array(i)) -> Ok(i)
    Ok(ArrayOfTables(i)) -> Ok(list.map(i, Table))
    Ok(other) -> Error(WrongType(key, "Array", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a table from a TOML document.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = { d = 1 }")
/// get_table(parsed, ["a", "b", "c"])
/// // -> Ok(map.from_list([#("d", Int(1))]))
/// ```
///
pub fn get_table(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(Map(String, Toml), GetError) {
  case get(toml, key) {
    Ok(Table(i)) -> Ok(i)
    Ok(InlineTable(i)) -> Ok(i)
    Ok(other) -> Error(WrongType(key, "Table", classify(other)))
    Error(e) -> Error(e)
  }
}

// TODO: test
/// Get a number of any kind from a TOML document.
/// This could be an int, a float, a NaN, or an infinity.
///
/// ## Examples
/// 
/// ```gleam
/// let assert Ok(parsed) = parse("a.b.c = { d = inf }")
/// get_number(parsed, ["a", "b", "c"])
/// // -> Ok(NumberInfinity(Positive)))
/// ```
///
pub fn get_number(
  toml: Map(String, Toml),
  key: List(String),
) -> Result(Number, GetError) {
  case get(toml, key) {
    Ok(Int(x)) -> Ok(NumberInt(x))
    Ok(Float(x)) -> Ok(NumberFloat(x))
    Ok(Nan(x)) -> Ok(NumberNan(x))
    Ok(Infinity(x)) -> Ok(NumberInfinity(x))
    Ok(other) -> Error(WrongType(key, "Number", classify(other)))
    Error(e) -> Error(e)
  }
}

fn classify(toml: Toml) -> String {
  case toml {
    Int(_) -> "Int"
    Float(_) -> "Float"
    Nan(Positive) -> "NaN"
    Nan(Negative) -> "Negative NaN"
    Infinity(Positive) -> "Infinity"
    Infinity(Negative) -> "Negative Infinity"
    Bool(_) -> "Bool"
    String(_) -> "String"
    Date(_) -> "Date"
    Time(_) -> "Time"
    DateTime(_) -> "DateTime"
    Array(_) -> "Array"
    ArrayOfTables(_) -> "Array"
    Table(_) -> "Table"
    InlineTable(_) -> "Table"
  }
}

fn push_key(result: Result(t, GetError), key: String) -> Result(t, GetError) {
  case result {
    Ok(t) -> Ok(t)
    Error(NotFound(path)) -> Error(NotFound([key, ..path]))
    Error(WrongType(path, expected, got)) ->
      Error(WrongType([key, ..path], expected, got))
  }
}

pub fn parse(input: String) -> Result(Map(String, Toml), ParseError) {
  let input = string.to_graphemes(input)
  let input = drop_comments(input, [])
  let input = skip_whitespace(input)
  use toml, input <- do(parse_table(input, map.new()))
  case parse_tables(input, toml) {
    Ok(toml) -> Ok(reverse_arrays_of_tables_table(toml))
    Error(e) -> Error(e)
  }
}

fn parse_tables(
  input: Tokens,
  toml: Map(String, Toml),
) -> Result(Map(String, Toml), ParseError) {
  case input {
    ["[", "[", ..input] -> {
      case parse_array_of_tables(input) {
        Error(e) -> Error(e)
        Ok(#(#(key, table), input)) -> {
          case insert(toml, key, ArrayOfTables([table])) {
            Ok(toml) -> parse_tables(input, toml)
            Error(e) -> Error(e)
          }
        }
      }
    }
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

fn parse_array_of_tables(
  input: Tokens,
) -> Parsed(#(List(String), Map(String, Toml))) {
  let input = skip_line_whitespace(input)
  use key, input <- do(parse_key(input, []))
  use input <- expect(input, "]")
  use input <- expect(input, "]")
  use table, input <- do(parse_table(input, map.new()))
  Ok(#(#(key, table), input))
}

fn parse_table_header(input: Tokens) -> Parsed(List(String)) {
  let input = skip_line_whitespace(input)
  use key, input <- do(parse_key(input, []))
  use input <- expect(input, "]")
  let input = skip_line_whitespace(input)
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
        Ok(old) -> merge(table, k, old, value)
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
        Ok(ArrayOfTables([inner, ..rest])) -> {
          case insert_loop(inner, key, value) {
            Ok(inner) ->
              Ok(map.insert(table, k, ArrayOfTables([inner, ..rest])))
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

fn merge(
  table: Map(String, Toml),
  key: String,
  old: Toml,
  new: Toml,
) -> Result(Map(String, Toml), List(String)) {
  case old, new {
    // When both are arrays of tables then they are merged together
    ArrayOfTables(tables), ArrayOfTables(new) ->
      Ok(map.insert(table, key, ArrayOfTables(list.append(new, tables))))

    _, _ -> Error([key])
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

    ["n", "a", "n", ..input] -> Ok(#(Nan(Positive), input))
    ["+", "n", "a", "n", ..input] -> Ok(#(Nan(Positive), input))
    ["-", "n", "a", "n", ..input] -> Ok(#(Nan(Negative), input))

    ["i", "n", "f", ..input] -> Ok(#(Infinity(Positive), input))
    ["+", "i", "n", "f", ..input] -> Ok(#(Infinity(Positive), input))
    ["-", "i", "n", "f", ..input] -> Ok(#(Infinity(Negative), input))

    ["[", ..input] -> parse_array(input, [])
    ["{", ..input] -> parse_inline_table(input, map.new())

    ["0", "x", ..input] -> parse_hex(input, 0, Positive)
    ["+", "0", "x", ..input] -> parse_hex(input, 0, Positive)
    ["-", "0", "x", ..input] -> parse_hex(input, 0, Negative)

    ["0", "o", ..input] -> parse_octal(input, 0, Positive)
    ["+", "0", "o", ..input] -> parse_octal(input, 0, Positive)
    ["-", "0", "o", ..input] -> parse_octal(input, 0, Negative)

    ["0", "b", ..input] -> parse_binary(input, 0, Positive)
    ["+", "0", "b", ..input] -> parse_binary(input, 0, Positive)
    ["-", "0", "b", ..input] -> parse_binary(input, 0, Negative)

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

    ["\"", "\"", "\"", ..input] -> parse_multi_line_string(input, "")
    ["\"", ..input] -> parse_string(input, "")

    ["'", "'", "'", ..input] -> parse_multi_line_literal_string(input, "")
    ["'", ..input] -> parse_literal_string(input, "")

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
    ["}", ..input] -> Ok(#(InlineTable(properties), input))
    _ ->
      case parse_inline_table_property(input, properties) {
        Ok(#(properties, input)) -> {
          let input = skip_whitespace(input)
          case input {
            ["}", ..input] -> Ok(#(InlineTable(properties), input))
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

fn parse_hex(input: Tokens, number: Int, sign: Sign) -> Parsed(Toml) {
  case input {
    ["_", ..input] -> parse_hex(input, number, sign)
    ["0", ..input] -> parse_hex(input, number * 16 + 0, sign)
    ["1", ..input] -> parse_hex(input, number * 16 + 1, sign)
    ["2", ..input] -> parse_hex(input, number * 16 + 2, sign)
    ["3", ..input] -> parse_hex(input, number * 16 + 3, sign)
    ["4", ..input] -> parse_hex(input, number * 16 + 4, sign)
    ["5", ..input] -> parse_hex(input, number * 16 + 5, sign)
    ["6", ..input] -> parse_hex(input, number * 16 + 6, sign)
    ["7", ..input] -> parse_hex(input, number * 16 + 7, sign)
    ["8", ..input] -> parse_hex(input, number * 16 + 8, sign)
    ["9", ..input] -> parse_hex(input, number * 16 + 9, sign)
    ["a", ..input] -> parse_hex(input, number * 16 + 10, sign)
    ["b", ..input] -> parse_hex(input, number * 16 + 11, sign)
    ["c", ..input] -> parse_hex(input, number * 16 + 12, sign)
    ["d", ..input] -> parse_hex(input, number * 16 + 13, sign)
    ["e", ..input] -> parse_hex(input, number * 16 + 14, sign)
    ["f", ..input] -> parse_hex(input, number * 16 + 15, sign)
    ["A", ..input] -> parse_hex(input, number * 16 + 10, sign)
    ["B", ..input] -> parse_hex(input, number * 16 + 11, sign)
    ["C", ..input] -> parse_hex(input, number * 16 + 12, sign)
    ["D", ..input] -> parse_hex(input, number * 16 + 13, sign)
    ["E", ..input] -> parse_hex(input, number * 16 + 14, sign)
    ["F", ..input] -> parse_hex(input, number * 16 + 15, sign)

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

fn parse_octal(input: Tokens, number: Int, sign: Sign) -> Parsed(Toml) {
  case input {
    ["_", ..input] -> parse_octal(input, number, sign)
    ["0", ..input] -> parse_octal(input, number * 8 + 0, sign)
    ["1", ..input] -> parse_octal(input, number * 8 + 1, sign)
    ["2", ..input] -> parse_octal(input, number * 8 + 2, sign)
    ["3", ..input] -> parse_octal(input, number * 8 + 3, sign)
    ["4", ..input] -> parse_octal(input, number * 8 + 4, sign)
    ["5", ..input] -> parse_octal(input, number * 8 + 5, sign)
    ["6", ..input] -> parse_octal(input, number * 8 + 6, sign)
    ["7", ..input] -> parse_octal(input, number * 8 + 7, sign)

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

fn parse_binary(input: Tokens, number: Int, sign: Sign) -> Parsed(Toml) {
  case input {
    ["_", ..input] -> parse_binary(input, number, sign)
    ["0", ..input] -> parse_binary(input, number * 2 + 0, sign)
    ["1", ..input] -> parse_binary(input, number * 2 + 1, sign)

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
    [g, ..input] -> parse_string(input, string <> g)
  }
}

fn parse_multi_line_string(input: Tokens, string: String) -> Parsed(Toml) {
  case input {
    ["\"", "\"", "\"", ..input] -> Ok(#(String(string), input))
    ["\\", "\n", ..input] ->
      parse_multi_line_string(skip_whitespace(input), string)
    ["\\", "\r\n", ..input] ->
      parse_multi_line_string(skip_whitespace(input), string)
    ["\r\n", ..input] if string == "" -> parse_multi_line_string(input, string)
    ["\n", ..input] if string == "" -> parse_multi_line_string(input, string)
    ["\r\n", ..input] if string == "" -> parse_multi_line_string(input, string)
    ["\\", "t", ..input] -> parse_multi_line_string(input, string <> "\t")
    ["\\", "n", ..input] -> parse_multi_line_string(input, string <> "\n")
    ["\\", "r", ..input] -> parse_multi_line_string(input, string <> "\r")
    ["\\", "\"", ..input] -> parse_multi_line_string(input, string <> "\"")
    ["\\", "\\", ..input] -> parse_multi_line_string(input, string <> "\\")
    [] -> Error(Unexpected("EOF", "\""))
    [g, ..input] -> parse_multi_line_string(input, string <> g)
  }
}

fn parse_multi_line_literal_string(
  input: Tokens,
  string: String,
) -> Parsed(Toml) {
  case input {
    [] -> Error(Unexpected("EOF", "\""))
    ["'", "'", "'", "'", ..] -> Error(Unexpected("''''", "'''"))
    ["'", "'", "'", ..input] -> Ok(#(String(string), input))
    ["\n", ..input] if string == "" ->
      parse_multi_line_literal_string(input, string)
    ["\r\n", ..input] if string == "" ->
      parse_multi_line_literal_string(input, string)
    [g, ..input] -> parse_multi_line_literal_string(input, string <> g)
  }
}

fn parse_literal_string(input: Tokens, string: String) -> Parsed(Toml) {
  case input {
    [] -> Error(Unexpected("EOF", "\""))
    ["\n", ..] -> Error(Unexpected("\n", "'"))
    ["\r\n", ..] -> Error(Unexpected("\r\n", "'"))
    ["'", ..input] -> Ok(#(String(string), input))
    [g, ..input] -> parse_literal_string(input, string <> g)
  }
}

fn reverse_arrays_of_tables(toml: Toml) -> Toml {
  case toml {
    ArrayOfTables(tables) ->
      ArrayOfTables(reverse_arrays_of_tables_array(tables, []))

    Table(table) -> Table(reverse_arrays_of_tables_table(table))

    _ -> toml
  }
}

fn reverse_arrays_of_tables_table(table: Map(String, Toml)) -> Map(String, Toml) {
  map.map_values(table, fn(_, v) { reverse_arrays_of_tables(v) })
}

fn reverse_arrays_of_tables_array(
  array: List(Map(String, Toml)),
  acc: List(Map(String, Toml)),
) -> List(Map(String, Toml)) {
  case array {
    [] -> acc
    [first, ..rest] -> {
      let first = reverse_arrays_of_tables_table(first)
      reverse_arrays_of_tables_array(rest, [first, ..acc])
    }
  }
}
