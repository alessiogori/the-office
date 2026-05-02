use notify::{Event, EventKind, RecursiveMode, Watcher};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::{BufRead, BufReader, Seek, SeekFrom};
use std::path::PathBuf;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;
use tauri::{AppHandle, Emitter};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AgentState {
    status: String,
    task: String,
    ts: String,
}

type StatusMap = HashMap<String, AgentState>;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct MsgEvent {
    #[serde(default)]
    from: String,
    #[serde(default)]
    to: String,
    #[serde(default)]
    msg: String,
    #[serde(default)]
    ts: String,
}

fn shared_dir() -> PathBuf {
    if let Ok(env_path) = std::env::var("OFFICE_SHARED_DIR") {
        return PathBuf::from(env_path);
    }
    if let Ok(cwd) = std::env::current_dir() {
        for hops in 0..5 {
            let mut p = cwd.clone();
            for _ in 0..hops {
                p.pop();
            }
            p.push("shared-context");
            if p.exists() {
                return p;
            }
        }
    }
    PathBuf::from("shared-context")
}

fn status_file_path() -> PathBuf {
    if let Ok(env_path) = std::env::var("OFFICE_STATUS_FILE") {
        return PathBuf::from(env_path);
    }
    shared_dir().join("AGENT-STATUS.json")
}

fn msg_log_path() -> PathBuf {
    if let Ok(env_path) = std::env::var("OFFICE_MSG_LOG") {
        return PathBuf::from(env_path);
    }
    shared_dir().join("MSG-LOG.jsonl")
}

fn read_status(path: &PathBuf) -> Option<StatusMap> {
    let raw = fs::read_to_string(path).ok()?;
    serde_json::from_str(&raw).ok()
}

#[tauri::command]
fn get_status() -> Option<StatusMap> {
    read_status(&status_file_path())
}

fn spawn_status_watcher(handle: AppHandle, dir: PathBuf, target: PathBuf) {
    if let Some(initial) = read_status(&target) {
        let _ = handle.emit("agent-status", initial);
    }
    thread::spawn(move || {
        let (tx, rx) = mpsc::channel::<notify::Result<Event>>();
        let mut watcher = match notify::recommended_watcher(tx) {
            Ok(w) => w,
            Err(e) => { eprintln!("status watcher init: {e}"); return; }
        };
        if let Err(e) = watcher.watch(&dir, RecursiveMode::NonRecursive) {
            eprintln!("status watch start: {e}"); return;
        }
        loop {
            match rx.recv_timeout(Duration::from_secs(60)) {
                Ok(Ok(event)) => {
                    let hit = event.paths.iter().any(|p| {
                        p == &target || p.file_name() == target.file_name()
                    });
                    if hit {
                        if let Some(s) = read_status(&target) {
                            let _ = handle.emit("agent-status", s);
                        }
                    }
                }
                Ok(Err(e)) => eprintln!("status watch err: {e}"),
                Err(mpsc::RecvTimeoutError::Timeout) => continue,
                Err(_) => break,
            }
        }
    });
}

fn spawn_msg_watcher(handle: AppHandle, dir: PathBuf, target: PathBuf) {
    thread::spawn(move || {
        let mut last_pos: u64 = match fs::metadata(&target) {
            Ok(m) => m.len(),
            Err(_) => 0,
        };
        let (tx, rx) = mpsc::channel::<notify::Result<Event>>();
        let mut watcher = match notify::recommended_watcher(tx) {
            Ok(w) => w,
            Err(e) => { eprintln!("msg watcher init: {e}"); return; }
        };
        if let Err(e) = watcher.watch(&dir, RecursiveMode::NonRecursive) {
            eprintln!("msg watch start: {e}"); return;
        }
        loop {
            match rx.recv_timeout(Duration::from_secs(60)) {
                Ok(Ok(event)) => {
                    let hit = event.paths.iter().any(|p| {
                        p == &target || p.file_name() == target.file_name()
                    });
                    if !hit { continue; }
                    if matches!(event.kind, EventKind::Remove(_)) {
                        last_pos = 0;
                        continue;
                    }
                    let len = match fs::metadata(&target) {
                        Ok(m) => m.len(),
                        Err(_) => continue,
                    };
                    if len < last_pos { last_pos = 0; }
                    if len == last_pos { continue; }
                    let mut f = match fs::File::open(&target) {
                        Ok(f) => f,
                        Err(_) => continue,
                    };
                    if f.seek(SeekFrom::Start(last_pos)).is_err() { continue; }
                    let reader = BufReader::new(&mut f);
                    for line in reader.lines().flatten() {
                        if line.trim().is_empty() { continue; }
                        if let Ok(ev) = serde_json::from_str::<MsgEvent>(&line) {
                            let _ = handle.emit("agent-msg", ev);
                        }
                    }
                    last_pos = len;
                }
                Ok(Err(e)) => eprintln!("msg watch err: {e}"),
                Err(mpsc::RecvTimeoutError::Timeout) => continue,
                Err(_) => break,
            }
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .invoke_handler(tauri::generate_handler![get_status])
        .setup(|app| {
            let dir = shared_dir();
            let status_path = status_file_path();
            let msg_path = msg_log_path();
            eprintln!("[overlay] shared dir: {}", dir.display());
            eprintln!("[overlay] status file: {}", status_path.display());
            eprintln!("[overlay] msg log: {}", msg_path.display());

            spawn_status_watcher(app.handle().clone(), dir.clone(), status_path);
            spawn_msg_watcher(app.handle().clone(), dir, msg_path);
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
