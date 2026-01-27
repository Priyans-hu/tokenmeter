use std::sync::Arc;
use tokio::sync::RwLock;

use crate::providers::types::UsageSummary;
use crate::providers::UsageProvider;

pub struct AppState {
    pub cached_data: Arc<RwLock<Option<UsageSummary>>>,
    pub provider: Arc<dyn UsageProvider>,
}
