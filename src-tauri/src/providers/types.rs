use serde::{Deserialize, Serialize};

use crate::context_window::ContextWindowInfo;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyUsage {
    pub date: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_creation_tokens: u64,
    pub cache_read_tokens: u64,
    pub total_tokens: u64,
    pub total_cost: f64,
    pub models_used: Vec<String>,
    pub model_breakdowns: Vec<ModelBreakdown>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelBreakdown {
    pub model_name: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_creation_tokens: u64,
    pub cache_read_tokens: u64,
    pub cost: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageSummary {
    pub daily: Vec<DailyUsage>,
    pub today_cost: f64,
    pub week_cost: f64,
    pub month_cost: f64,
    pub today_tokens: u64,
    pub today_model_breakdowns: Vec<ModelBreakdown>,
    pub context_window: ContextWindowInfo,
    pub last_updated: String,
}

#[derive(Debug, Clone)]
pub enum ProviderError {
    BinaryNotFound(String),
    ExecutionFailed(String),
    ParseError(String),
}

impl std::fmt::Display for ProviderError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ProviderError::BinaryNotFound(msg) => write!(f, "Binary not found: {}", msg),
            ProviderError::ExecutionFailed(msg) => write!(f, "Execution failed: {}", msg),
            ProviderError::ParseError(msg) => write!(f, "Parse error: {}", msg),
        }
    }
}

impl std::error::Error for ProviderError {}
