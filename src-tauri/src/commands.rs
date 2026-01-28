use serde::{Deserialize, Serialize};
use tauri::State;

use crate::providers::types::UsageSummary;
use crate::state::AppState;

#[tauri::command]
pub async fn get_usage(state: State<'_, AppState>) -> Result<UsageSummary, String> {
    state
        .cached_data
        .read()
        .await
        .clone()
        .ok_or_else(|| "Data not loaded yet. Refreshing...".to_string())
}

#[tauri::command]
pub async fn refresh_usage(state: State<'_, AppState>) -> Result<UsageSummary, String> {
    crate::scheduler::do_refresh(&state).await
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateInfo {
    pub version: String,
    pub url: String,
    pub notes: String,
}

#[derive(Deserialize)]
struct GithubRelease {
    tag_name: String,
    html_url: String,
    body: Option<String>,
}

#[tauri::command]
pub async fn check_for_updates() -> Result<Option<UpdateInfo>, String> {
    let current = env!("CARGO_PKG_VERSION");

    let client = reqwest::Client::builder()
        .user_agent("TokenMeter")
        .build()
        .map_err(|e| e.to_string())?;

    let release: GithubRelease = client
        .get("https://api.github.com/repos/Priyans-hu/tokenmeter/releases/latest")
        .send()
        .await
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;

    let latest = release.tag_name.trim_start_matches('v');

    if version_newer(latest, current) {
        Ok(Some(UpdateInfo {
            version: release.tag_name,
            url: release.html_url,
            notes: release.body.unwrap_or_default(),
        }))
    } else {
        Ok(None)
    }
}

fn version_newer(latest: &str, current: &str) -> bool {
    let parse = |v: &str| -> Vec<u32> {
        v.split('.')
            .filter_map(|s| s.parse().ok())
            .collect()
    };
    let l = parse(latest);
    let c = parse(current);
    l > c
}
