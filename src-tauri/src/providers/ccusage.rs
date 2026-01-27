use std::process::Command;

use super::types::{DailyUsage, ProviderError};
use super::UsageProvider;

pub struct CcusageProvider {
    bin_path: Option<String>,
}

impl CcusageProvider {
    pub fn new() -> Self {
        let bin_path = Self::resolve_binary().ok();
        if let Some(ref path) = bin_path {
            eprintln!("CcusageProvider: found ccusage at {}", path);
        } else {
            eprintln!("CcusageProvider: ccusage not found, will retry on fetch");
        }
        Self { bin_path }
    }

    fn get_bin_path(&self) -> Result<String, ProviderError> {
        if let Some(ref path) = self.bin_path {
            Ok(path.clone())
        } else {
            Self::resolve_binary()
        }
    }

    fn resolve_binary() -> Result<String, ProviderError> {
        // Search common NVM paths first (most reliable for bundled apps)
        let home = std::env::var("HOME").unwrap_or_default();
        let nvm_base = format!("{}/.nvm/versions/node", home);
        if let Ok(entries) = std::fs::read_dir(&nvm_base) {
            for entry in entries.flatten() {
                let candidate = entry.path().join("bin/ccusage");
                if candidate.exists() {
                    return Ok(candidate.to_string_lossy().to_string());
                }
            }
        }

        // Try `which ccusage`
        if let Ok(path) = which::which("ccusage") {
            return Ok(path.to_string_lossy().to_string());
        }

        // Try common global paths
        for path in &["/usr/local/bin/ccusage", "/opt/homebrew/bin/ccusage"] {
            if std::path::Path::new(path).exists() {
                return Ok(path.to_string());
            }
        }

        Err(ProviderError::BinaryNotFound(
            "ccusage not found. Install with: npm install -g ccusage".to_string(),
        ))
    }

    fn run_command(&self, args: &[&str]) -> Result<serde_json::Value, ProviderError> {
        let bin = self.get_bin_path()?;
        let output = Command::new(&bin)
            .args(args)
            .env("PATH", Self::build_path())
            .output()
            .map_err(|e| ProviderError::ExecutionFailed(e.to_string()))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(ProviderError::ExecutionFailed(format!(
                "ccusage exited with {}: {}",
                output.status, stderr
            )));
        }

        let stdout = String::from_utf8(output.stdout)
            .map_err(|e| ProviderError::ParseError(e.to_string()))?;

        serde_json::from_str(&stdout)
            .map_err(|e| ProviderError::ParseError(format!("JSON parse error: {}", e)))
    }

    fn build_path() -> String {
        let home = std::env::var("HOME").unwrap_or_default();
        let existing = std::env::var("PATH").unwrap_or_default();
        format!(
            "{home}/.nvm/versions/node/v20.20.0/bin:{home}/.cargo/bin:/usr/local/bin:/opt/homebrew/bin:{existing}"
        )
    }
}

impl UsageProvider for CcusageProvider {
    fn name(&self) -> &str {
        "claude-code"
    }

    fn fetch_daily(&self, since: &str, until: &str) -> Result<Vec<DailyUsage>, ProviderError> {
        let json = self.run_command(&["daily", "--json", "--since", since, "--until", until])?;

        let daily_arr = json
            .get("daily")
            .ok_or_else(|| ProviderError::ParseError("missing 'daily' key in response".into()))?;

        let daily: Vec<DailyUsage> = serde_json::from_value(daily_arr.clone())
            .map_err(|e| ProviderError::ParseError(format!("Failed to parse daily data: {}", e)))?;

        Ok(daily)
    }
}
