use age::secrecy::SecretString;
use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Entry {
    pub secret: String,
    #[serde(default)]
    pub username: String,
}

// ponytail: BTreeMap = sorted output for free; the key IS the name, so rename can't desync
pub type Entries = BTreeMap<String, Entry>;

/// One value in an export file. Same shape as RusTOTPony's `totp export`
/// (minus `secret_bytes`, which serde ignores), so both files import the same way.
#[derive(Serialize, Deserialize)]
struct Portable {
    name: String,
    secret: String,
    #[serde(default)]
    username: String,
}

/// The decrypted database plus what's needed to save it again.
/// Every mutating method saves immediately.
pub struct Vault {
    path: PathBuf,
    pass: String,
    pub entries: Entries,
}

impl Vault {
    pub fn open(path: PathBuf, pass: String) -> Result<Self> {
        let v = Self {
            entries: crate::spin("Unlocking…", || load(&path, &pass))?,
            path,
            pass,
        };
        if !v.path.exists() {
            v.save()?; // first run: create the DB now, so the next run asks for this password
        }
        Ok(v)
    }

    fn save(&self) -> Result<()> {
        crate::spin("Saving…", || save(&self.path, &self.pass, &self.entries))
    }

    pub fn add(&mut self, name: &str, username: &str, secret: &str) -> Result<()> {
        if self.entries.contains_key(name) {
            bail!("'{name}' already exists");
        }
        let secret = normalize(secret);
        code(&secret, 0)?; // fail now on bad base32, not at show time
        let username = username.to_string();
        self.entries
            .insert(name.to_string(), Entry { secret, username });
        self.save()
    }

    pub fn remove(&mut self, name: &str) -> Result<()> {
        self.entries
            .remove(name)
            .with_context(|| format!("'{name}' not found"))?;
        self.save()
    }

    pub fn rename(&mut self, old: &str, new: &str) -> Result<()> {
        if self.entries.contains_key(new) {
            bail!("'{new}' already exists");
        }
        let entry = self
            .entries
            .remove(old)
            .with_context(|| format!("'{old}' not found"))?;
        self.entries.insert(new.to_string(), entry);
        self.save()
    }

    pub fn set_username(&mut self, name: &str, username: &str) -> Result<()> {
        self.entries
            .get_mut(name)
            .with_context(|| format!("'{name}' not found"))?
            .username = username.to_string();
        self.save()
    }

    pub fn set_password(&mut self, pass: String) -> Result<()> {
        self.pass = pass;
        self.save()
    }

    /// Returns (imported, skipped because the name already exists).
    pub fn import(&mut self, raw: &str) -> Result<(usize, usize)> {
        // ponytail: RusTOTPony's prompt leaks escape codes into a redirected export; skip to the JSON
        let json = &raw[raw.find('{').context("no JSON object in file")?..];
        let apps: HashMap<String, Portable> =
            serde_json::from_str(json).context("not an otpdash/RusTOTPony export")?;
        let (mut added, mut skipped) = (0, 0);
        for app in apps.into_values() {
            // use .name, not the map key: RusTOTPony's rename leaves the key stale
            if self.entries.contains_key(&app.name) {
                skipped += 1;
                continue;
            }
            let secret = normalize(&app.secret);
            code(&secret, 0).with_context(|| format!("bad secret for '{}'", app.name))?;
            self.entries.insert(
                app.name,
                Entry {
                    secret,
                    username: app.username,
                },
            );
            added += 1;
        }
        self.save()?;
        Ok((added, skipped))
    }

    pub fn export(&self) -> Result<String> {
        let out: BTreeMap<&String, Portable> = self
            .entries
            .iter()
            .map(|(name, e)| {
                let p = Portable {
                    name: name.clone(),
                    secret: e.secret.clone(),
                    username: e.username.clone(),
                };
                (name, p)
            })
            .collect();
        Ok(serde_json::to_string_pretty(&out)? + "\n")
    }

    pub fn code_for(&self, name: &str, t: u64) -> Result<String> {
        let e = self
            .entries
            .get(name)
            .with_context(|| format!("'{name}' not found"))?;
        code(&e.secret, t)
    }

    /// `[code, name, username]` rows, filtered case-insensitively by name.
    pub fn rows(&self, filter: &str, t: u64) -> Result<Vec<[String; 3]>> {
        let f = filter.to_lowercase();
        self.entries
            .iter()
            .filter(|(name, _)| name.to_lowercase().contains(&f))
            .map(|(name, e)| Ok([code(&e.secret, t)?, name.clone(), e.username.clone()]))
            .collect()
    }

    /// `CODE  NAME  USERNAME` lines, names padded to one width.
    pub fn lines(&self, filter: &str, t: u64) -> Result<Vec<String>> {
        let w = self
            .entries
            .keys()
            .map(|k| k.chars().count())
            .max()
            .unwrap_or(0);
        Ok(self
            .rows(filter, t)?
            .into_iter()
            .map(|[c, n, u]| format!("{c}  {n:<w$}  {u}"))
            .collect())
    }
}

