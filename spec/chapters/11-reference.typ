#import "../template.typ": *

= Reference implementation

The files below are included straight from `spec/reference/`. They were checked with `cargo test` (3 tests pass)
and `cargo clippy --all-targets` (no warnings). Interactive behaviour wasn't tested automatically, so use the chapter 2 checklist for that.

== `Cargo.toml`
#source("/reference/Cargo.toml", lang: "toml")

== `src/main.rs`
#source("/reference/src/main.rs")

== `src/vault.rs`
#source("/reference/src/vault.rs")

== `src/dashboard.rs`
#source("/reference/src/dashboard.rs")
