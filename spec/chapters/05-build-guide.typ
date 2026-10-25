#import "../template.typ": *

#let V = "/reference/src/vault.rs"
#let M = "/reference/src/main.rs"
#let D = "/reference/src/dashboard.rs"

= Build guide

Eleven steps. Each one ends with code that compiles, so commit after every step.

*How to use this chapter:* read the goal and the "Your turn" box, then *try to write the step yourself*.
Look at the code only once you have something, or once you're stuck. All code here is pulled from the
tested reference files (chapter 11), so it is known to work.

== Step 1: Create the project

```bash
cd ~/personal_code/otpdash            # spec/ already lives here
cargo init --name otpdash
cargo add clap --features derive
cargo add serde --features derive
cargo add age@0.10 anyhow base32 dirs inquire serde_json totp-lite
git init && git add . && git commit -m "chore: scaffold"
```

#note[`cargo add` edits `Cargo.toml` for you. Commit `Cargo.lock`: for a binary, it pins the exact
versions you tested with.]

== Step 2: The CLI skeleton

#task[Define the `Cli` struct and the `Cmd` enum with clap. Make `main` print which command it got,
and use `todo!()` for everything else. Try `cargo run -- --help` and `cargo run -- rename a b`.]

#snippet(M, "/// Minimal TOTP manager", until: "fn main()")

#note[
  - `#[derive(Parser)]` is a *procedural macro*: it generates the argument parser at compile time.
    The `///` doc comments become the `--help` text.
  - Enum variants can carry data (`Rename { old, new }`). `match` *destructures* them into variables.
  - `Option<Cmd>` makes the subcommand optional. `None` will mean "open the dashboard".
  - `todo!()` compiles but panics if it runs. It's a handy placeholder.
]

== Step 3: `vault.rs`, the data types and path

Create `src/vault.rs`, and add `mod vault;` at the top of `main.rs`.

#snippet(V, "#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]", until: "/// One value")
#snippet(V, "pub fn db_path()", until: "pub fn now()")

#note[
  - `mod vault;` loads `src/vault.rs`. Items are *private by default*, so `main.rs` can only use things marked `pub`.
  - `pub type` is an alias, not a new type.
  - `#[serde(default)]` means a missing `username` becomes `""` instead of causing an error.
  - `p.into()` converts `OsString` to `PathBuf` through the `From`/`Into` traits. The return type tells the compiler which conversion to use.
]

== Step 4: Save (encrypt, then write atomically)

#snippet(V, "fn save(path", until: "#[cfg(test)]")

#note[
  - *`?`*: if the value is `Err`, return it from the function. Otherwise unwrap the `Ok` value. `anyhow` accepts any error type.
  - `&Path` / `&str` / `&Entries` are *shared borrows*: `save` only reads them.
  - `&mut encrypted` is an *exclusive borrow*: while `writer` is alive, nothing else can touch `encrypted`.
  - `rename` is atomic. If the program crashes, you have either the old file or the new one, never half of one.
]

== Step 5: Load (a missing file means an empty DB)

#snippet(V, "fn load(path", until: "fn save(path")

#task[Temporarily, in `main`: save one hard-coded entry, load it back and print it with `{:?}`.
Then load it with a wrong password and read the error.]

#note[
  - *Match guards*: `Err(e) if …` only matches when the condition holds.
  - `bail!(…)` is shorthand for `return Err(anyhow!(…))`.
  - `.context(…)` replaces a cryptic error with your message. `with_context(|| …)` builds the message only when there is an error; the `|| …` is a *closure*.
  - `&data[..]` is a *slice* of the whole `Vec`.
]

== Step 6: The `Vault` struct

#task[Write a `Vault` struct that holds the path, password and entries. Give it `open`, a private `save`, and
`add`, `remove`, `rename` and `set_password`, each of which saves when it's done.]

#snippet(V, "/// The decrypted database", until: "/// Returns (imported")

#note[
  - `impl Vault { … }` attaches *methods*. `&self` reads, and `&mut self` can change the struct.
  - `Self` is shorthand for the type being implemented (`Vault`).
  - `Self { path, pass, entries }` uses *field init shorthand*, because the variable names match the field names.
  - `rename` = `remove` + `insert`. Because the name only exists as the map key, there is no second copy of it to update.
  - `path` and `pass` are private. Outside code can't change them without going through methods that save.
]

== Step 7: TOTP and the code list

