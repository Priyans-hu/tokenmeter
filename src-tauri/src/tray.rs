use tauri::{
    image::Image,
    menu::{MenuBuilder, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, PhysicalPosition,
};
use tauri_plugin_opener::OpenerExt;

const TRAY_ICON: &[u8] = include_bytes!("../icons/32x32.png");

pub fn setup_tray(app: &mut tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    let refresh = MenuItem::with_id(app, "refresh", "Refresh Now", true, None::<&str>)?;
    let dashboard = MenuItem::with_id(app, "dashboard", "Usage Dashboard", true, None::<&str>)?;
    let updates = MenuItem::with_id(app, "updates", "Check for Updates", true, None::<&str>)?;
    let settings = MenuItem::with_id(app, "settings", "Settings", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit TokenMeter", true, None::<&str>)?;

    let menu = MenuBuilder::new(app)
        .item(&refresh)
        .item(&dashboard)
        .separator()
        .item(&updates)
        .item(&settings)
        .separator()
        .item(&quit)
        .build()?;

    let _tray = TrayIconBuilder::with_id("main-tray")
        .icon(Image::from_bytes(TRAY_ICON)?)
        .icon_as_template(true)
        .menu(&menu)
        .show_menu_on_left_click(false)
        .tooltip("TokenMeter")
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                rect,
                ..
            } = event
            {
                let app = tray.app_handle();
                let (px, py) = match rect.position {
                    tauri::Position::Physical(p) => (p.x as f64, p.y as f64),
                    tauri::Position::Logical(p) => (p.x, p.y),
                };
                let (sw, sh) = match rect.size {
                    tauri::Size::Physical(s) => (s.width as f64, s.height as f64),
                    tauri::Size::Logical(s) => (s.width, s.height),
                };
                let tray_pos = PhysicalPosition::new(
                    px + sw / 2.0,
                    py + sh,
                );
                toggle_window(app, tray_pos);
            }
        })
        .on_menu_event(|app, event| match event.id().as_ref() {
            "quit" => app.exit(0),
            "refresh" => {
                let _ = app.emit("trigger-refresh", ());
            }
            "dashboard" => {
                let _ = app
                    .opener()
                    .open_url("https://console.anthropic.com/settings/usage", None::<&str>);
            }
            "updates" => {
                let _ = app.emit("check-for-updates", ());
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            }
            "settings" => {
                let _ = app.emit("show-settings", ());
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            }
            _ => {}
        })
        .build(app)?;

    Ok(())
}

fn toggle_window(app: &AppHandle, tray_center_bottom: PhysicalPosition<f64>) {
    if let Some(window) = app.get_webview_window("main") {
        if window.is_visible().unwrap_or(false) {
            let _ = window.hide();
        } else {
            position_window_near_tray(&window, tray_center_bottom);
            let _ = window.show();
            let _ = window.set_focus();
        }
    }
}

fn position_window_near_tray(
    window: &tauri::WebviewWindow,
    tray_center_bottom: PhysicalPosition<f64>,
) {
    let win_w = 360.0;
    // Center the window horizontally on the tray icon
    let x = tray_center_bottom.x - (win_w / 2.0);
    let y = tray_center_bottom.y + 4.0; // small gap below tray

    // Clamp to screen bounds
    if let Ok(Some(monitor)) = window.current_monitor() {
        let screen_w = monitor.size().width as f64;
        let clamped_x = x.max(8.0).min(screen_w - win_w - 8.0);
        let _ = window.set_position(tauri::PhysicalPosition::new(
            clamped_x as i32,
            y as i32,
        ));
    } else {
        let _ = window.set_position(tauri::PhysicalPosition::new(x as i32, y as i32));
    }
}
