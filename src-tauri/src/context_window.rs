use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

use chrono::{DateTime, Duration as ChronoDuration, Utc};
use serde::{Deserialize, Serialize};

const SESSION_HOURS: i64 = 5;
const WEEKLY_HOURS: i64 = 168; // 7 days

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RateLimitInfo {
    pub session: WindowInfo,
    pub weekly: WindowInfo,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowInfo {
    pub tokens_used: u64,
    pub input_tokens: u64,
    pub output_tokens: u64,
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
}

struct WindowAccumulator {
    total_input: u64,
    total_output: u64,
    oldest_ts: Option<DateTime<Utc>>,
    active_sessions: HashSet<String>,
    window_hours: i64,
}

impl WindowAccumulator {
    fn new(window_hours: i64) -> Self {
        Self {
            total_input: 0,
            total_output: 0,
            oldest_ts: None,
            active_sessions: HashSet::new(),
            window_hours,
        }
    }

    fn into_info(self) -> WindowInfo {
        let tokens_used = self.total_input + self.total_output;
        let (resets_at, minutes_until_reset) = if let Some(oldest) = self.oldest_ts {
            let reset_time = oldest + ChronoDuration::hours(self.window_hours);
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

        WindowInfo {
            tokens_used,
            input_tokens: self.total_input,
            output_tokens: self.total_output,
            sessions_active: self.active_sessions.len() as u32,
            oldest_message_time: self.oldest_ts.map(|t| t.to_rfc3339()),
            resets_at,
            minutes_until_reset,
            window_hours: self.window_hours as u32,
        }
    }
}

pub fn compute() -> RateLimitInfo {
    let now = Utc::now();
    let session_cutoff = now - ChronoDuration::hours(SESSION_HOURS);
    let weekly_cutoff = now - ChronoDuration::hours(WEEKLY_HOURS);

    let claude_dir = match std::env::var("HOME") {
        Ok(home) => PathBuf::from(home).join(".claude").join("projects"),
        Err(_) => return empty_info(),
    };

    if !claude_dir.exists() {
        return empty_info();
    }

    let mut session = WindowAccumulator::new(SESSION_HOURS);
    let mut weekly = WindowAccumulator::new(WEEKLY_HOURS);

    if let Ok(projects) = fs::read_dir(&claude_dir) {
        for project in projects.flatten() {
            if !project.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                continue;
            }

            scan_directory(
                &project.path(),
                &session_cutoff,
                &weekly_cutoff,
                &mut session,
                &mut weekly,
            );

            let subagents = project.path().join("subagents");
            if subagents.exists() {
                scan_directory(
                    &subagents,
                    &session_cutoff,
                    &weekly_cutoff,
                    &mut session,
                    &mut weekly,
                );
            }
        }
    }

    RateLimitInfo {
        session: session.into_info(),
        weekly: weekly.into_info(),
    }
}

fn scan_directory(
    dir: &Path,
    session_cutoff: &DateTime<Utc>,
    weekly_cutoff: &DateTime<Utc>,
    session: &mut WindowAccumulator,
    weekly: &mut WindowAccumulator,
) {
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().map(|e| e == "jsonl").unwrap_or(false) {
            // Skip files not modified in last 7 days
            if let Ok(metadata) = path.metadata() {
                if let Ok(modified) = metadata.modified() {
                    let threshold =
                        SystemTime::now() - Duration::from_secs(WEEKLY_HOURS as u64 * 3600);
                    if modified < threshold {
                        continue;
                    }
                }
            }

            process_jsonl(&path, session_cutoff, weekly_cutoff, session, weekly);
        }
    }
}

fn process_jsonl(
    path: &Path,
    session_cutoff: &DateTime<Utc>,
    weekly_cutoff: &DateTime<Utc>,
    session: &mut WindowAccumulator,
    weekly: &mut WindowAccumulator,
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

        // Skip if outside the wider (weekly) window entirely
        if ts < *weekly_cutoff {
            continue;
        }

        if let Some(message) = &entry.message {
            if let Some(usage) = &message.usage {
                let input = usage.input_tokens.unwrap_or(0);
                let output = usage.output_tokens.unwrap_or(0);
                let session_id = entry.session_id.as_deref();

                // Always add to weekly
                weekly.total_input += input;
                weekly.total_output += output;
                match weekly.oldest_ts {
                    Some(existing) if ts < existing => weekly.oldest_ts = Some(ts),
                    None => weekly.oldest_ts = Some(ts),
                    _ => {}
                }
                if let Some(sid) = session_id {
                    weekly.active_sessions.insert(sid.to_string());
                }

                // Add to session if within 5h window
                if ts >= *session_cutoff {
                    session.total_input += input;
                    session.total_output += output;
                    match session.oldest_ts {
                        Some(existing) if ts < existing => session.oldest_ts = Some(ts),
                        None => session.oldest_ts = Some(ts),
                        _ => {}
                    }
                    if let Some(sid) = session_id {
                        session.active_sessions.insert(sid.to_string());
                    }
                }
            }
        }
    }
}

fn empty_info() -> RateLimitInfo {
    RateLimitInfo {
        session: WindowInfo {
            tokens_used: 0,
            input_tokens: 0,
            output_tokens: 0,
            sessions_active: 0,
            oldest_message_time: None,
            resets_at: None,
            minutes_until_reset: None,
            window_hours: SESSION_HOURS as u32,
        },
        weekly: WindowInfo {
            tokens_used: 0,
            input_tokens: 0,
            output_tokens: 0,
            sessions_active: 0,
            oldest_message_time: None,
            resets_at: None,
            minutes_until_reset: None,
            window_hours: WEEKLY_HOURS as u32,
        },
    }
}
