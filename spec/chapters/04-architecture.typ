#import "../template.typ": *

= Architecture

== Layout

```text
otpdash/
├── Cargo.toml
├── src/
│   ├── main.rs        CLI (clap), login, password prompts, one-shot commands   ~90 lines
│   ├── vault.rs       Vault: load/save (age), add/rm/rename/import/export, TOTP ~240 lines (incl. tests)
│   └── dashboard.rs   Interactive menu: copy, live, add, More… submenu          ~160 lines
└── spec/              this report
```

There are three files because there are three concerns:

- *`vault.rs`* holds the data and the rules. It has no prompts and does no printing, so it is easy to test.
- *`main.rs`* is the entry point. It handles login and the one-shot commands, which are thin wrappers around `Vault` methods.
- *`dashboard.rs`* is the interactive front end. It calls the *same* `Vault` methods as `main.rs`.

== The `Vault` type

Both front ends need the same three things: the file path, the password, and the decrypted entries.
`Vault` bundles them, and every method that changes something also saves:

```rust
pub struct Vault { path: PathBuf, pass: String, pub entries: Entries }

impl Vault {
    pub fn open(path, pass) -> Result<Vault>
    pub fn add(&mut self, name, username, secret) -> Result<()>      // saves
    pub fn remove(&mut self, name) -> Result<()>                      // saves
    pub fn rename(&mut self, old, new) -> Result<()>                  // saves
    pub fn set_password(&mut self, new) -> Result<()>                 // saves
    pub fn import(&mut self, raw_json) -> Result<(added, skipped)>    // saves
    pub fn export(&self) -> Result<String>
    pub fn code_for(&self, name, t) -> Result<String>
    pub fn lines(&self, filter, t) -> Result<Vec<String>>             // "CODE  NAME  USER"
}
```

There is no `Database` trait and no generics. #old had a trait with two implementations and
macro-generated code, which this app doesn't need.

== Data flow

```text
                  login(): password ──▶ Vault::open ◀── db.age
                                             │
              ┌──────────────────────────────┴───────────────────────┐
              ▼                                                      ▼
   otpdash <command>  (main.rs)                          otpdash  (dashboard.rs)
   one Vault call, then exit                     loop { draw; menu; Vault call }
              │                                                      │
              └───────────────▶ mutating calls ─▶ save ◀─────────────┘
                                  encrypt ─▶ db.tmp ─rename─▶ db.age
```

== Dashboard loop

```text
loop:
  clear screen, print header + codes + status line
  choice = Select(main menu)            Esc / Ctrl-C here ⇒ quit
  result = run action(choice)           actions return Result<String> (status message)
  status = Ok(msg)          ⇒ msg
           Err(cancelled)   ⇒ ""        Esc inside an action ⇒ back to menu
           Err(e)           ⇒ "Error: …" errors are shown, never fatal
```

*Live codes* uses a background thread that waits for Enter and sends a message over a channel.
Meanwhile the main thread redraws every second and checks for that message with `recv_timeout(1s)`.
This only needs the standard library: no raw terminal mode and no extra crate.

== Dependencies

#table(
  columns: (auto, auto, 1fr),
  [*Crate*], [*Ver*], [*Why*],
  [`clap` (derive)], [4], [The standard CLI parser. Subcommands are defined as an `enum`.],
  [`inquire`], [0.9], [Menus (`Select`, which you can filter by typing), `Text`, `Confirm` and `Password`. It draws on stderr.],
  [`age`], [0.10], [Authenticated passphrase encryption. Files can also be read with the `age` CLI.],
  [`anyhow`], [1], [One error type. Use `?` everywhere and `.context("…")` for readable messages.],
  [`totp-lite`], [2], [The RFC 6238 maths.],
  [`base32`], [0.5], [Decodes secrets.],
  [`serde` + `serde_json`], [1], [JSON for both the DB contents and the export files.],
  [`dirs`], [5], [Gives the platform's config directory.],
)

The clipboard uses OS tools (`pbcopy`, `wl-copy`, `xclip`) through `std::process::Command`, so no crate is needed.

#note[Pinned to `age = "0.10"`, because 0.11 changed the API. Upgrade once everything works (stretch goal).]

== Error strategy

- Everything returns `anyhow::Result<T>`. Library errors convert automatically with `?`.
- `.context("wrong password")` and similar calls turn cryptic errors into readable ones.
- *One-shot commands*: an error ends the program with `Error: …` and exit code 1.
- *Dashboard*: an error becomes the status line, and the loop continues.
- To tell "user pressed Esc" apart from a real error, `anyhow::Error::downcast_ref::<InquireError>()` checks what the error originally was.
