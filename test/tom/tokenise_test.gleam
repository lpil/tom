import gleam/option.{None, Some}
import gleam/time/calendar
import gleam/time/duration
import tom.{
  BareKeyToken, BasicStringToken, BoolToken, CommaToken, CommentToken, DotToken,
  DoubleLeftBracketToken, DoubleRightBracketToken, EndOfFile, EqualsToken,
  FloatToken, IncompleteDate, IncompleteFloat, IncompleteTime, InfinityToken,
  IntToken, LeftBraceToken, LeftBracketToken, LiteralStringToken,
  LocalDateTimeToken, LocalDateToken, LocalTimeToken, MultiLineBasicStringToken,
  MultiLineLiteralStringToken, NanToken, Negative, NewlineToken,
  OffsetDateTimeToken, Positive, RightBraceToken, RightBracketToken,
  UnknownSequence, UnterminatedString, WhitespaceToken,
}

pub fn empty_test() {
  assert tom.to_tokens("") == Ok([EndOfFile])
}

pub fn equal_test() {
  assert tom.to_tokens("=") == Ok([EqualsToken, EndOfFile])
}

pub fn dot_test() {
  assert tom.to_tokens(".") == Ok([DotToken, EndOfFile])
}

pub fn comma_test() {
  assert tom.to_tokens(",") == Ok([CommaToken, EndOfFile])
}

pub fn braces_test() {
  assert tom.to_tokens("{}") == Ok([LeftBraceToken, RightBraceToken, EndOfFile])
}

pub fn brackets_test() {
  assert tom.to_tokens("[]")
    == Ok([LeftBracketToken, RightBracketToken, EndOfFile])
}

pub fn double_brackets_test() {
  assert tom.to_tokens("[[]]")
    == Ok([DoubleLeftBracketToken, DoubleRightBracketToken, EndOfFile])
}

pub fn true_test() {
  assert tom.to_tokens("true") == Ok([BoolToken(True), EndOfFile])
}

pub fn false_test() {
  assert tom.to_tokens("false") == Ok([BoolToken(False), EndOfFile])
}

pub fn nan_test() {
  assert tom.to_tokens("nan") == Ok([NanToken(None), EndOfFile])
}

pub fn nan_positive_test() {
  assert tom.to_tokens("+nan") == Ok([NanToken(Some(Positive)), EndOfFile])
}

pub fn nan_negative_test() {
  assert tom.to_tokens("-nan") == Ok([NanToken(Some(Negative)), EndOfFile])
}

pub fn inf_test() {
  assert tom.to_tokens("inf") == Ok([InfinityToken(None), EndOfFile])
}

pub fn inf_positive_test() {
  assert tom.to_tokens("+inf") == Ok([InfinityToken(Some(Positive)), EndOfFile])
}

pub fn inf_negative_test() {
  assert tom.to_tokens("-inf") == Ok([InfinityToken(Some(Negative)), EndOfFile])
}

pub fn newline_test() {
  assert tom.to_tokens("\n\n\n")
    == Ok([NewlineToken, NewlineToken, NewlineToken, EndOfFile])
}

pub fn comment_test() {
  assert tom.to_tokens("# Hello, world!\n\n")
    == Ok([CommentToken(" Hello, world!\n"), NewlineToken, EndOfFile])
}

pub fn comment_no_newline_test() {
  assert tom.to_tokens("# Hello, world!")
    == Ok([CommentToken(" Hello, world!"), EndOfFile])
}

pub fn spaces_test() {
  assert tom.to_tokens(
      "# 1
      # 2
",
    )
    == Ok([
      CommentToken(" 1\n"),
      WhitespaceToken("      "),
      CommentToken(" 2\n"),
      EndOfFile,
    ])
}

pub fn tabs_test() {
  assert tom.to_tokens(
      "# 1
\t\t\t# 2
",
    )
    == Ok([
      CommentToken(" 1\n"),
      WhitespaceToken("\t\t\t"),
      CommentToken(" 2\n"),
      EndOfFile,
    ])
}

pub fn tabs_and_spaces_test() {
  assert tom.to_tokens(
      "# 1
\t \t \t# 2
",
    )
    == Ok([
      CommentToken(" 1\n"),
      WhitespaceToken("\t \t \t"),
      CommentToken(" 2\n"),
      EndOfFile,
    ])
}

pub fn literal_string_test() {
  assert tom.to_tokens("'Hello'")
    == Ok([
      LiteralStringToken(src: "Hello"),
      EndOfFile,
    ])
}

