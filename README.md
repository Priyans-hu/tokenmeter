# TokenMeter

macOS menu bar app for visualizing Claude Code token usage and costs. Built with SwiftUI.

Parses Claude Code's local conversation data to show real-time usage stats — no API keys or external tools needed.

![macOS](https://img.shields.io/badge/macOS_14+-000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?logo=swift&logoColor=white)

## Features

- **Menu bar app** — lives in menu bar, no dock icon, works in fullscreen
- **Native macOS** — built with SwiftUI and Swift Charts
- **Rate limit tracking** — 5-hour session and weekly output token usage with plan-based limits
- **Cost summary** — today / this week / this month (calculated with embedded pricing)
- **Daily cost chart** — bar chart with 7/14/30 day range
- **Model breakdown** — donut chart showing per-model usage (Opus, Sonnet, Haiku)
- **Plan selection** — Pro / Max 5x / Max 20x for estimated rate limits
- **Auto-refresh** — every 5 minutes (configurable)
- **Zero dependencies** — parses `~/.claude/` JSONL files directly, no external tools required

## Installation

### Quick Install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Priyans-hu/tokenmeter/main/install.sh | bash
```

Downloads the latest release, extracts to `/Applications`, and removes quarantine.

### Homebrew

```bash
brew install Priyans-hu/tap/tokenmeter
```

### Manual Download

1. Download `TokenMeter-v*.zip` from [Releases](https://github.com/Priyans-hu/tokenmeter/releases/latest)
2. Extract and move `TokenMeter.app` to `/Applications`
3. Right-click → Open on first launch (to bypass Gatekeeper)

### Build from Source

```bash
git clone https://github.com/Priyans-hu/tokenmeter.git
cd tokenmeter/TokenMeter
swift build -c release
```

Then copy the binary into the app bundle:

```bash
cp .build/release/TokenMeter /Applications/TokenMeter.app/Contents/MacOS/TokenMeter
```

### Prerequisites

- macOS 14 (Sonoma) or later
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and used (generates the local data TokenMeter reads)

## How It Works

TokenMeter reads Claude Code's local JSONL files from `~/.claude/projects/`:

1. **Daily usage** — scans all conversation JSONL files, groups by date, calculates token costs using embedded model pricing
2. **Rate limits** — tracks output tokens in the last 5 hours (session) and 7 days (weekly), shows progress against estimated plan limits
3. **Model breakdown** — identifies which models (Opus, Sonnet, Haiku) are being used and their relative costs

No API keys, no external tools, no cloud services. Everything is local.

### Pricing

Costs are calculated using Anthropic's published API-equivalent pricing (per million tokens):

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Opus 4.5 | $15.00 | $75.00 | $18.75 | $1.50 |
| Sonnet 4.5 | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku 4.5 | $0.80 | $4.00 | $1.00 | $0.08 |

> Note: These are API-equivalent costs for reference. Claude Code subscription users pay a flat monthly fee.

## Architecture

```
TokenMeter/
├── TokenMeterApp.swift              # App entry with MenuBarExtra
├── UsageViewModel.swift             # State management, timer, caching
├── Models/
│   └── UsageSummary.swift           # Data models + ClaudePlan enum
├── Services/
│   ├── NativeUsageParser.swift      # JSONL parser + pricing engine
│   └── UpdateChecker.swift          # GitHub releases checker
└── Views/
    ├── DashboardView.swift          # Main popover container
    ├── RateLimitView.swift          # Progress bar with plan limits
    ├── CostSummaryView.swift        # Today/week/month cost cards
    ├── DailyChartView.swift         # Swift Charts bar chart
    ├── ModelBreakdownView.swift     # Swift Charts donut chart
    └── SettingsView.swift           # Plan picker, refresh interval
```

```
Data Flow:
  ~/.claude/projects/*.jsonl  ──>  NativeUsageParser  ──>  DailyUsage + RateLimits
                                        │
  Timer (5min)  ──>  UsageViewModel  ──>  UsageSummary  ──>  SwiftUI Views
                          │
                          └──>  UserDefaults cache (instant reopen)
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
