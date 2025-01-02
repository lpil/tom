# Changelog

## v1.1.1 - 2025-01-02

- Fixed bug where `InlineTable` could not be cast `as_table`.

## v1.1.0 - 2024-09-23

- Added the `as_array`, `as_bool`, `as_date`, `as_date_time`, `as_float`,
  `as_int`, `as_number`, `as_string`, `as_table`, and `as_time`,
  functions.

## v1.0.1 - 2024-07-15

- Fixed a bug where `get` would not work in `InlineTable`.

## v1.0.0 - 2024-05-04

- Added support for `\e`, `\f`, `\b`.
- Fixed a bug where strings with `#` in them would fail to parse.

## v0.3.0 - 2023-12-07

- Updated for Gleam v0.33.0.

## v0.2.1 - 2023-11-20

- Documents with no trailing newline can now be parsed.

## v0.2.0 - 2023-11-14

- The library can now parse full TOML documents, with the exception of the
  string escape codes `\b`, `\f`, `\e`, `\xHH`, `\uHHHH`, and `\UHHHHHHHH`.

## v0.1.0 - 2023-11-12

- Initial release
