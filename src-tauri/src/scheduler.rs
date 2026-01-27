use std::time::Duration;

use chrono::{Datelike, Local, NaiveDate};
use tauri::{AppHandle, Emitter, Manager};

use crate::providers::types::{ProviderError, UsageSummary};
use crate::state::AppState;

const REFRESH_INTERVAL_SECS: u64 = 300; // 5 minutes
const FETCH_DAYS: i64 = 30;

pub fn start(app: AppHandle) {
    tauri::async_runtime::spawn(async move {
        // Initial fetch on startup
        refresh_and_emit(&app).await;

        loop {
            tokio::time::sleep(Duration::from_secs(REFRESH_INTERVAL_SECS)).await;
            refresh_and_emit(&app).await;
        }
    });
}

async fn refresh_and_emit(app: &AppHandle) {
    let state = app.state::<AppState>();
    match do_refresh(&state).await {
        Ok(summary) => {
            let _ = app.emit("usage-updated", &summary);
        }
        Err(e) => {
            let _ = app.emit("usage-error", e);
        }
    }
}

pub async fn do_refresh(state: &AppState) -> Result<UsageSummary, String> {
    let provider = state.provider.clone();

    let summary = tokio::task::spawn_blocking(move || build_summary(&*provider))
        .await
        .map_err(|e| format!("Task join error: {}", e))?
        .map_err(|e| e.to_string())?;

    *state.cached_data.write().await = Some(summary.clone());
    Ok(summary)
}

fn build_summary(
    provider: &dyn crate::providers::UsageProvider,
) -> Result<UsageSummary, ProviderError> {
    let now = Local::now().naive_local().date();
    let since = now - chrono::Duration::days(FETCH_DAYS);

    let since_str = since.format("%Y%m%d").to_string();
    let until_str = now.format("%Y%m%d").to_string();

    let daily = provider.fetch_daily(&since_str, &until_str)?;

    let today_str = now.format("%Y-%m-%d").to_string();
    let today_data = daily.iter().find(|d| d.date == today_str);

    let today_cost = today_data.map(|d| d.total_cost).unwrap_or(0.0);
    let today_tokens = today_data.map(|d| d.total_tokens).unwrap_or(0);
    let today_model_breakdowns = today_data
        .map(|d| d.model_breakdowns.clone())
        .unwrap_or_default();

    // Week cost: sum of last 7 days
    let week_start = now - chrono::Duration::days(6);
    let week_cost: f64 = daily
        .iter()
        .filter(|d| {
            NaiveDate::parse_from_str(&d.date, "%Y-%m-%d")
                .map(|date| date >= week_start)
                .unwrap_or(false)
        })
        .map(|d| d.total_cost)
        .sum();

    // Month cost: sum of current month
    let month_start = now.with_day(1).unwrap_or(now);
    let month_cost: f64 = daily
        .iter()
        .filter(|d| {
            NaiveDate::parse_from_str(&d.date, "%Y-%m-%d")
                .map(|date| date >= month_start)
                .unwrap_or(false)
        })
        .map(|d| d.total_cost)
        .sum();

    let last_updated = Local::now().format("%Y-%m-%dT%H:%M:%S").to_string();

    Ok(UsageSummary {
        daily,
        today_cost,
        week_cost,
        month_cost,
        today_tokens,
        today_model_breakdowns,
        last_updated,
    })
}
