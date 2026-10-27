mod dashboard;
mod vault;

use anyhow::Result;
use clap::{Parser, Subcommand};
use inquire::{Password, PasswordDisplayMode};
use std::path::PathBuf;
use vault::Vault;

const VERSION: &str = match option_env!("OTPDASH_VERSION") {
    Some(v) => v,
    None => env!("CARGO_PKG_VERSION"),
};

/// Minimal TOTP manager. Run without a command to open the dashboard.
#[derive(Parser)]
#[command(version = VERSION)]
struct Cli {
    #[command(subcommand)]
    cmd: Option<Cmd>,
}

#[derive(Subcommand)]
enum Cmd {
    /// Print codes (only names containing FILTER, if given)
    Show { filter: Option<String> },
    /// Add a generator; the secret is prompted, never passed as an argument
    Add {
        name: String,
        #[arg(default_value = "")]
        username: String,
    },
    /// Remove a generator
    Rm { name: String },
    /// Rename a generator
    Rename { old: String, new: String },
    /// Import an otpdash or RusTOTPony export file
    Import { file: PathBuf },
    /// Print all generators as plaintext JSON
    Export,
    /// Change the database password
    Passwd,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let mut v = login()?;
    match cli.cmd {
        None => dashboard::run(&mut v),
        Some(Cmd::Show { filter }) => {
            let t = vault::now();
            for line in v.lines(filter.as_deref().unwrap_or(""), t)? {
                println!("{line}");
            }
            eprintln!("({}s left)", vault::seconds_left(t));
            Ok(())
        }
        Some(Cmd::Add { name, username }) => v.add(&name, &username, &prompt_secret()?),
        Some(Cmd::Rm { name }) => v.remove(&name),
        Some(Cmd::Rename { old, new }) => v.rename(&old, &new),
        Some(Cmd::Import { file }) => {
            let (added, skipped) = v.import(&std::fs::read_to_string(&file)?)?;
            eprintln!(
                "Imported {added}, skipped {skipped} existing. Now delete {}",
                file.display()
            );
            Ok(())
        }
        Some(Cmd::Export) => {
            print!("{}", v.export()?);
            Ok(())
        }
        Some(Cmd::Passwd) => v.set_password(new_password()?),
    }
}

fn login() -> Result<Vault> {
    let path = vault::db_path();
    let pass = if path.exists() {
        Password::new("Password:").without_confirmation().prompt()?
    } else {
        eprintln!("No database at {}, creating one.", path.display());
        new_password()?
    };
    Vault::open(path, pass)
}

fn new_password() -> Result<String> {
    Ok(Password::new("New password:")
        .with_custom_confirmation_message("Repeat:")
        .with_validator(inquire::required!("password must not be empty"))
        .prompt()?)
}

/// Runs `f` while a spinner animates on stderr (age's scrypt takes ~1 s by design).
fn spin<T>(msg: &str, f: impl FnOnce() -> T) -> T {
    use std::io::IsTerminal;
    use std::sync::atomic::{AtomicBool, Ordering};
    if !std::io::stderr().is_terminal() {
        return f(); // piped or redirected: no animation garbage
    }
    let done = AtomicBool::new(false);
    std::thread::scope(|s| {
        s.spawn(|| {
            for c in "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏".chars().cycle() {
                if done.load(Ordering::Relaxed) {
                    break;
                }
                eprint!("\r{c} {msg}");
                std::thread::sleep(std::time::Duration::from_millis(80));
            }
            eprint!("\r\x1B[2K"); // clear the spinner line
        });
        let out = f();
        done.store(true, Ordering::Relaxed);
        out
    })
}

fn prompt_secret() -> Result<String> {
    Ok(Password::new("Secret (base32):")
        .without_confirmation()
        .with_display_mode(PasswordDisplayMode::Masked)
        .prompt()?)
}
