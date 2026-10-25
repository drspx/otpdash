#import "../template.typ": *

= Testing

== Where tests live in Rust

#table(
  columns: (auto, 1fr, auto),
  [*Style*], [*How*], [*Can test private fns?*],
  [Same file (convention)], [`#[cfg(test)] mod tests { use super::*; … }` at the bottom of the file.], [Yes],
  [Separate file], [`#[cfg(test)] mod tests;` in `vault.rs` puts the tests in `src/vault/tests.rs`.], [Yes],
  [Integration tests], [Files in `tests/*.rs`. Each one is a separate crate that can only use the *public* API.
    It needs a `src/lib.rs`, because a crate that only has `main.rs` can't be imported.], [No],
)

#app puts its tests in `vault.rs`, because all the logic is there. `main.rs` and `dashboard.rs` only
handle prompts and printing, so test those by hand with the acceptance checklist.

== The three tests

#snippet("/reference/src/vault.rs", "#[cfg(test)]")

#table(
  columns: (auto, 1fr),
  [*Test*], [*Fails if…*],
  [`rfc6238_vector`], [The TOTP maths, the base32 alphabet or the padding is wrong. It checks against the official RFC vector.],
  [`save_load_and_wrong_password`], [The first open doesn't create the DB, encryption or serialisation breaks, normalisation or rename breaks, a wrong password is accepted, or `set_password` doesn't re-encrypt.],
  [`import_rustotpony_export_and_own_roundtrip`], [Escape-code junk breaks the import, the stale key is used, duplicates aren't skipped, or export and import disagree.],
)

Run them with `cargo test`. They take about 10 s, because age's scrypt is slow on purpose.

#note[
  - `#[cfg(test)]` compiles the module only for `cargo test`. `use super::*;` brings in private items too.
  - The tests can read `v.path` even though it's private, because a child module can see its parent's private items.
  - `assert_eq!` needs `PartialEq` and `Debug`. That's why `Entry` derives them.
]

== Manual testing without risking real data

```bash
export OTPDASH_DB=/tmp/otpdash-test.age
cargo run                     # dashboard on a throw-away DB
cargo run -- show
unset OTPDASH_DB; rm -f /tmp/otpdash-test.age
```

Check codes against your phone, or against https://totp.danhersam.com with the secret `JBSWY3DPEHPK3PXP`.

== Tooling

```bash
cargo fmt && cargo clippy && cargo test
```
