pub mod ccusage;
pub mod types;

use types::{DailyUsage, ProviderError};

pub trait UsageProvider: Send + Sync {
    fn name(&self) -> &str;
    fn fetch_daily(&self, since: &str, until: &str) -> Result<Vec<DailyUsage>, ProviderError>;
}