pub fn literal_string_newline_test() {
  assert tom.to_tokens("'1\n2'") == Error(UnterminatedString(byte_position: 0))
}

pub fn literal_string_unterminated_test() {
  assert tom.to_tokens("'1") == Error(UnterminatedString(byte_position: 0))
}

pub fn multiline_literal_string_test() {
  assert tom.to_tokens(
      "'''
1
2
3
'''",
    )
    == Ok([
      MultiLineLiteralStringToken(src: "\n1\n2\n3\n", value: "1\n2\n3\n"),
      EndOfFile,
    ])
}

pub fn basic_string_test() {
  assert tom.to_tokens("\"Hello\"")
    == Ok([
      BasicStringToken(src: "Hello", value: "Hello"),
      EndOfFile,
    ])
}

pub fn basic_string_newline_test() {
  assert tom.to_tokens("\"1\n2\"")
    == Error(UnterminatedString(byte_position: 0))
}

pub fn basic_string_unterminated_test() {
  assert tom.to_tokens("\"1") == Error(UnterminatedString(byte_position: 0))
}

pub fn basic_string_quote_escape_test() {
  assert tom.to_tokens("\"\\\"\"")
    == Ok([
      BasicStringToken(src: "\\\"", value: "\""),
      EndOfFile,
    ])
}

pub fn basic_string_backslash_escape_test() {
  assert tom.to_tokens("\"\\\\\"")
    == Ok([
      BasicStringToken(src: "\\\\", value: "\\"),
      EndOfFile,
    ])
}

pub fn basic_string_backspace_escape_test() {
  assert tom.to_tokens("\"\\b\"")
    == Ok([
      BasicStringToken(src: "\\b", value: "\u{8}"),
      EndOfFile,
    ])
}

pub fn basic_string_tab_escape_test() {
  assert tom.to_tokens("\"\\t\"")
    == Ok([
      BasicStringToken(src: "\\t", value: "\t"),
      EndOfFile,
    ])
}

pub fn basic_string_newline_escape_test() {
  assert tom.to_tokens("\"\\n\"")
    == Ok([
      BasicStringToken(src: "\\n", value: "\n"),
      EndOfFile,
    ])
}

pub fn basic_string_form_feed_escape_test() {
  assert tom.to_tokens("\"\\f\"")
    == Ok([
      BasicStringToken(src: "\\f", value: "\u{c}"),
      EndOfFile,
    ])
}

pub fn basic_string_carriage_return_escape_test() {
  assert tom.to_tokens("\"\\r\"")
    == Ok([
      BasicStringToken(src: "\\r", value: "\r"),
      EndOfFile,
    ])
}

pub fn basic_string_escape_escape_test() {
  assert tom.to_tokens("\"\\e\"")
    == Ok([
      BasicStringToken(src: "\\e", value: "\u{1b}"),
      EndOfFile,
    ])
}

pub fn basic_string_hex_escape_test() {
  assert tom.to_tokens("\"\\x7f\"")
    == Ok([
      BasicStringToken(src: "\\x7f", value: "\u{7f}"),
      EndOfFile,
    ])
}

pub fn basic_string_hex_escape_upper_range_test() {
  assert tom.to_tokens("\"\\xff\"")
    == Ok([
      BasicStringToken(src: "\\xff", value: "\u{ff}"),
      EndOfFile,
    ])
}

pub fn basic_string_unicode_escape_test() {
  assert tom.to_tokens("\"\\u03B1\"")
    == Ok([
      BasicStringToken(src: "\\u03B1", value: "\u{3b1}"),
      EndOfFile,
    ])
}

pub fn basic_string_unicode_long_escape_test() {
  assert tom.to_tokens("\"\\U0001F600\"")
    == Ok([
      BasicStringToken(src: "\\U0001F600", value: "\u{1f600}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_test() {
  assert tom.to_tokens("\"\"\"\nHello\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\nHello", value: "Hello"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_no_newline_test() {
  assert tom.to_tokens("\"\"\"Hello\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "Hello", value: "Hello"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_multiline_test() {
  assert tom.to_tokens("\"\"\"\n1\n2\n3\n\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n1\n2\n3\n", value: "1\n2\n3\n"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_newline_test() {
  assert tom.to_tokens("\"\"\"\n1\n2\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n1\n2", value: "1\n2"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_unterminated_test() {
  assert tom.to_tokens("\"\"\"\n1")
    == Error(UnterminatedString(byte_position: 0))
}

pub fn multiline_basic_string_quote_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\\"\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\\"", value: "\""),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_backslash_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\\\\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\\\", value: "\\"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_backspace_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\b\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\b", value: "\u{8}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_tab_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\t\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\t", value: "\t"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_newline_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\n\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\n", value: "\n"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_form_feed_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\f\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\f", value: "\u{c}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_carriage_return_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\r\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\r", value: "\r"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_escape_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\e\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\e", value: "\u{1b}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_hex_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\x7f\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\x7f", value: "\u{7f}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_hex_escape_upper_range_test() {
  assert tom.to_tokens("\"\"\"\n\\xff\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\xff", value: "\u{ff}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_unicode_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\u03B1\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\u03B1", value: "\u{3b1}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_unicode_long_escape_test() {
  assert tom.to_tokens("\"\"\"\n\\U0001F600\"\"\"")
    == Ok([
      MultiLineBasicStringToken(src: "\n\\U0001F600", value: "\u{1f600}"),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_line_ending_backslash_test() {
  assert tom.to_tokens(
      "\"\"\"\nThe quick brown \\\nfox jumps over \\\nthe lazy dog.\"\"\"",
    )
    == Ok([
      MultiLineBasicStringToken(
        src: "\nThe quick brown \\\nfox jumps over \\\nthe lazy dog.",
        value: "The quick brown fox jumps over the lazy dog.",
      ),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_line_ending_backslash_spaces_test() {
  assert tom.to_tokens(
      "\"\"\"\nThe quick brown \\\n  fox jumps over \\\n  the lazy dog.\"\"\"",
    )
    == Ok([
      MultiLineBasicStringToken(
        src: "\nThe quick brown \\\n  fox jumps over \\\n  the lazy dog.",
        value: "The quick brown fox jumps over the lazy dog.",
      ),
      EndOfFile,
    ])
}

pub fn multiline_basic_string_line_ending_backslash_tabs_test() {
  assert tom.to_tokens(
      "\"\"\"\nThe quick brown \\\n\tfox jumps over \\\n\tthe lazy dog.\"\"\"",
    )
    == Ok([
      MultiLineBasicStringToken(
        src: "\nThe quick brown \\\n\tfox jumps over \\\n\tthe lazy dog.",
        value: "The quick brown fox jumps over the lazy dog.",
      ),
      EndOfFile,
    ])
}

pub fn unexpected_test() {
  assert tom.to_tokens("???") == Error(UnknownSequence(0))
}

pub fn key_test() {
  assert tom.to_tokens("name") == Ok([BareKeyToken("name"), EndOfFile])
}

pub fn key_fancy_test() {
  assert tom.to_tokens("_H311o-W0rld_")
    == Ok([BareKeyToken("_H311o-W0rld_"), EndOfFile])
}

pub fn key_value_test() {
  assert tom.to_tokens("items = []")
    == Ok([
      BareKeyToken("items"),
      WhitespaceToken(" "),
      EqualsToken,
      WhitespaceToken(" "),
      LeftBracketToken,
      RightBracketToken,
      EndOfFile,
    ])
}

pub fn number_test() {
  assert tom.to_tokens("1234567890")
    == Ok([IntToken("1234567890", 1_234_567_890), EndOfFile])
}

pub fn int_positive_test() {
  assert tom.to_tokens("+1234567890")
    == Ok([IntToken("+1234567890", 1_234_567_890), EndOfFile])
}

pub fn int_negative_test() {
  assert tom.to_tokens("-1234567890")
    == Ok([IntToken("-1234567890", -1_234_567_890), EndOfFile])
}

pub fn int_underscore_test() {
  assert tom.to_tokens("12_345_67__890")
    == Ok([IntToken("12_345_67__890", 1_234_567_890), EndOfFile])
}

pub fn float_test() {
  assert tom.to_tokens("12.34") == Ok([FloatToken("12.34", 12.34), EndOfFile])
}

pub fn float_negative_test() {
  assert tom.to_tokens("-12.34")
    == Ok([FloatToken("-12.34", -12.34), EndOfFile])
}

pub fn float_positive_test() {
  assert tom.to_tokens("+12.34") == Ok([FloatToken("+12.34", 12.34), EndOfFile])
}

pub fn float_underscore_test() {
  assert tom.to_tokens("12_34.5_67__890")
    == Ok([FloatToken("12_34.5_67__890", 1234.567_89), EndOfFile])
}

pub fn float_incomplete_test() {
  assert tom.to_tokens("12.") == Error(IncompleteFloat(2))
}

pub fn lex_float_exponent_test() {
  assert tom.to_tokens("1e6") == Ok([FloatToken("1e6", 1.0e6), EndOfFile])
}

pub fn lex_float_exponent_uppercase_test() {
  assert tom.to_tokens("1E6") == Ok([FloatToken("1E6", 1.0e6), EndOfFile])
}

pub fn lex_float_exponent_negative_test() {
  assert tom.to_tokens("-2e-22")
    == Ok([FloatToken("-2e-22", -2.0e-22), EndOfFile])
}

pub fn lex_float_decimal_and_exponent_test() {
  assert tom.to_tokens("6.626e25")
    == Ok([FloatToken("6.626e25", 6.626e25), EndOfFile])
}

pub fn lex_float_decimal_and_exponent_positive_test() {
  assert tom.to_tokens("6.626e+25")
    == Ok([FloatToken("6.626e+25", 6.626e25), EndOfFile])
}

pub fn lex_float_decimal_and_exponent_negative_test() {
  assert tom.to_tokens("6.626e-25")
    == Ok([FloatToken("6.626e-25", 6.626e-25), EndOfFile])
}

pub fn local_time_test() {
  assert tom.to_tokens("07:32:00")
    == Ok([
      LocalTimeToken("07:32:00", calendar.TimeOfDay(7, 32, 0, 0)),
      EndOfFile,
    ])
}

pub fn local_time_fractional_seconds_test() {
  assert tom.to_tokens("00:32:00.1234")
    == Ok([
      LocalTimeToken("00:32:00.1234", calendar.TimeOfDay(0, 32, 0, 123_400_000)),
      EndOfFile,
    ])
}

pub fn local_time_incomplete_minutes_test() {
  assert tom.to_tokens("07:") == Error(IncompleteTime(3))
}

pub fn local_time_incomplete_seconds_test() {
  assert tom.to_tokens("07:32")
    == Ok([
      LocalTimeToken("07:32", calendar.TimeOfDay(7, 32, 0, 0)),
      EndOfFile,
    ])
}

pub fn local_time_incomplete_fractional_seconds_test() {
  assert tom.to_tokens("07:32:00.") == Error(IncompleteTime(9))
}

pub fn local_date_test() {
  assert tom.to_tokens("1991-01-05")
    == Ok([
      LocalDateToken("1991-01-05", calendar.Date(1991, calendar.January, 5)),
      EndOfFile,
    ])
}

pub fn local_date_incomplete_month_test() {
  assert tom.to_tokens("1991-") == Error(IncompleteDate(5))
}

pub fn local_date_incomplete_day_test() {
  assert tom.to_tokens("1991-01-") == Error(IncompleteDate(8))
}

pub fn local_date_time_test() {
  assert tom.to_tokens("1991-01-05T07:32:00")
    == Ok([
      LocalDateTimeToken(
        "1991-01-05T07:32:00",
        calendar.Date(1991, calendar.January, 5),
        calendar.TimeOfDay(7, 32, 0, 0),
      ),
      EndOfFile,
    ])
}

pub fn offset_date_time_test() {
  assert tom.to_tokens("1991-01-05T07:32:00Z")
    == Ok([
      OffsetDateTimeToken(
        "1991-01-05T07:32:00Z",
        calendar.Date(1991, calendar.January, 5),
        calendar.TimeOfDay(7, 32, 0, 0),
        calendar.utc_offset,
      ),
      EndOfFile,
    ])
}

pub fn offset_date_time_positive_offset_test() {
  assert tom.to_tokens("1991-01-05T07:32:00+07:30")
    == Ok([
      OffsetDateTimeToken(
        "1991-01-05T07:32:00+07:30",
        calendar.Date(1991, calendar.January, 5),
        calendar.TimeOfDay(7, 32, 0, 0),
        duration.add(duration.hours(7), duration.minutes(30)),
      ),
      EndOfFile,
    ])
}

pub fn offset_date_time_negative_offset_test() {
  assert tom.to_tokens("1991-01-05T07:32:00-05:15")
    == Ok([
      OffsetDateTimeToken(
        "1991-01-05T07:32:00-05:15",
        calendar.Date(1991, calendar.January, 5),
        calendar.TimeOfDay(7, 32, 0, 0),
        duration.add(duration.hours(-5), duration.minutes(-15)),
      ),
      EndOfFile,
    ])
}
