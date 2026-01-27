use tauri::State;

use crate::state::AppState;
use crate::providers::types::UsageSummary;

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