pub fn db_path() -> PathBuf {
    if let Some(p) = std::env::var_os("OTPDASH_DB") {
        return p.into();
    }
    dirs::config_dir()
        .expect("no config dir")
        .join("otpdash")
        .join("db.age")
}

pub fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

pub fn seconds_left(t: u64) -> u64 {
    30 - t % 30
}

fn normalize(secret: &str) -> String {
    secret
        .chars()
        .filter(|c| !c.is_whitespace() && *c != '=')
        .collect::<String>()
        .to_uppercase()
}

fn code(secret: &str, t: u64) -> Result<String> {
    let key = totp_rs::Secret::try_from_base32(secret).context("secret is not valid base32")?;
    // ponytail: build_noncompliant skips the 128-bit minimum; many services use 80-bit secrets
    let totp = totp_rs::Builder::new()
        .with_secret(key)
        .build_noncompliant(); // SHA-1, 6 digits, 30 s
    Ok(totp.generate(t).to_string())
}

fn load(path: &Path, pass: &str) -> Result<Entries> {
    let data = match std::fs::read(path) {
        Ok(d) => d,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Entries::new()),
        Err(e) => return Err(e).with_context(|| format!("reading {}", path.display())),
    };
    let decryptor = age::Decryptor::new(&data[..])?;
    if !decryptor.is_scrypt() {
        bail!("{} is not passphrase-encrypted", path.display());
    }
    let identity = age::scrypt::Identity::new(SecretString::from(pass.to_owned()));
    let mut reader = decryptor
        .decrypt(std::iter::once(&identity as &dyn age::Identity))
        .context("wrong password")?;
    let mut json = Vec::new();
    reader.read_to_end(&mut json)?;
    Ok(serde_json::from_slice(&json)?)
}

fn save(path: &Path, pass: &str, entries: &Entries) -> Result<()> {
    let json = serde_json::to_vec(entries)?;
    let mut encrypted = Vec::new();
    let mut writer = age::Encryptor::with_user_passphrase(SecretString::from(pass.to_owned()))
        .wrap_output(&mut encrypted)?;
    writer.write_all(&json)?;
    writer.finish()?;

    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    // write, fsync, rename: a crash or power cut leaves either the old file or the new one, never half
    // ponytail: the directory isn't fsynced, so a power cut right after rename can still revert to the old file
    let tmp = path.with_extension("tmp");
    let mut f = std::fs::File::create(&tmp)?;
    f.write_all(&encrypted)?;
    f.sync_all()?;
    std::fs::rename(&tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_vault(file: &str) -> Vault {
        let path = std::env::temp_dir().join(file);
        let _ = std::fs::remove_file(&path);
        Vault::open(path, "pw".into()).unwrap()
    }

    #[test]
    fn rfc6238_vector() {
        // RFC 6238 appendix B: ASCII "12345678901234567890", T=59 -> 94287082 (last 6 digits)
        assert_eq!(
            code("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 59).unwrap(),
            "287082"
        );
    }

    #[test]
    fn save_load_and_wrong_password() {
        let mut v = temp_vault("otpdash_test_a.age");
        assert!(v.path.exists(), "first open creates the DB");
        v.add("github", "me", "jbsw y3dp ehpk 3pxp").unwrap();
        v.rename("github", "gh").unwrap();
        v.set_username("gh", "you").unwrap();
        assert!(v.set_username("nope", "x").is_err());
        assert!(v.rename("nope", "x").is_err());

        let reopened = Vault::open(v.path.clone(), "pw".into()).unwrap();
        assert_eq!(reopened.entries["gh"].secret, "JBSWY3DPEHPK3PXP");
        assert_eq!(reopened.entries["gh"].username, "you");
        assert!(Vault::open(v.path.clone(), "wrong".into()).is_err());

        v.set_password("new".into()).unwrap();
        assert!(Vault::open(v.path.clone(), "new".into()).is_ok());
        std::fs::remove_file(&v.path).unwrap();
    }

    #[test]
    fn import_rustotpony_export_and_own_roundtrip() {
        let raw = "\x1b[?25l\x1b[1E{\"old-key\":{\"name\":\"github\",\"secret\":\"jbsw y3dp ehpk 3pxp\",\"username\":\"me\",\"secret_bytes\":[1]}}";
        let mut v = temp_vault("otpdash_test_b.age");
        assert_eq!(v.import(raw).unwrap(), (1, 0));
        assert_eq!(v.import(raw).unwrap(), (0, 1));

        let mut w = temp_vault("otpdash_test_c.age");
        w.import(&v.export().unwrap()).unwrap();
        assert_eq!(w.entries, v.entries);

        std::fs::remove_file(&v.path).unwrap();
        std::fs::remove_file(&w.path).unwrap();
    }
}
