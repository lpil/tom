import gleam/dict
import gleam/result
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import gleeunit
import gleeunit/should
import tom

pub fn main() {
  gleeunit.main()
}

pub fn parse_empty_test() {
  ""
  |> tom.parse
  |> should.equal(Ok(dict.from_list([])))
}

pub fn parse_spaces_test() {
  " "
  |> tom.parse
  |> should.equal(Ok(dict.from_list([])))
}

pub fn parse_newline_test() {
  "\n"
  |> tom.parse
  |> should.equal(Ok(dict.from_list([])))
}

pub fn parse_crlf_test() {
  "\r\n"
  |> tom.parse
  |> should.equal(Ok(dict.from_list([])))
}

pub fn parse_quoted_key_test() {
  let expected = dict.from_list([#(" ", tom.Bool(True))])
  "\" \" = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_single_key_test() {
  let expected = dict.from_list([#("", tom.Bool(True))])
  "'' = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_true_test() {
  let expected = dict.from_list([#("cool", tom.Bool(True))])
  "cool = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_false_test() {
  let expected = dict.from_list([#("cool", tom.Bool(False))])
  "cool = false\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_unicode_key_test() {
  let expected = dict.from_list([#("பெண்", tom.Bool(False))])
  "பெண் = false\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_int_test() {
  let expected = dict.from_list([#("it", tom.Int(1))])
  "it = 1\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_int_underscored_test() {
  let expected = dict.from_list([#("it", tom.Int(1_000_009))])
  "it = 1_000_0__0_9\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_int_positive_test() {
  let expected = dict.from_list([#("it", tom.Int(234))])
  "it = +234\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_int_negative_test() {
  let expected = dict.from_list([#("it", tom.Int(-234))])
  "it = -234\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_string_test() {
  let expected = dict.from_list([#("hello", tom.String("Joe"))])
  "hello = \"Joe\"\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_string_escaped_quote_test() {
  let expected = dict.from_list([#("hello", tom.String("\""))])
  "hello = \"\\\"\"\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_string_tab_test() {
  let expected = dict.from_list([#("hello", tom.String("\t"))])
  "hello = \"\\t\"\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_string_newline_test() {
  let expected = dict.from_list([#("hello", tom.String("\n"))])
  "hello = \"\\n\"\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_string_linefeed_test() {
  let expected = dict.from_list([#("hello", tom.String("\r"))])
  "hello = \"\\r\"\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_escaped_slash_test() {
  let expected = dict.from_list([#("hello", tom.String("\\"))])
  "hello = \"\\\\\"\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_test() {
  let expected = dict.from_list([#("it", tom.Float(1.0))])
  "it = 1.0\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_bigger_float_test() {
  let expected = dict.from_list([#("it", tom.Float(123_456_789.9876))])
  "it = 123456789.9876\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_segment_key_test() {
  let expected =
    dict.from_list([
      #(
        "one",
        tom.Table(
          dict.from_list([
            #("two", tom.Table(dict.from_list([#("three", tom.Bool(True))]))),
          ]),
        ),
      ),
    ])
  "one.two.three = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_segment_key_with_spaeces_test() {
  let expected =
    dict.from_list([
      #(
        "one",
        tom.Table(
          dict.from_list([
            #("two", tom.Table(dict.from_list([#("three", tom.Bool(True))]))),
          ]),
        ),
      ),
    ])
  "one  . two   .   three = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_segment_key_quotes_test() {
  let expected =
    dict.from_list([
      #(
        "1",
        tom.Table(
          dict.from_list([
            #("two", tom.Table(dict.from_list([#("3", tom.Bool(True))]))),
          ]),
        ),
      ),
    ])
  "\"1\".two.\"3\" = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multiple_keys_test() {
  let expected = dict.from_list([#("a", tom.Int(1)), #("b", tom.Int(2))])
  "a = 1\nb = 2\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_duplicate_key_test() {
  "a = 1\na = 2\n"
  |> tom.parse
  |> should.equal(Error(tom.KeyAlreadyInUse(["a"])))
}

pub fn parse_conflicting_keys_test() {
  "a = 1\na.b = 2\n"
  |> tom.parse
  |> should.equal(Error(tom.KeyAlreadyInUse(["a"])))
}

pub fn parse_empty_array_test() {
  let expected = dict.from_list([#("a", tom.Array([]))])
  "a = []\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_array_test() {
  let expected = dict.from_list([#("a", tom.Array([tom.Int(1), tom.Int(2)]))])
  "a = [1, 2]\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_line_array_test() {
  let expected = dict.from_list([#("a", tom.Array([tom.Int(1), tom.Int(2)]))])
  "a = [\n  1 \n ,\n  2,\n]\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_table_test() {
  let expected = dict.from_list([#("a", tom.Table(dict.from_list([])))])
  "[a]\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_table_with_values_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.Table(
          dict.from_list([
            #("a", tom.Int(1)),
            #("b", tom.Table(dict.from_list([#("c", tom.Int(2))]))),
          ]),
        ),
      ),
    ])
  "[a]
a = 1
b.c = 2
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_table_with_values_before_test() {
  let expected =
    dict.from_list([
      #("name", tom.String("Joe")),
      #("size", tom.Int(123)),
      #(
        "a",
        tom.Table(
          dict.from_list([
            #("a", tom.Int(1)),
            #("b", tom.Table(dict.from_list([#("c", tom.Int(2))]))),
          ]),
        ),
      ),
    ])
  "name = \"Joe\"
size = 123

[a]
a = 1
b.c = 2
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multiple_tables_test() {
  let expected =
    dict.from_list([
      #("name", tom.String("Joe")),
      #("size", tom.Int(123)),
      #(
        "a",
        tom.Table(
          dict.from_list([
            #("a", tom.Int(1)),
            #("b", tom.Table(dict.from_list([#("c", tom.Int(2))]))),
          ]),
        ),
      ),
      #("b", tom.Table(dict.from_list([#("a", tom.Int(1))]))),
    ])
  "name = \"Joe\"
size = 123

[a]
a = 1
b.c = 2

[b]
a = 1
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_inline_table_empty_test() {
  let expected = dict.from_list([#("a", tom.InlineTable(dict.from_list([])))])
  "a = {}\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_inline_table_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.InlineTable(
          dict.from_list([
            #("a", tom.Int(1)),
            #("b", tom.Table(dict.from_list([#("c", tom.Int(2))]))),
          ]),
        ),
      ),
    ])
  "a = {
  a = 1,
  b.c = 2
}
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_inline_trailing_comma_table_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.InlineTable(
          dict.from_list([
            #("a", tom.Int(1)),
            #("b", tom.Table(dict.from_list([#("c", tom.Int(2))]))),
          ]),
        ),
      ),
    ])
  "a = {
  a = 1,
  b.c = 2,
}
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_invalid_newline_in_string_test() {
  "a = \"\n\""
  |> tom.parse
  |> should.equal(Error(tom.Unexpected("\n", "\"")))
}

pub fn parse_invalid_newline_windows_in_string_test() {
  "a = \"\r\n\""
  |> tom.parse
  |> should.equal(Error(tom.Unexpected("\r\n", "\"")))
}

pub fn parse_array_of_tables_empty_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.ArrayOfTables([
          dict.from_list([]),
          dict.from_list([]),
          dict.from_list([]),
        ]),
      ),
    ])
  "[[a]]
[[a]]
[[a]]
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_array_of_tables_nonempty_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.ArrayOfTables([
          dict.from_list([#("a", tom.Int(1))]),
          dict.from_list([#("a", tom.Int(2))]),
          dict.from_list([#("a", tom.Int(3))]),
        ]),
      ),
    ])
  "[[a]]
a = 1

[[a]]
a = 2

[[a]]
a = 3
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_array_of_tables_with_subtable_test() {
  let expected =
    dict.from_list([
      #(
        "fruits",
        tom.ArrayOfTables([
          dict.from_list([]),
          dict.from_list([
            #("name", tom.String("apple")),
            #(
              "physical",
              tom.Table(
                dict.from_list([
                  #("color", tom.String("red")),
                  #("shape", tom.String("round")),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    ])
  "[[fruits]]

[[fruits]]
name = \"apple\"

[fruits.physical]  # subtable
color = \"red\"
shape = \"round\"
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_single_quote_string_test() {
  let expected = dict.from_list([#("a", tom.String("\\n"))])
  "a = '\\n'\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_line_string_test() {
  let expected = dict.from_list([#("a", tom.String("hello\nworld"))])
  "a = \"\"\"
hello
world\"\"\"
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_line_single_quote_string_test() {
  let expected = dict.from_list([#("a", tom.String("hello\\n\nworld"))])
  "a = '''
hello\\n
world'''
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_line_single_quote_string_too_many_quotes_test() {
  "a = '''
''''
'''
"
  |> tom.parse
  |> should.equal(Error(tom.Unexpected("''''", "'''")))
}

pub fn parse_multi_line_literal_string_with_hash_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.String(
          "This string contains a #hash character\nand more text after it\n",
        ),
      ),
    ])
  "a = '''
This string contains a #hash character
and more text after it
'''
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_line_string_escape_newline_test() {
  let expected =
    dict.from_list([
      #("a", tom.String("The quick brown fox jumps over the lazy dog.")),
    ])
  "a = \"\"\"
The quick brown \\


  fox jumps over \\
    the lazy dog.\"\"\"
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_multi_line_string_escape_newline_windows_test() {
  let expected =
    dict.from_list([
      #("a", tom.String("The quick brown fox jumps over the lazy dog.")),
    ])
  "a = \"\"\"
The quick brown \\\r\n


  fox jumps over \\\r\n
    the lazy dog.\"\"\"
"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_nan_test() {
  let expected = dict.from_list([#("a", tom.Nan(tom.Positive))])
  "a = nan\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_positive_nan_test() {
  let expected = dict.from_list([#("a", tom.Nan(tom.Positive))])
  "a = +nan\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_negative_nan_test() {
  let expected = dict.from_list([#("a", tom.Nan(tom.Negative))])
  "a = -nan\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_infinity_test() {
  let expected = dict.from_list([#("a", tom.Infinity(tom.Positive))])
  "a = inf\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_positive_infinity_test() {
  let expected = dict.from_list([#("a", tom.Infinity(tom.Positive))])
  "a = +inf\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_negative_infinity_test() {
  let expected = dict.from_list([#("a", tom.Infinity(tom.Negative))])
  "a = -inf\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_write_to_key_that_does_not_exist_test() {
  let expected =
    dict.from_list([
      #("apple", tom.Table(dict.from_list([#("smooth", tom.Bool(True))]))),
    ])
  "apple.smooth = true\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_binary_test() {
  let expected = dict.from_list([#("a", tom.Int(0b101010))])
  "a = 0b101010\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_binary_positive_test() {
  let expected = dict.from_list([#("a", tom.Int(0b101010))])
  "a = +0b101010\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_binary_negative_test() {
  let expected = dict.from_list([#("a", tom.Int(0b101010 * -1))])
  "a = -0b101010\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_binary_underscores_test() {
  let expected = dict.from_list([#("a", tom.Int(0b101010))])
  "a = 0b1__010___1_0\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_octal_test() {
  let expected = dict.from_list([#("a", tom.Int(0o1234567))])
  "a = 0o1234567\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_octal_positive_test() {
  let expected = dict.from_list([#("a", tom.Int(0o1234567))])
  "a = +0o1234567\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_octal_negative_test() {
  let expected = dict.from_list([#("a", tom.Int(0o1234567 * -1))])
  "a = -0o1234567\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_octal_underscores_test() {
  let expected = dict.from_list([#("a", tom.Int(0o1234567))])
  "a = 0o1_23_45__6_7\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_hex_test() {
  let expected = dict.from_list([#("a", tom.Int(0xdeadbeef))])
  "a = 0xdeadbeef\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_hex_positive_test() {
  let expected = dict.from_list([#("a", tom.Int(0xdeadbeef))])
  "a = +0xdeadbeef\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_hex_negative_test() {
  let expected = dict.from_list([#("a", tom.Int(0xdeadbeef * -1))])
  "a = -0xdeadbeef\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_hex_underscores_test() {
  let expected = dict.from_list([#("a", tom.Int(0xdeadbeef))])
  "a = 0xd_e_a_d__b___e____e______f\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_hex_uppercase_test() {
  let expected = dict.from_list([#("a", tom.Int(0xdeadbeef))])
  "a = +0xDEADBEEF\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_exponent_test() {
  let expected = dict.from_list([#("a", tom.Float(1.0e6))])
  "a = 1e6\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_exponent_uppercase_test() {
  let expected = dict.from_list([#("a", tom.Float(1.0e6))])
  "a = 1E6\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_exponent_postive_test() {
  let expected = dict.from_list([#("a", tom.Float(5.0e22))])
  "a = 5e+22\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_exponent_negative_test() {
  let expected = dict.from_list([#("a", tom.Float(-2.0e-22))])
  "a = -2e-22\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_decimal_and_exponent_test() {
  let expected = dict.from_list([#("a", tom.Float(6.626e25))])
  "a = 6.626e25\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_decimal_and_exponent_positive_test() {
  let expected = dict.from_list([#("a", tom.Float(6.626e25))])
  "a = 6.626e+25\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_float_decimal_and_exponent_negative_test() {
  let expected = dict.from_list([#("a", tom.Float(6.626e-25))])
  "a = 6.626e-25\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_date_test() {
  let expected =
    dict.from_list([#("a", tom.Date(calendar.Date(1979, calendar.May, 27)))])
  "a = 1979-05-27\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 0)))])
  "a = 07:32:01\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_zero_minute_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 0, 1, 0)))])
  "a = 07:00:01\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_nanoseconds_999999_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 999_999_000)))])
  "a = 07:32:01.999999\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_nanoseconds_09179_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 91_790_000)))])
  "a = 07:32:01.09179\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_nanoseconds_123456789_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 123_456_789)))])
  "a = 07:32:01.123456789\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_nanoseconds_1_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 100_000_000)))])
  "a = 07:32:01.1\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_nanoseconds_001_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 1_000_000)))])
  "a = 07:32:01.001\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_nanoseconds_000000789_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 1, 789)))])
  "a = 07:32:01.000000789\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_time_no_seconds_test() {
  let expected =
    dict.from_list([#("a", tom.Time(calendar.TimeOfDay(7, 32, 0, 0)))])
  "a = 07:32\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_date_time_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.DateTime(
          calendar.Date(1979, calendar.May, 27),
          calendar.TimeOfDay(7, 32, 0, 0),
          offset: tom.Local,
        ),
      ),
    ])
  "a = 1979-05-27T07:32:00\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_date_time_space_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.DateTime(
          calendar.Date(1979, calendar.May, 27),
          calendar.TimeOfDay(7, 0, 1, 0),
          offset: tom.Local,
        ),
      ),
    ])
  "a = 1979-05-27 07:00:01\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_offset_z_date_time_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.DateTime(
          calendar.Date(1979, calendar.May, 27),
          calendar.TimeOfDay(7, 32, 0, 0),
          offset: tom.Offset(calendar.utc_offset),
        ),
      ),
    ])
  "a = 1979-05-27T07:32:00Z\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_offset_z_date_time_space_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.DateTime(
          calendar.Date(1979, calendar.May, 27),
          calendar.TimeOfDay(7, 0, 1, 0),
          offset: tom.Offset(calendar.utc_offset),
        ),
      ),
    ])
  "a = 1979-05-27 07:00:01Z\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_offset_positive_date_time_space_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.DateTime(
          calendar.Date(1979, calendar.May, 27),
          calendar.TimeOfDay(7, 0, 1, 0),
          offset: tom.Offset(duration.add(
            duration.hours(7),
            duration.minutes(40),
          )),
        ),
      ),
    ])
  "a = 1979-05-27 07:00:01+07:40\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_offset_negative_date_time_space_test() {
  let expected =
    dict.from_list([
      #(
        "a",
        tom.DateTime(
          calendar.Date(1979, calendar.May, 27),
          calendar.TimeOfDay(7, 0, 1, 0),
          offset: tom.Offset(duration.add(
            duration.hours(-7),
            duration.minutes(-1),
          )),
        ),
      ),
    ])
  "a = 1979-05-27 07:00:01-07:01\n"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_no_trailing_newline_test() {
  let expected = dict.from_list([#("a", tom.Int(1))])
  "a = 1"
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_trailing_whitespace_test() {
  let expected = dict.from_list([#("a", tom.Int(1))])
  "a = 1 "
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_trailing_other_test() {
  "a = 1 b"
  |> tom.parse
  |> should.equal(Error(tom.Unexpected("b", "\n")))
}

pub fn parse_sequence_e_test() {
  "a = \"\\e\""
  |> tom.parse
  |> should.equal(Ok(dict.from_list([#("a", tom.String("\u{001b}"))])))
}

pub fn parse_sequence_f_test() {
  "a = \"\\f\""
  |> tom.parse
  |> should.equal(Ok(dict.from_list([#("a", tom.String("\f"))])))
}

pub fn parse_sequence_b_test() {
  "a = \"\\b\""
  |> tom.parse
  |> should.equal(Ok(dict.from_list([#("a", tom.String("\u{0008}"))])))
}

pub fn parse_ignore_comments_test() {
  let expected = dict.from_list([#("field", tom.String("#"))])
  "# This should be ignored
field = \"#\""
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn parse_not_remove_hash_in_string_test() {
  let content = tom.Table(dict.from_list([#("field", tom.String("#"))]))
  let expected = dict.from_list([#("section", content)])
  "[section]
field = \"#\""
  |> tom.parse
  |> should.equal(Ok(expected))
}

pub fn get_data_in_table_and_inline_table_test() {
  let toml =
    "section = { field = \"data\" }
another_section = { another_field = \"another_data\", int_field = 2 }
[still_a_section]
still_a_field = 1"
    |> tom.parse
  toml
  |> result.is_ok
  |> should.equal(True)
  use toml <- result.map(toml)

  tom.get(toml, ["section", "field"])
  |> should.equal(Ok(tom.String("data")))

  tom.get(toml, ["another_section", "another_field"])
  |> should.equal(Ok(tom.String("another_data")))

  tom.get(toml, ["another_section", "int_field"])
  |> should.equal(Ok(tom.Int(2)))

  tom.get(toml, ["still_a_section", "still_a_field"])
  |> should.equal(Ok(tom.Int(1)))
}

pub fn tom_as_int_test() {
  tom.as_int(tom.Int(1))
  |> should.equal(Ok(1))

  tom.as_int(tom.Float(1.5))
  |> should.equal(Error(tom.WrongType([], "Int", "Float")))
}

pub fn tom_as_float_test() {
  tom.as_float(tom.Float(1.5))
  |> should.equal(Ok(1.5))

  tom.as_float(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "Float", "Int")))
}

pub fn tom_as_bool_test() {
  tom.as_bool(tom.Bool(True))
  |> should.equal(Ok(True))

  tom.as_bool(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "Bool", "Int")))
}

pub fn tom_as_string_test() {
  tom.as_string(tom.String("hello"))
  |> should.equal(Ok("hello"))

  tom.as_string(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "String", "Int")))
}

pub fn tom_as_date_test() {
  let date = calendar.Date(2023, calendar.September, 23)

  tom.as_date(tom.Date(date))
  |> should.equal(Ok(date))

  tom.as_date(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "Date", "Int")))
}

pub fn tom_as_time_of_day_test() {
  let time = calendar.TimeOfDay(12, 30, 0, 4_000_000)

  tom.as_time_of_day(tom.Time(time))
  |> should.equal(Ok(time))

  tom.as_time_of_day(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "Time", "Int")))
}

pub fn tom_as_calendar_time_test() {
  let date = calendar.Date(2023, calendar.September, 23)
  let time_of_day = calendar.TimeOfDay(10, 30, 00, 00)
  let offset = tom.Local

  tom.as_calendar_time(tom.DateTime(date, time_of_day, offset))
  |> should.equal(Ok(#(date, time_of_day, offset)))

  tom.as_calendar_time(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "DateTime", "Int")))
}

pub fn tom_as_timestamp_test() {
  let date = calendar.Date(1970, calendar.January, 1)
  let time_of_day = calendar.TimeOfDay(0, 0, 00, 00)

  tom.as_timestamp(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "DateTime with offset", "Int")))

  tom.as_timestamp(tom.DateTime(date, time_of_day, tom.Local))
  |> should.equal(Error(tom.WrongType([], "DateTime with offset", "DateTime")))

  tom.as_timestamp(tom.DateTime(
    date,
    time_of_day,
    tom.Offset(duration.seconds(0)),
  ))
  |> should.equal(Ok(timestamp.from_unix_seconds(0)))
}

pub fn tom_as_array_test() {
  let array = [tom.Int(1), tom.Int(2), tom.Int(3)]

  tom.as_array(tom.Array(array))
  |> should.equal(Ok(array))

  tom.as_array(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "Array", "Int")))
}

pub fn tom_as_table_test() {
  let dict = dict.new()

  tom.as_table(tom.Table(dict))
  |> should.equal(Ok(dict))

  tom.as_table(tom.InlineTable(dict))
  |> should.equal(Ok(dict))

  tom.as_table(tom.Int(1))
  |> should.equal(Error(tom.WrongType([], "Table", "Int")))
}

pub fn tom_as_number_test() {
  tom.as_number(tom.Int(1))
  |> should.equal(Ok(tom.NumberInt(1)))

  tom.as_number(tom.Float(1.5))
  |> should.equal(Ok(tom.NumberFloat(1.5)))

  tom.as_number(tom.Bool(True))
  |> should.equal(Error(tom.WrongType([], "Number", "Bool")))
}

pub fn get_date_test() {
  let assert Ok(parsed) = tom.parse("a.b.c = 1979-05-27")

  tom.get_date(parsed, ["a", "b", "c"])
  |> should.equal(Ok(calendar.Date(1979, calendar.May, 27)))

  tom.get_time_of_day(parsed, ["a", "b", "c"])
  |> should.equal(Error(tom.WrongType(["a", "b", "c"], "Time", "Date")))
}

pub fn get_time_of_day_test() {
  let assert Ok(parsed) = tom.parse("a.b.c = 07:32:00")

  tom.get_time_of_day(parsed, ["a", "b", "c"])
  |> should.equal(Ok(calendar.TimeOfDay(7, 32, 0, 0)))

  tom.get_time_of_day(parsed, ["foo"])
  |> should.equal(Error(tom.NotFound(["foo"])))
}

pub fn get_calendar_time_test() {
  let assert Ok(parsed) = tom.parse("a.b.c = 1979-05-27T07:32:00Z")
  let expected = #(
    calendar.Date(1979, calendar.May, 27),
    calendar.TimeOfDay(7, 32, 0, 0),
    tom.Offset(calendar.utc_offset),
  )

  tom.get_calendar_time(parsed, ["a", "b", "c"])
  |> should.equal(Ok(expected))
}

pub fn get_timestamp_test() {
  let assert Ok(parsed) = tom.parse("a.b.c = 1970-01-01T00:00:00Z")
  tom.get_timestamp(parsed, ["a", "b", "c"])
  |> should.equal(Ok(timestamp.from_unix_seconds(0)))

  let assert Ok(parsed) = tom.parse("a.b.c = 1970-01-01T00:00:00")
  tom.get_timestamp(parsed, ["a", "b", "c"])
  |> should.equal(
    Error(tom.WrongType(["a", "b", "c"], "DateTime with offset", "DateTime")),
  )

  let assert Ok(parsed) = tom.parse("a = 1")
  tom.get_timestamp(parsed, ["a", "b", "c"])
  |> should.equal(Error(tom.WrongType(["a"], "Table", "Int")))
}
