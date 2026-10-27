use crate::VERSION;
use crate::vault::{Vault, now, seconds_left};
use anyhow::{Result, bail};
use crossterm::event::KeyModifiers;
use crossterm::{
    cursor::MoveTo,
    event::{self, Event, KeyCode},
    execute,
    terminal::{
        Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode,
        enable_raw_mode,
    },
};
use inquire::{Confirm, InquireError, Select, Text};
use std::io::{Write, stdout};
use std::process::{Command, Stdio};
use std::time::Duration;

const REMOVE: &str = "Remove";
const RENAME: &str = "Rename";
const IMPORT: &str = "Import";
const EXPORT: &str = "Export";
const PASSWD: &str = "Change password";
const BACK: &str = "Back";

struct AltScreen;

impl AltScreen {
    fn enter() -> Result<Self> {
        execute!(stdout(), EnterAlternateScreen)?;
        Ok(AltScreen)
    }
}

impl Drop for AltScreen {
    fn drop(&mut self) {
        let _ = execute!(stdout(), LeaveAlternateScreen);
    }
}

pub fn run(v: &mut Vault) -> Result<()> {
    let _screen = AltScreen::enter()?;
    let mut status = String::new();
    loop {
        draw(v, &format!("{status}\nc copy · a add · m more · q quit"))?;
        let choice = key_within(Duration::from_secs(1))?;
        let result = match choice {
            Some(KeyCode::Char('c')) => copy_code(v),
            Some(KeyCode::Char('a')) => add(v),
            Some(KeyCode::Char('m')) => more(v),
            Some(KeyCode::Char('q') | KeyCode::Esc) => return Ok(()),
            _ => continue,
        };
        // Esc inside an action just goes back to the menu; real errors are shown, not fatal
        status = match result {
            Ok(msg) => msg,
            Err(e) if cancelled(&e) => String::new(),
            Err(e) => format!("Error: {e:#}"),
        };
    }
}

fn more(v: &mut Vault) -> Result<String> {
    match Select::new("More:", vec![REMOVE, RENAME, IMPORT, EXPORT, PASSWD, BACK])
        .with_vim_mode(true)
        .prompt()?
    {
        REMOVE => {
            let name = pick(v, "Remove which?")?;
            if !Confirm::new(&format!("Really remove '{name}'?"))
                .with_default(false)
                .prompt()?
            {
                return Ok(String::new());
            }
            v.remove(&name)?;
            Ok(format!("Removed '{name}'."))
        }
        RENAME => {
            let old = pick(v, "Rename which?")?;
            let new = Text::new("New name:").with_initial_value(&old).prompt()?;
            v.rename(&old, &new)?;
            Ok(format!("Renamed '{old}' to '{new}'."))
        }
        IMPORT => {
            let path = Text::new("Export file to import:").prompt()?;
            let (added, skipped) = v.import(&std::fs::read_to_string(&path)?)?;
            Ok(format!(
                "Imported {added}, skipped {skipped} existing. Delete {path} now."
            ))
        }
        EXPORT => export(v),
        PASSWD => {
            v.set_password(crate::new_password()?)?;
            Ok("Password changed.".into())
        }
        _ => Ok(String::new()),
    }
}

fn draw(v: &Vault, status: &str) -> Result<()> {
    let t = now();
    execute!(stdout(), Clear(ClearType::All), MoveTo(0, 0))?;
    println!("otpdash version {VERSION}");
    println!();
    println!("otpdash · codes valid for {}s\n", seconds_left(t));
    if v.entries.is_empty() {
        println!("  (no entries: use Add, or More… → Import)");
    }
    for line in v.lines("", t)? {
        println!("  {line}");
    }
    println!("\n{status}");
    stdout().flush()?;
    Ok(())
}

fn pick(v: &Vault, msg: &str) -> Result<String> {
    if v.entries.is_empty() {
        bail!("no entries yet");
    }
    Ok(Select::new(msg, v.entries.keys().cloned().collect())
        .with_vim_mode(true)
        .prompt()?)
}

fn add(v: &mut Vault) -> Result<String> {
    let name = Text::new("Name:").prompt()?;
    let username = Text::new("Username (optional):").prompt()?;
    v.add(&name, &username, &crate::prompt_secret()?)?;
    Ok(format!("Added '{name}'."))
}

fn copy_code(v: &Vault) -> Result<String> {
    let name = pick(v, "Copy which? (type to filter)")?;
    let t = now();
    copy_to_clipboard(&v.code_for(&name, t)?)?;
    Ok(format!(
        "Copied code for '{name}', valid {}s.",
        seconds_left(t)
    ))
}

// ponytail: shells out to the OS clipboard tool; switch to the `arboard` crate if this list falls short
fn copy_to_clipboard(text: &str) -> Result<()> {
    let tools: [&[&str]; 3] = [
        &["pbcopy"],
        &["wl-copy"],
        &["xclip", "-selection", "clipboard"],
    ];
    for tool in tools {
        if let Ok(mut child) = Command::new(tool[0])
            .args(&tool[1..])
            .stdin(Stdio::piped())
            .spawn()
        {
            child.stdin.take().unwrap().write_all(text.as_bytes())?;
            child.wait()?;
            return Ok(());
        }
    }
    bail!("no clipboard tool found (pbcopy, wl-copy or xclip)")
}

fn key_within(timeout: Duration) -> Result<Option<KeyCode>> {
    enable_raw_mode()?;
    let key = event::poll(timeout).and_then(|ready| {
        if ready {
            event::read().map(|e| match e {
                Event::Key(k)
                    if k.code == KeyCode::Char('c')
                        && k.modifiers.contains(KeyModifiers::CONTROL) =>
                {
                    Some(KeyCode::Esc)
                }
                Event::Key(k) => Some(k.code),
                _ => None,
            })
        } else {
            Ok(None)
        }
    });
    disable_raw_mode()?;
    Ok(key?)
}

fn export(v: &Vault) -> Result<String> {
    use std::os::unix::fs::OpenOptionsExt;
    let path = Text::new("Export to file:")
        .with_default("otpdash-export.json")
        .prompt()?;
    if !Confirm::new("The file will contain ALL secrets in plaintext. Continue?")
        .with_default(false)
        .prompt()?
    {
        return Ok(String::new());
    }
    std::fs::OpenOptions::new()
        .write(true)
        .create_new(true) // never overwrite an existing file
        .mode(0o600) // readable by you only
        .open(&path)?
        .write_all(v.export()?.as_bytes())?;
    Ok(format!(
        "Exported to {path}. Keep it safe, delete it when done."
    ))
}

fn cancelled(e: &anyhow::Error) -> bool {
    matches!(
        e.downcast_ref::<InquireError>(),
        Some(InquireError::OperationCanceled | InquireError::OperationInterrupted)
    )
}
