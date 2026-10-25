#import "../template.typ": *

= Overview

== What we're building

#app is a small TOTP manager for the terminal. You log in once with your password and land on a
*dashboard*: your current codes, with a short menu underneath.

```text
$ otpdash
? Password: ********

otpdash · codes valid for 17s

  492039  github  me@example.com
  817364  google
  103385  aws     admin

? Action:
> Copy a code
  Live codes
  Add
  More…            → Remove, Rename, Import, Export, Change password
  Quit
```

The things you do every day are on the main menu. The rarely used ones are under *More…*.
For scripts, every action is also a one-shot command:

```bash
otpdash show git          # print matching codes and exit
otpdash export > backup.json
```

== Goals

- *Log in once.* Run `otpdash` and you get a dashboard you can keep using until you quit.
- *Small.* About 500 lines in three files, which you write yourself.
- *Imports #old.* It reads the JSON from `totp export`, and its own exports use the same format.
- *Coexists with #old.* It has a different binary name and a different data path, and never touches `~/.rustotpony`.
- *Safe storage.* It uses age encryption, so a wrong password gives a clean error and saves are atomic.
- *Teaches Rust.* Each step introduces a few concepts, with notes alongside.

== Non-goals (YAGNI)

#table(
  columns: (auto, 1fr, 1fr),
  [*Skipped*], [*Why*], [*Add when*],
  [Full-screen TUI (ratatui)], [Menu plus live view covers the need with a fraction of the code], [You want mouse support, panes, or everything on one screen.],
  [OS keyring], [Platform-specific code], [Typing the password gets old.],
  [Auto-lock after idle], [It's a terminal you can close], [You leave the dashboard open on shared machines.],
  [HOTP / SHA-256 / 8 digits], [Almost every service uses TOTP-SHA1 with 6 digits], [A service needs it.],
  [QR code scanning], [Services also show the base32 text], [Never, probably.],
  [Windows], [Export uses Unix file permissions], [You need it. Wrap that one line in `#[cfg(unix)]`.],
)

== How to read this report

#table(
  columns: (auto, 1fr),
  [Ch. 2–4], [*Spec.* What the app does, its file formats and code layout. An agent or a person can build from these alone.],
  [Ch. 5], [*Build guide.* Eleven steps, each with verified code, Rust notes and a "Your turn" box.],
  [Ch. 6–8], [Testing, moving over from #old, and security.],
  [Ch. 9], [*Vibe coding.* Instructions for a coding agent, plus one prompt per step.],
  [Ch. 10], [Naming.],
  [Ch. 11], [The full reference source, checked with `cargo test` and `cargo clippy`.],
)
