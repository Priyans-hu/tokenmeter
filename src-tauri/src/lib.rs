mod commands;
mod providers;
mod scheduler;
mod state;
mod tray;

use std::sync::Arc;
use tokio::sync::RwLock;

use providers::ccusage::CcusageProvider;
use state::AppState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let provider = Arc::new(CcusageProvider::new()) as Arc<dyn providers::UsageProvider>;

    let app_state = AppState {
        cached_data: Arc::new(RwLock::new(None)),
        provider,
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_notification::init())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::get_usage,
            commands::refresh_usage,
        ])
        .setup(|app| {
            tray::setup_tray(app)?;
            scheduler::start(app.handle().clone());
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
