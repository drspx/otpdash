use crate::vault::{Vault, now, seconds_left};
use anyhow::{Result, bail};
use crossterm::{
    ExecutableCommand,
    cursor::MoveTo,
    terminal::{Clear, ClearType},
};
use inquire::{Confirm, InquireError, Select, Text};
use std::io::{Write, stdout};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::time::Duration;

const COPY: &str = "Copy a code";
const LIVE: &str = "Live codes";
const ADD: &str = "Add";
const MORE: &str = "More…";
const QUIT: &str = "Quit";

const REMOVE: &str = "Remove";
const RENAME: &str = "Rename";
const IMPORT: &str = "Import";
const EXPORT: &str = "Export";
const PASSWD: &str = "Change password";
const BACK: &str = "Back";

fn clear_screen() {
    stdout().execute(Clear(ClearType::All)).unwrap();
    stdout().execute(Clear(ClearType::Purge)).unwrap();
    stdout().execute(MoveTo(0, 0)).unwrap();
}

pub fn run(v: &mut Vault) -> Result<()> {
    let mut status = String::new();
    loop {
        draw(v, &status)?;
        let choice = match Select::new("Action:", vec![COPY, LIVE, ADD, MORE, QUIT])
            .with_vim_mode(true)
            .prompt()
        {
            Ok(c) => c,
            Err(InquireError::OperationCanceled | InquireError::OperationInterrupted) => {
                clear_screen();
                return Ok(());
            }
            Err(e) => return Err(e.into()),
        };
        let result = match choice {
            COPY => copy_code(v),
            LIVE => live(v),
            ADD => add(v),
            MORE => more(v),
            _ => {
                return {
                    clear_screen();
                    Ok(())
                };
            }
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
    clear_screen();
    println!("otpdash · codes valid for {}s\n", seconds_left(t));
    if v.entries.is_empty() {
        println!("  (no entries: use Add, or More… → Import)");
    }
    for line in v.lines("", t)? {
        println!("  {line}");
    }
    println!("\n{status}");
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

fn live(v: &Vault) -> Result<String> {
    // A thread waits for Enter while the main thread redraws once per second.
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let _ = std::io::stdin().read_line(&mut String::new());
        let _ = tx.send(());
    });
    loop {
        draw(v, "Live. Press Enter to go back.")?;
        if rx.recv_timeout(Duration::from_secs(1)).is_ok() {
            return Ok(String::new());
        }
    }
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
