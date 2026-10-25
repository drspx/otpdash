#import "../template.typ": *

= Naming

The chosen name is *#app*. The alternatives that were considered were free on crates.io and not used by any command on this machine
as of 2026-10-25:

#table(
  columns: (auto, 1fr),
  [*Name*], [*Vibe*],
  [`otpdash`], [OTP dashboard: says what it is. *Chosen.*],
  [`otpz`], [Four letters, quick to type.],
  [`mintotp`], ["Minimal TOTP".],
  [`otpvault`], [Matches the `Vault` type.],
  [`twofer`], [Two-factor, playful.],
  [`lilotp`], [Little OTP.],
  [`otpony`], [OTP + pony. Keeps the 🐴 heritage.],
  [`ponyotp`], [Same idea as `otpony`, but reads less smoothly.],
  [`twofa`], [Says exactly what it does.],
  [`sixdig`], [Six digits. A bit playful.],
  [`keyp`], [Short, sounds like "keep".],
  [`codez`], [Tongue in cheek.],
)

Not usable: `totp` (RusTOTPony's binary), and `kodo`, `tok`, `tik`, `tock`, `hexa`, `otpcli`, `tokn`, `sixer` (already taken on crates.io).

== How to rename

+ Change `#let app = "…"` in `spec/template.typ`.
+ In the code: `name` in `Cargo.toml`, the config subdirectory and the env var in `db_path()` (`OTPDASH_DB`).
+ Rename the folder `~/personal_code/otpdash`.

Check that the new name is free: `curl -s -o /dev/null -w '%{http_code}' https://crates.io/api/v1/crates/NAME`
(`404` = free) and `command -v NAME` (no output = free).
