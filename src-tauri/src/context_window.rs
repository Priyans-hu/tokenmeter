use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

use chrono::{DateTime, Duration as ChronoDuration, Utc};
use serde::{Deserialize, Serialize};

const WINDOW_HOURS: i64 = 5;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContextWindowInfo {
    pub tokens_used: u64,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_creation_tokens: u64,
    pub sessions_active: u32,
    pub oldest_message_time: Option<String>,
    pub resets_at: Option<String>,
    pub minutes_until_reset: Option<u32>,
    pub window_hours: u32,
}

#[derive(Deserialize)]
struct JournalEntry {
    #[serde(rename = "type")]
    entry_type: Option<String>,
    timestamp: Option<String>,
    message: Option<MessageData>,
    #[serde(rename = "sessionId")]
    session_id: Option<String>,
}

#[derive(Deserialize)]
struct MessageData {
    usage: Option<UsageData>,
}

#[derive(Deserialize)]
struct UsageData {
    input_tokens: Option<u64>,
    output_tokens: Option<u64>,
    cache_read_input_tokens: Option<u64>,
    cache_creation_input_tokens: Option<u64>,
}

pub fn compute() -> ContextWindowInfo {
    let cutoff = Utc::now() - ChronoDuration::hours(WINDOW_HOURS);

    let claude_dir = match std::env::var("HOME") {
        Ok(home) => PathBuf::from(home).join(".claude").join("projects"),
        Err(_) => return empty_info(),
    };

    if !claude_dir.exists() {
        return empty_info();
    }

    let mut total_input = 0u64;
    let mut total_output = 0u64;
    let mut total_cache_read = 0u64;
    let mut total_cache_creation = 0u64;
    let mut oldest_ts: Option<DateTime<Utc>> = None;
    let mut active_sessions: HashSet<String> = HashSet::new();

    if let Ok(projects) = fs::read_dir(&claude_dir) {
        for project in projects.flatten() {
            if !project.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                continue;
            }

            scan_directory(
                &project.path(),
                &cutoff,
                &mut total_input,
                &mut total_output,
                &mut total_cache_read,
                &mut total_cache_creation,
                &mut oldest_ts,
                &mut active_sessions,
            );

            let subagents = project.path().join("subagents");
            if subagents.exists() {
                scan_directory(
                    &subagents,
                    &cutoff,
                    &mut total_input,
                    &mut total_output,
                    &mut total_cache_read,
                    &mut total_cache_creation,
                    &mut oldest_ts,
                    &mut active_sessions,
                );
            }
        }
    }

    let tokens_used = total_input + total_output;

    let (resets_at, minutes_until_reset) = if let Some(oldest) = oldest_ts {
        let reset_time = oldest + ChronoDuration::hours(WINDOW_HOURS);
        let now = Utc::now();
        let minutes = if reset_time > now {
            (reset_time - now).num_minutes() as u32
        } else {
            0
        };
        (Some(reset_time.to_rfc3339()), Some(minutes))
    } else {
        (None, None)
    };

    ContextWindowInfo {
        tokens_used,
        input_tokens: total_input,
        output_tokens: total_output,
        cache_read_tokens: total_cache_read,
        cache_creation_tokens: total_cache_creation,
        sessions_active: active_sessions.len() as u32,
        oldest_message_time: oldest_ts.map(|t| t.to_rfc3339()),
        resets_at,
        minutes_until_reset,
        window_hours: WINDOW_HOURS as u32,
    }
}

fn scan_directory(
    dir: &Path,
    cutoff: &DateTime<Utc>,
    total_input: &mut u64,
    total_output: &mut u64,
    total_cache_read: &mut u64,
    total_cache_creation: &mut u64,
    oldest_ts: &mut Option<DateTime<Utc>>,
    active_sessions: &mut HashSet<String>,
) {
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().map(|e| e == "jsonl").unwrap_or(false) {
            // Skip files not modified in last 5 hours
            if let Ok(metadata) = path.metadata() {
                if let Ok(modified) = metadata.modified() {
                    let threshold = SystemTime::now() - Duration::from_secs(5 * 3600);
                    if modified < threshold {
                        continue;
                    }
                }
            }

            process_jsonl(
                &path,
                cutoff,
                total_input,
                total_output,
                total_cache_read,
                total_cache_creation,
                oldest_ts,
                active_sessions,
            );
        }
    }
}

fn process_jsonl(
    path: &Path,
    cutoff: &DateTime<Utc>,
    total_input: &mut u64,
    total_output: &mut u64,
    total_cache_read: &mut u64,
    total_cache_creation: &mut u64,
    oldest_ts: &mut Option<DateTime<Utc>>,
    active_sessions: &mut HashSet<String>,
) {
    let content = match fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return,
    };

    for line in content.lines() {
        let entry: JournalEntry = match serde_json::from_str(line) {
            Ok(e) => e,
            Err(_) => continue,
        };

        if entry.entry_type.as_deref() != Some("assistant") {
            continue;
        }

        let ts = match entry
            .timestamp
            .as_deref()
            .and_then(|t| t.parse::<DateTime<Utc>>().ok())
        {
            Some(t) => t,
            None => continue,
        };

        if ts < *cutoff {
            continue;
        }

        if let Some(message) = &entry.message {
            if let Some(usage) = &message.usage {
                let input = usage.input_tokens.unwrap_or(0);
                let output = usage.output_tokens.unwrap_or(0);
                let cache_read = usage.cache_read_input_tokens.unwrap_or(0);
                let cache_creation = usage.cache_creation_input_tokens.unwrap_or(0);

                *total_input += input;
                *total_output += output;
                *total_cache_read += cache_read;
                *total_cache_creation += cache_creation;

                match oldest_ts {
                    Some(ref existing) if ts < *existing => *oldest_ts = Some(ts),
                    None => *oldest_ts = Some(ts),
                    _ => {}
                }

                if let Some(session_id) = &entry.session_id {
                    active_sessions.insert(session_id.clone());
                }
            }
        }
    }
}

fn empty_info() -> ContextWindowInfo {
    ContextWindowInfo {
        tokens_used: 0,
        input_tokens: 0,
        output_tokens: 0,
        cache_read_tokens: 0,
        cache_creation_tokens: 0,
        sessions_active: 0,
        oldest_message_time: None,
        resets_at: None,
        minutes_until_reset: None,
        window_hours: WINDOW_HOURS as u32,
    }
}
