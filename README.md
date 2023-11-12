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
  name = \"tom\"
  version = \"0.1.0\"
"

pub fn main() {
  let assert Ok(parsed) = tom.parse(config)
  // Now do stuff with your data!
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
- [ ] Sub-table in array of tables
- [x] String
- [ ] Multi-line string
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
- [ ] Hex integer
- [ ] Octal integer
- [ ] Binary integer
- [x] Float
- [ ] Float with exponent
- [x] Boolean
- [ ] Offset Date-Time
- [ ] Local Date-Time
- [ ] Local Date
- [ ] Local Time
- [x] Array
- [x] Inline Table
