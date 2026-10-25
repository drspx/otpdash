#import "../template.typ": *

= Moving over from #old

Both tools can stay installed. They have different binaries (`totp` and `otpdash`) and different data files.

#table(
  columns: (auto, 1fr, 1fr),
  [], [*#old*], [*#app*],
  [Binary], [`totp`], [`otpdash`],
  [Data], [`~/.rustotpony/totp.safe`], [`<config_dir>/otpdash/db.age`],
  [Crypto], [AES-256-CBC, key = SHA-256(password), no authentication], [age (scrypt + ChaCha20-Poly1305)],
  [Wrong password], [Panic or garbage], [`Error: wrong password`],
)

== Runbook

```bash
cargo install --path .                 # installs ~/.cargo/bin/otpdash

umask 077                              # export file readable only by you
totp export > /tmp/old.json            # enter the RusTOTPony password
otpdash import /tmp/old.json              # first run: choose a NEW password
rm -P /tmp/old.json                    # macOS: overwrite and delete (Linux: shred -u)

otpdash                                   # dashboard: compare a few codes with `totp`
```

#warn[`totp export` prints *every secret in plaintext*. Keep the file in `/tmp`, never in a synced or
git-tracked folder, and delete it right after the import.]

== Retiring #old (when you're confident)

+ Use #app on its own for a week or two.
+ Back up the old DB somewhere offline: `~/.rustotpony/totp.safe`.
+ Run `cargo uninstall rustotpony` (or remove the AUR package).
