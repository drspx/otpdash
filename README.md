# otpdash

Minimal terminal TOTP manager. Secrets live in a password-encrypted [age](https://age-encryption.org) file.

## Install

Download a binary from [Releases](https://github.com/drspx/otpdash/releases), or:

```sh
cargo install --git https://github.com/drspx/otpdash
```

## Usage

Run `otpdash` with no arguments to open the live dashboard. Codes refresh every second.

| Key | Action |
|-----|--------|
| `c` | copy a code to the clipboard |
| `a` | add a generator |
| `m` | more: remove, rename, import, export, change password |
| `q` / `Esc` | quit |

Commands:

```sh
otpdash show [FILTER]        # print codes
otpdash add NAME [USERNAME]  # secret is prompted, never an argument
otpdash rm NAME
otpdash rename OLD NEW
otpdash import FILE          # otpdash or RusTOTPony export
otpdash export               # plaintext JSON, handle with care
otpdash passwd
otpdash --version
```

The vault is stored at `<config dir>/otpdash/db.age`. Override the location with `OTPDASH_DB=/path/to/db.age`.

## Release

Push a tag like `v1.2.3`. CI builds Linux and macOS binaries and stamps that version into them. You don't need to edit `Cargo.toml`.
