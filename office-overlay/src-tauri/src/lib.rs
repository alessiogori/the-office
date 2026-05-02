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
    if let Ok(env_path) = std::env::var("OFFICE_STATUS_FILE") {
        return PathBuf::from(env_path);
    }
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Ok(cwd) = std::env::current_dir() {
        for hops in 0..5 {
            let mut p = cwd.clone();
            for _ in 0..hops {
                p.pop();
            }
            p.push("shared-context");
            p.push("AGENT-STATUS.json");
            candidates.push(p);
        }
    }
    for c in &candidates {
        if c.exists() {
            return c.clone();
        }
    }
    candidates.into_iter().next().unwrap_or_default()
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
            eprintln!("[overlay] watching status file: {}", path.display());
            let watch_dir = path
                .parent()
                .map(|p| p.to_path_buf())
                .unwrap_or_else(|| PathBuf::from("."));
            eprintln!("[overlay] watching dir: {}", watch_dir.display());

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
                            let hit = event.paths.iter().any(|p| {
                                p == &target
                                    || p.file_name() == target.file_name()
                            });
                            if hit {
                                eprintln!("[overlay] file event: {:?}", event.kind);
                                if let Some(s) = read_status(&target) {
                                    eprintln!("[overlay] emit agent-status ({} agents)", s.len());
                                    let _ = handle.emit("agent-status", s);
                                } else {
                                    eprintln!("[overlay] read_status returned None");
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
