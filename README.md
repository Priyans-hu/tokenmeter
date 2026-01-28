# TokenMeter

macOS menu bar app for visualizing Claude Code token usage and costs. Built with Tauri v2 (Rust + vanilla JS).

Parses Claude Code's local conversation data to show real-time usage stats — no API keys needed.

![macOS](https://img.shields.io/badge/macOS-000?logo=apple&logoColor=white)
![Tauri](https://img.shields.io/badge/Tauri_v2-FFC131?logo=tauri&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-000?logo=rust&logoColor=white)

## Features

- **System tray app** — lives in menu bar, no dock icon
- **Native macOS vibrancy** — frosted glass popover appearance
- **Context window tracker** — 5-hour sliding window with token count, active sessions, and reset timer
- **Cost summary** — today / this week / this month
- **Daily cost chart** — bar chart with 7/14/30 day range
- **Model breakdown** — donut chart showing per-model usage (Opus, Sonnet, Haiku)
- **Auto-refresh** — every 5 minutes (configurable)
- **Click outside to close** — native popover behavior
- **Single instance** — prevents duplicate app launches
- **Instant reopen** — cached data persists across restarts

## How It Works

TokenMeter reads Claude Code's local data from two sources:

1. **[ccusage](https://github.com/yucchiy/ccusage)** — for daily cost and token aggregates
2. **`~/.claude/projects/` JSONL files** — for 5-hour context window tracking (parses `message.usage` from conversation logs)

No API keys or cloud services required. Everything is local.

## Prerequisites

- macOS (Apple Silicon or Intel)
- [Rust](https://rustup.rs/)
- Node.js
- [ccusage](https://github.com/yucchiy/ccusage): `npm install -g ccusage`
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and used (for local data)

## Development

```bash
npm install
npm run tauri dev
```

## Build

```bash
npm run tauri build -- --bundles app
```

Output: `src-tauri/target/release/bundle/macos/TokenMeter.app`

Move to `/Applications` for permanent use.

## Architecture

```
Data Sources:
  ccusage CLI --json  ──>  CcusageProvider  ──>  Daily cost/tokens
  ~/.claude/projects/  ──>  context_window   ──>  5h token tracking

Pipeline:
  Scheduler (5min)  ──>  UsageSummary cache  ──>  Tauri event  ──>  Frontend
                         |
                         └──>  Persisted to store (instant reopen)

UI:
  System Tray  ──>  Click  ──>  Popover (positioned below icon)
                                 ├── Stats cards (today/week/month)
                                 ├── Context window (5h progress bar)
                                 ├── Daily cost chart
                                 ├── Model breakdown donut
                                 └── Settings
```

### Provider Trait

Extensible provider architecture for adding other AI services:

```rust
pub trait UsageProvider: Send + Sync {
    fn name(&self) -> &str;
    fn fetch_daily(&self, since: &str, until: &str) -> Result<Vec<DailyUsage>, ProviderError>;
}
```

Add new providers in `src-tauri/src/providers/`.

## Project Structure

```
tokenmeter/
├── src/                          # Frontend (vanilla JS)
│   ├── index.html
│   ├── main.js
│   └── styles.css
├── src-tauri/                    # Rust backend
│   ├── src/
│   │   ├── lib.rs                # App entry, vibrancy, single-instance
│   │   ├── tray.rs               # System tray, window positioning
│   │   ├── scheduler.rs          # Auto-refresh loop
│   │   ├── commands.rs           # Tauri IPC commands
│   │   ├── state.rs              # App state (cached data)
│   │   ├── context_window.rs     # 5h context window parser
│   │   └── providers/
│   │       ├── mod.rs            # UsageProvider trait
│   │       ├── types.rs          # Data types
│   │       └── ccusage.rs        # ccusage CLI provider
│   ├── icons/
│   ├── Cargo.toml
│   └── tauri.conf.json
└── package.json
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
