#import "../template.typ": *

= Vibe coding with this spec

== Handing it to a coding agent

Yes, another agent can build #app from this report. `.typ` files are plain text, and chapters 2–4 are written
as a spec. Paste this into the agent, run from `~/personal_code/otpdash`:

#prompt[Read `spec/main.typ` and every chapter it includes. Build the Rust app it describes in this directory,
following chapters 2–5. Constraints: edition 2024, the dependencies and major versions in chapter 4 and nothing else, three source
files (`main.rs`, `vault.rs`, `dashboard.rs`), and no features that aren't in chapter 2. Do *not* copy
`spec/reference/`. Write the code step by step and commit after each build-guide step.
You're done when `cargo test` and `cargo clippy --all-targets` are clean and you've listed which chapter 2
acceptance items you could verify and which need a human (anything interactive). As the very last commit,
delete `spec/` (`git rm -r spec`); the report stays in git history.]

If you'd rather just have it working: `cp -r spec/reference/{Cargo.toml,src} .` is the tested result.

== Building it yourself with AI help

To *learn*, have the AI write one step at a time. Read each step and change something by hand before moving on.

- Give it chapters 2–4 as context.
- Ask for one step at a time, and add "nothing beyond the spec".
- After each step, run `cargo build && cargo clippy && cargo test` and paste back the *errors*.
- Ask it to *explain* any line you don't understand. That's where most of the learning happens.

== Prompts, one per step

#prompt[Scaffold a Rust binary `otpdash` (edition 2024) with clap (derive), serde (derive), age, anyhow, dirs, inquire,
serde_json, totp-rs. Only give me the cargo commands.]

#prompt[Write the clap CLI from chapter 2: an optional subcommand (none = dashboard), plus show/add/rm/rename/import/export/passwd. Use `todo!()` for every command body.]

#prompt[Write `vault.rs`: `Entry`, `Entries = BTreeMap`, `db_path()` with the `OTPDASH_DB` override, `load`/`save` with an age passphrase,
an atomic tmp+fsync+rename write, and the error "wrong password". Create the DB on first open. Add a round-trip test.]

#prompt[Add a `Vault` struct (path, pass, entries) with open/add/remove/rename/set_password. Every mutating method saves.]

#prompt[Add TOTP with totp-rs (`Builder` defaults: SHA-1, 30 s, 6 digits; `build_noncompliant` so 80-bit secrets work), `normalize`, `code_for`, and `lines(filter, t)` that returns
padded `CODE  NAME  USER` strings. Add the RFC 6238 test vector as a test.]

#prompt[Write `main.rs`: log in with inquire (a new password asked twice if there's no DB yet), then dispatch the one-shot commands to Vault methods.]

#prompt[Add `import` (skip everything before the first `{`, use `.name` not the map key, skip duplicates, return (added, skipped))
and `export` (the same JSON shape). Add a test: a RusTOTPony export with junk in front, plus an export→import round trip.]

#prompt[Write `dashboard.rs` from chapter 2: a clear-and-redraw loop, a main menu (Copy, Live, Add, More…, Quit) and a More… submenu
(Remove, Rename, Import, Export, Change password, Back). Esc goes back, and errors show in a status line.
Copy uses pbcopy/wl-copy/xclip. Live uses a stdin thread + `recv_timeout`. Export uses create_new + mode 0600.]

== Learning checkpoints

+ Why does `export` take `&self` but `import` take `&mut self`?
+ What happens at each `?` in `load`?
+ Why is `name` unusable after `entries.insert(name, …)`?
+ How does `collect()` turn many `Result`s into one?
+ Why does Live codes need a thread?
+ Why is it safe to press Ctrl-C anywhere in the dashboard?
