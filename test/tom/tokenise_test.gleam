import gleam/option.{None, Some}
import tom.{
  BareKeyToken, BoolToken, CommentToken, DotToken, DoubleLeftBracketToken,
  DoubleRightBracketToken, EndOfFile, EqualsToken, InfinityToken, IntToken,
  LeftBraceToken, LeftBracketToken, NanToken, Negative, NewlineToken, Positive,
  RightBraceToken, RightBracketToken, WhitespaceToken,
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
    == Ok([CommentToken(" Hello, world!"), NewlineToken, EndOfFile])
}
// pub fn key_value_with_whitespace_tokenises_test() {
//   assert tom2.to_tokens("answer = 42")
//     == Ok([
//       BareKeyToken("answer"),
//       WhitespaceToken(" "),
//       EqualsToken,
//       WhitespaceToken(" "),
//       IntToken("42", 42),
//     ])
// }