#snippet(V, "pub fn now()", until: "fn load(path")
#snippet(V, "pub fn code_for", until: "pub fn db_path()")

#note[
  - `.chars().filter(…).collect::<String>()` is an *iterator chain*. `::<String>` (the *turbofish*) tells `collect` which type to build.
  - In `lines`, each `map` produces a `Result<String>`. Collecting an iterator of `Result`s *into* `Result<Vec<_>>`
    gives you the first error, or a `Vec` of everything if there were none.
  - `{name:<w$}` left-aligns `name`, padded to the width held in the variable `w`.
]

#task[Write the `rfc6238_vector` test from chapter 6 now, before you trust any code it prints.]

== Step 8: `main`, login and the one-shot commands

#snippet(M, "fn main()")

#note[
  - `if path.exists() { … } else { … }` is an *expression*: whichever branch runs produces the value of `pass`.
  - Each `match` arm returns `Result<()>`, so several arms are a single call such as `v.remove(&name)`.
  - `filter.as_deref()` turns `Option<String>` into `Option<&str>`, borrowing instead of moving.
  - `inquire::Password` asks for confirmation by default. Use `.without_confirmation()` for the login prompt.
  - If `main` returns `Err`, Rust prints `Error: …` and exits with code 1.
]

#task[Try `add`, `show`, `rename`, `rm` and `passwd` with `OTPDASH_DB=/tmp/t.age cargo run -- …`.]

== Step 9: Import and export

#snippet(V, "/// One value in an export file", until: "/// The decrypted database")
#snippet(V, "/// Returns (imported", until: "pub fn code_for")

#note[
  - `&raw[i..]` is a *string slice* starting at byte `i`. Nothing is copied.
  - `into_values()` *consumes* the map, so `app.name` can be moved into `entries` without a clone.
  - Serde ignores unknown fields such as `secret_bytes` by default.
  - `let (mut added, mut skipped) = (0, 0);` destructures a tuple into two variables.
  - `export` builds a `BTreeMap<&String, Portable>`: the keys *borrow* from `self.entries`, while the values are new.
]

== Step 10: The dashboard loop

Create `src/dashboard.rs` and add `mod dashboard;` to `main.rs`. Then wire up `None => dashboard::run(&mut v)`.

#snippet(D, "const COPY", until: "fn more(")
#snippet(D, "fn cancelled(")

#note[
  - `const` defines compile-time constants. Matching on them keeps the menu labels in one place.
  - A `match` can produce a value: `status = match result { … }` assigns whichever arm runs.
  - `Err(InquireError::OperationCanceled | InquireError::OperationInterrupted)` is an *or-pattern*.
  - `downcast_ref::<T>()` checks whether an `anyhow::Error` started out as a `T`.
  - `matches!(value, pattern)` returns `true` when the value fits the pattern.
]

== Step 11: Dashboard actions

=== Drawing, picking and adding
#snippet(D, "fn draw(", until: "fn copy_code(")

=== Copy to clipboard
#snippet(D, "fn copy_code(", until: "fn live(")

#note[`Command::new("pbcopy").stdin(Stdio::piped()).spawn()` starts a child process with a pipe connected to its
stdin. `.take()` moves the pipe out of the `Option`. When the pipe is dropped it closes, and `pbcopy` sees end of input.
`[&[&str]; 3]` is an array of three slices that can have different lengths.]

=== Live codes
#snippet(D, "fn live(", until: "fn export(")

#note[`mpsc::channel()` gives a sender and a receiver. `move ||` moves `tx` into the thread.
`recv_timeout` waits up to 1 s for a message, so the same call acts as the "sleep a second" and
the "check whether Enter was pressed".]

=== The More… submenu and export
#snippet(D, "fn more(", until: "fn draw(")
#snippet(D, "fn export(", until: "fn cancelled(")

#note[`use std::os::unix::fs::OpenOptionsExt;` is an *extension trait*: importing it adds the `.mode()` method to
`OpenOptions`. It only exists on Unix, which is why the app doesn't build on Windows as written.]

#task[Go through the acceptance checklist in chapter 2.]

== Stretch goals <stretch>

+ *Auto-lock*: quit the dashboard if no key is pressed for 5 minutes.
+ *Retry on a wrong password*: three attempts, then exit.
+ *File mode 0600 on `db.age`*: reuse `OpenOptionsExt` in `save`.
+ *Upgrade to age 0.11*: follow the compiler errors and keep the tests green.
+ *Windows*: put `#[cfg(unix)]` on the `.mode()` line.
