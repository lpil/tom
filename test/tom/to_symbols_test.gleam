import tom

pub fn gleam_toml_test() {
  let assert Ok(symbols) =
    tom.to_symbols(
      "
name = \"tom\"
version = \"2.0.2\"

[dependencies]
gleam_stdlib = \">= 0.33.0 and < 3.0.0\"
",
    )

  assert symbols == []
}
