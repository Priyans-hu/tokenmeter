# TokenMeter

macOS menu bar app for visualizing AI token usage and costs. Built with Tauri v2 (Rust + vanilla JS).

Currently supports Claude Code via [ccusage](https://github.com/yucchiy/ccusage). Extensible provider architecture for adding other AI services.

## Features

- System tray icon with popover dashboard
- Today / week / month cost summary
- Daily cost bar chart (7/14/30 days)
- Model breakdown donut chart (Opus, Sonnet, Haiku)
- Budget alerts with color-coded progress bar
- Auto-refresh every 5 minutes (configurable)
- Settings: budget thresholds, refresh interval, chart range

## Prerequisites

- [Rust](https://rustup.rs/)
- Node.js (for ccusage)
- [ccusage](https://github.com/yucchiy/ccusage): `npm install -g ccusage`

## Development

```bash
npm install
npm run tauri dev
```

## Build

```bash
npm run tauri build
```

Output: `src-tauri/target/release/bundle/macos/TokenMeter.app`

## Architecture

```
ccusage CLI --json  -->  CcusageProvider (Rust)  -->  Scheduler (5min)
                                                      |
                                                      v
                                               UsageSummary cache
                                                      |
                                                      v
                                              Frontend (vanilla JS)
                                              Charts, cards, settings
```

### Provider Trait

```rust
pub trait UsageProvider: Send + Sync {
    fn name(&self) -> &str;
    fn fetch_daily(&self, since: &str, until: &str) -> Result<Vec<DailyUsage>, ProviderError>;
}
```

Add new providers in `src-tauri/src/providers/`.
