use notify::{Event, RecursiveMode, Watcher};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;
use tauri::{Emitter, Manager};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AgentState {
    status: String,
    task: String,
    ts: String,
}

type StatusMap = HashMap<String, AgentState>;

fn status_file_path() -> PathBuf {
    let mut p = std::env::current_dir().unwrap_or_default();
    p.pop();
    p.push("shared-context");
    p.push("AGENT-STATUS.json");
    p
}

fn read_status(path: &PathBuf) -> Option<StatusMap> {
    let raw = fs::read_to_string(path).ok()?;
    serde_json::from_str(&raw).ok()
}

#[tauri::command]
fn get_status() -> Option<StatusMap> {
    read_status(&status_file_path())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![get_status])
        .setup(|app| {
            let handle = app.handle().clone();
            let path = status_file_path();
            let watch_dir = path.parent().unwrap().to_path_buf();

            if let Some(initial) = read_status(&path) {
                let _ = handle.emit("agent-status", initial);
            }

            thread::spawn(move || {
                let (tx, rx) = mpsc::channel::<notify::Result<Event>>();
                let mut watcher = match notify::recommended_watcher(tx) {
                    Ok(w) => w,
                    Err(e) => {
                        eprintln!("watcher init: {e}");
                        return;
                    }
                };
                if let Err(e) = watcher.watch(&watch_dir, RecursiveMode::NonRecursive) {
                    eprintln!("watch start: {e}");
                    return;
                }
                let target = path.clone();
                loop {
                    match rx.recv_timeout(Duration::from_secs(60)) {
                        Ok(Ok(event)) => {
                            if event.paths.iter().any(|p| p == &target) {
                                if let Some(s) = read_status(&target) {
                                    let _ = handle.emit("agent-status", s);
                                }
                            }
                        }
                        Ok(Err(e)) => eprintln!("watch err: {e}"),
                        Err(mpsc::RecvTimeoutError::Timeout) => continue,
                        Err(_) => break,
                    }
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
