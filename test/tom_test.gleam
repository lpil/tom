import tom
import gleam/map
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn parse_empty_test() {
  ""
  |> tom.parse
  |> should.equal(Ok(map.from_list([])))
}

pub fn parse_spaces_test() {
  " "
  |> tom.parse
  |> should.equal(Ok(map.from_list([])))
}

pub fn parse_newline_test() {
  "\n"
  |> tom.parse
  |> should.equal(Ok(map.from_list([])))
}

pub fn parse_crlf_test() {
  "\r\n"
  |> tom.parse
  |> should.equal(Ok(map.from_list([])))
}

pub fn parse_quoted_key_test() {
  let expected = map.from_list([#(" ", tom.Bool(True))])
  "\" \" = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_single_key_test() {
  let expected = map.from_list([#("", tom.Bool(True))])
  "'' = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_true_test() {
  let expected = map.from_list([#("cool", tom.Bool(True))])
  "cool = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_false_test() {
  let expected = map.from_list([#("cool", tom.Bool(False))])
  "cool = false\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_unicode_key_test() {
  let expected = map.from_list([#("பெண்", tom.Bool(False))])
  "பெண் = false\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_int_0_test() {
  let expected = map.from_list([#("it", tom.Int(1))])
  "it = 1\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_int_1_test() {
  let expected = map.from_list([#("it", tom.Int(1_000_009))])
  "it = 1_000_0__0_9\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}
