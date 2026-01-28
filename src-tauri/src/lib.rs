mod commands;
mod context_window;
mod providers;
mod scheduler;
mod state;
mod tray;

use std::sync::Arc;
use tokio::sync::RwLock;

use tauri::Manager;
use tauri_plugin_store::StoreExt;

use providers::ccusage::CcusageProvider;
use providers::types::UsageSummary;
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
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            // When a second instance is launched, show the existing window
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }))
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::get_usage,
            commands::refresh_usage,
        ])
        .setup(|app| {
            // Step 1: Hide dock icon — menu-bar-only app
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Step 2: Apply macOS vibrancy (frosted glass)
            #[cfg(target_os = "macos")]
            {
                use window_vibrancy::{
                    apply_vibrancy, NSVisualEffectMaterial, NSVisualEffectState,
                };
                let window = app.get_webview_window("main").unwrap();
                let _ = apply_vibrancy(
                    &window,
                    NSVisualEffectMaterial::Popover,
                    Some(NSVisualEffectState::Active),
                    Some(10.0),
                );
            }

            // Step 4: Click outside → hide window
            if let Some(window) = app.get_webview_window("main") {
                let w = window.clone();
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        let _ = w.hide();
                    }
                });
            }

            // Step 5: Load cached data from store on startup
            if let Ok(store) = app.store("data.json") {
                if let Some(val) = store.get("last_summary") {
                    if let Ok(summary) = serde_json::from_value::<UsageSummary>(val.clone()) {
                        let state = app.state::<AppState>();
                        *state.cached_data.blocking_write() = Some(summary);
                    }
                }
            }

            tray::setup_tray(app)?;
            scheduler::start(app.handle().clone());
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
