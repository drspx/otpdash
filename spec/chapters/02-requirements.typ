#import "../template.typ": *

= Requirements

== Session

+ `otpdash` with no arguments asks for the password, then opens the *dashboard*.
+ The password is asked for *once* per session. Everything after that uses the decrypted vault in memory.
+ Every change (add, remove, rename, import, change password) is *saved immediately*. If you quit or press Ctrl-C at any point, nothing is lost.
+ *First run* (no DB file): ask for a *new* password, entered twice. A typo here would lock you out.
+ A *wrong password* prints `Error: wrong password` and exits with code 1. It never panics, and nothing is written.

== Dashboard

Each time the menu appears, the screen is cleared and redrawn:

```text
otpdash · codes valid for 17s           ← header, seconds left in this 30 s window

  492039  github  me@example.com     ← CODE  NAME (padded)  USERNAME, sorted by name
  817364  google

Copied code for 'github', valid 17s.  ← status line: result of the last action

? Action:                             ← arrow keys + Enter; typing filters
```

*Main menu* (frequent actions):

#table(
  columns: (auto, 1fr),
  [*Copy a code*], [Pick an entry (type to filter), and its current code goes to the clipboard. Uses `pbcopy`, `wl-copy` or `xclip`, whichever exists.],
  [*Live codes*], [Redraw the codes every second until you press Enter.],
  [*Add*], [Ask for the name, an optional username, and the secret (masked input). Validate the secret, then save.],
  [*More…*], [Open the submenu below.],
  [*Quit*], [Exit. Esc or Ctrl-C on the main menu also quits.],
)

*More… submenu* (rare actions):

#table(
  columns: (auto, 1fr),
  [*Remove*], [Pick an entry, confirm (the default answer is *No*), then remove it.],
  [*Rename*], [Pick an entry, then type the new name, which starts filled with the old one. Error if the new name already exists.],
  [*Import*], [Ask for a file path. Import an otpdash or #old export and skip names that already exist. Report how many were added and how many skipped.],
  [*Export*], [Ask for a file path (default `otpdash-export.json`) and warn that the file is plaintext (default *No*). Write the file with mode `0600` and never overwrite an existing file.],
  [*Change password*], [Ask for the new password twice, then re-encrypt.],
  [*Back*], [Return to the main menu.],
)

*Errors and cancelling inside the dashboard:* Esc in any sub-prompt goes back to the main menu with no message.
Other errors, such as a duplicate name or a bad secret, appear in the status line, and the dashboard stays open.

== One-shot commands (for scripts)

#table(
  columns: (auto, 1fr),
  [*Command*], [*Behaviour*],
  [`otpdash show [FILTER]`], [Print `CODE  NAME  USERNAME` lines to stdout, filtered case-insensitively. Print `(Ns left)` to stderr.],
  [`otpdash add NAME [USERNAME]`], [Prompt for the secret. It is never passed as an argument.],
  [`otpdash rm NAME`], [Remove an entry, with no confirmation (it's a script command).],
  [`otpdash rename OLD NEW`], [Rename an entry.],
  [`otpdash import FILE`], [Same as the dashboard's Import.],
  [`otpdash export`], [Print the export JSON to stdout, e.g. `otpdash export > backup.json`.],
  [`otpdash passwd`], [Change the password.],
)

Prompts are drawn on *stderr* (inquire does this by default), so stdout only ever carries data.
Exit code: `0` on success, `1` on error.

== Paths

#table(
  columns: (auto, 1fr),
  [*Default DB*], [`dirs::config_dir()/otpdash/db.age`
    - macOS: `~/Library/Application Support/otpdash/db.age`
    - Linux: `$XDG_CONFIG_HOME/otpdash/db.age` (falls back to `~/.config/otpdash/db.age`)],
  [*Override*], [The env var `OTPDASH_DB=/some/path.age` changes the DB path. Tests and experiments use it.],
  [*#old*], [`~/.rustotpony/totp.safe` is never read or written.],
)

== Acceptance checklist

+ [ ] `cargo install --path .` installs `otpdash`, and `totp` still works.
+ [ ] The first run asks for a new password twice.
+ [ ] `otpdash` opens the dashboard after a single password prompt, and every action works without asking for the password again.
+ [ ] Copy a code: pasting it elsewhere gives the 6 digits.
+ [ ] Live codes counts down, rolls over at 30 s, and Enter goes back.
+ [ ] Add with an invalid secret shows an error in the status line, and the dashboard stays open.
+ [ ] Esc inside any action returns to the menu.
+ [ ] Remove asks for confirmation, and the default answer is No.
+ [ ] Exporting and then importing into an empty DB (`OTPDASH_DB=/tmp/x.age`) gives the same entries.
+ [ ] Importing a `totp export` file works, and running it again adds nothing.
+ [ ] A wrong password gives a clean error. After Change password, only the new password works.
+ [ ] `otpdash show git | cat` prints only code lines.
+ [ ] `cargo test` and `cargo clippy` are both clean.
