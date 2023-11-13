# tom

A (not quite complete) pure Gleam TOML parser!

[![Package Version](https://img.shields.io/hexpm/v/tom)](https://hex.pm/packages/tom)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/tom/)


```sh
gleam add tom
```
```gleam
import tom

const config = "
  [person]
  name = \"Lucy\"
  is_cool = true
"

pub fn main() {
  // Parse a string of TOML
  let assert Ok(parsed) = tom.parse(config)

  // Now you can work with the data directly, or you can use the `get_*`
  // functions to retrieve values.

  tom.get_string(parsed, ["person", "name"])
  // -> Ok("Lucy")

  let is_cool = tom.get_bool(parsed, ["person", "is_cool"])
  // -> Ok(True)
}
```

Further documentation can be found at <https://hexdocs.pm/tom>.

## Status

- [x] Bare key
- [x] Double quoted key
- [x] Single quoted key
- [x] Multi-segment key
- [x] Mixed multi-segment key
- [x] Table
- [x] Array of tables
- [x] Sub-table in array of tables
- [x] String
- [x] Multi-line string
- [x] Single quote string
- [x] Multi-line single quote string
- [x] String \\\\n escape sequence
- [ ] String \b escape sequence
- [x] String \t escape sequence
- [x] String \n escape sequence
- [ ] String \f escape sequence
- [x] String \r escape sequence
- [ ] String \e escape sequence
- [x] String \" escape sequence
- [x] String \\ escape sequence
- [ ] String \xHH escape sequence
- [ ] String \uHHHH escape sequence
- [ ] String \UHHHHHHHH escape sequence
- [x] Positive number operator
- [x] Negative number operator
- [x] Decimal integer
- [x] Decimal integer with underscores
- [x] Hex integer
- [x] Octal integer
- [x] Binary integer
- [x] Float
- [x] Infinity
- [x] Negative Infinity
- [x] NaN
- [x] Negative NaN
- [ ] Float with exponent
- [x] Boolean
- [ ] Offset Date-Time
- [ ] Local Date-Time
- [ ] Local Date
- [ ] Local Time
- [x] Array
- [x] Inline Table
