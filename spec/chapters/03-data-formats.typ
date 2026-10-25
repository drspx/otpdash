#import "../template.typ": *

= Data formats

== Export / import format

#app reads *and writes* one format: the shape of #old's export. As a result,
`totp export` files and `otpdash export` files import the same way, and a round trip loses nothing.
#app writes the same structure without `secret_bytes`, using the name as the map key.

`totp export` prints `serde_json::to_string_pretty(&HashMap<String, GenApp>)`:

```json
{
  "github": {
    "name": "github",
    "secret": "JBSWY3DPEHPK3PXP",
    "username": "me",
    "secret_bytes": [72, 101, 108, 108, 111, 33, 222, 173, 190, 239]
  }
}
```

#table(
  columns: (auto, 1fr),
  [*Field*], [*Use in #app*],
  [map key], [*Ignored.* #old's `rename` updates `name` but leaves the key unchanged, so the key can be out of date.],
  [`name`], [Becomes the entry name.],
  [`secret`], [The base32 TOTP secret. It is normalised (§3.3) and checked before it is stored.],
  [`username`], [Kept. It is optional (`#[serde(default)]`).],
  [`secret_bytes`], [*Ignored.* It is just the decoded secret, so we compute it when needed. Serde skips unknown fields by default.],
)

#warn[*The file may start with junk.* #old's password prompt (promkit) writes terminal
escape codes to stdout, so `totp export > old.json` produces something like
`ESC[?25l…ESC[1E{ "github": … }`. The importer skips everything before the first `{`.]

#warn[The export is *plaintext*. It contains all your secrets. Delete it right after you import it (chapter 7).]

== Storage: `db.age`

An #link("https://age-encryption.org")[age] file, encrypted with a passphrase (scrypt). Inside is compact JSON:

```json
{"github":{"secret":"JBSWY3DPEHPK3PXP","username":"me"},
 "google":{"secret":"…","username":""}}
```

In Rust this is `BTreeMap<String, Entry>`:
- *The key is the name.* Nothing else stores the name, so it can't get out of sync the way #old's rename did.
- `BTreeMap` iterates in sorted key order, so `show` comes out sorted without any extra code.

Because this is standard age, you can always get your data back without #app:
```bash
age -d "~/Library/Application Support/otpdash/db.age"   # brew install age
```

== Secret normalisation

Services print secrets in many forms: `jbsw y3dp ehpk 3pxp`, `JBSWY3DPEHPK3PXP====`.
Before storing a secret, #app removes whitespace and `=` padding and converts it to uppercase. Decoding then uses
RFC 4648 base32 *without* padding.

== The TOTP algorithm (RFC 6238)

$ "code" = "HOTP"("key", floor(t / 30)) mod 10^6 $

`totp-lite` implements this, so it takes one call:

```rust
totp_lite::totp_custom::<totp_lite::Sha1>(30, 6, &key_bytes, unix_seconds)
```

The seconds left in the current window are `30 - t % 30`. The RFC test vector (appendix B) is
used as a unit test: the ASCII key `12345678901234567890` (base32 `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`) at
$t = 59$ gives `94287082`, and the last 6 digits are `287082`.
