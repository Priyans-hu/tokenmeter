# TokenMeter

macOS menu bar app for tracking Claude Code usage, rate limits, and costs. Built with SwiftUI.

Reads Claude Code's OAuth token from Keychain for real rate limit data, and parses local JSONL files for cost and usage analytics.

![macOS](https://img.shields.io/badge/macOS_14+-000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?logo=swift&logoColor=white)

## Features

- **Real rate limits** — fetches actual utilization from Anthropic API via Claude Code's OAuth token
- **Rate limit notifications** — macOS alerts when session or weekly usage hits 80%
- **Usage heatmap** — hour-by-day grid showing when you're most active (7/14/30 day range)
- **Hover details** — token breakdown (input/output) appears on hover over rate limit bars
- **Cost summary** — today / this week / this month (API-equivalent pricing)
- **Daily cost chart** — bar chart with 7/14/30 day range
- **Model breakdown** — donut chart showing per-model usage (Opus, Sonnet, Haiku)
- **Menu bar app** — lives in menu bar, no dock icon, works in fullscreen
- **Auto-refresh** — every 5 minutes (configurable)
- **Fallback mode** — if Keychain/API unavailable, uses local JSONL estimates with plan selection

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
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and used

## How It Works

### Rate Limits (real data)
TokenMeter reads Claude Code's OAuth token from the macOS Keychain and calls `api.anthropic.com/api/oauth/usage` to get real utilization percentages and reset times. On first launch, macOS will ask you to allow Keychain access — click "Always Allow".

### Usage Analytics (local data)
Parses JSONL files from `~/.claude/projects/` and `~/.config/claude/projects/`:
- **Daily costs** — groups by date, calculates using embedded model pricing
- **Hourly heatmap** — groups by hour-of-day per date for activity patterns
- **Model breakdown** — per-model token and cost breakdown
- Deduplicates by `requestId` and filters `<synthetic>` entries

### Notifications
Sends macOS notifications when rate limit utilization reaches 80% (session or weekly). Throttled to once per hour per window. Toggle in Settings.

### Pricing

Costs are calculated using API-equivalent pricing (per million tokens):

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Opus 4.5 | $5.00 | $25.00 | $6.25 | $0.50 |
| Opus 4 / 4.1 | $15.00 | $75.00 | $18.75 | $1.50 |
| Sonnet 4.5 | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku 4.5 | $1.00 | $5.00 | $1.25 | $0.10 |

> Note: These are API-equivalent costs for reference. Claude Code subscription users pay a flat monthly fee.

## Architecture

```
TokenMeter/
├── TokenMeterApp.swift              # App entry with MenuBarExtra
├── UsageViewModel.swift             # State, timer, caching, notifications
├── Models/
│   └── UsageSummary.swift           # Data models + ClaudePlan enum
├── Services/
│   ├── NativeUsageParser.swift      # JSONL parser + pricing engine
│   ├── UsageAPIService.swift        # Keychain + Anthropic API client
│   └── UpdateChecker.swift          # GitHub releases checker
└── Views/
    ├── DashboardView.swift          # Main popover container
    ├── RateLimitView.swift          # Progress bar with hover details
    ├── UsageHeatmapView.swift       # Hour-by-day activity heatmap
    ├── CostSummaryView.swift        # Today/week/month cost cards
    ├── DailyChartView.swift         # Swift Charts bar chart
    ├── ModelBreakdownView.swift     # Swift Charts donut chart
    └── SettingsView.swift           # Plan, notifications, refresh interval
```

```
Data Flow:
  Keychain OAuth  ──>  UsageAPIService  ──>  Real rate limit %
                                │
  ~/.claude/*.jsonl  ──>  NativeUsageParser  ──>  Costs + Hourly + Tokens
                                │
  Timer (5min)  ──>  UsageViewModel  ──>  UsageSummary  ──>  SwiftUI Views
                          │                                      │
                          ├──>  UserDefaults cache               └──>  Notifications (≥80%)
                          └──>  UNUserNotificationCenter
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
