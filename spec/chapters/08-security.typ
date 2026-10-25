#import "../template.typ": *

= Security notes

Not a full threat model, just the decisions and their limits.

#table(
  columns: (auto, 1fr),
  [*Decision*], [*Reason / limit*],
  [age passphrase encryption], [scrypt makes guessing passwords slow, and Poly1305 detects tampering and wrong passwords. This is the main improvement over #old.],
  [Secrets are prompted, never passed as arguments], [Command-line arguments end up in shell history and are visible to other users through `ps`.],
  [Write to a tmp file, then rename], [A crash can't leave a half-written DB. A stale `db.tmp` might be left behind, but it is encrypted too.],
  [Codes on stdout, everything else on stderr], [`otpdash show git | cat` gets only code lines; the dashboard copies a single code to the clipboard.],
  [No `unsafe`, few dependencies], [Less code you have to trust.],
  [Password stays in memory for the session], [This is what lets you log in only once. Quit the dashboard when you walk away.],
  [Export: confirm (default No), mode `0600`, never overwrite], [A plaintext export is the most dangerous file this app creates.],
  [Clipboard], [A copied code stays on the clipboard. That's harmless, because it expires within 30 s.],
)

== Known ceilings (acceptable for a personal tool)

- *Secrets in memory.* Plain `String`s aren't wiped when they're dropped. Upgrade path: the `zeroize` / `secrecy` crates.
- *Password strength.* Nothing is enforced. Choose a long passphrase.
- *Backups.* There are none. Copy `db.age` to your backup location; it's safe to store because it's encrypted.
- *File mode.* It follows your umask, which is usually 0644. The file is encrypted, but 0600 is tidier (stretch goal).
