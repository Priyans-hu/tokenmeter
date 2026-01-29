# TokenMeter

macOS menu bar app for tracking Claude Code usage, rate limits, and costs. Native SwiftUI, no Electron/Tauri.

## Build

```bash
cd TokenMeter
swift build -c release
```

Binary output: `TokenMeter/.build/release/TokenMeter`

## Architecture

- **SwiftUI MenuBarExtra** — macOS 14+, `LSUIElement` (no dock icon)
- **Swift Package Manager** — single executable target, no Xcode project
- **Concurrency** — `@MainActor` view model, `actor` for services, `async let` for parallel fetches

### Key Components

| File | Role |
|------|------|
| `TokenMeterApp.swift` | App entry, `MenuBarExtra` with popover |
| `UsageViewModel.swift` | `@MainActor ObservableObject` — state, timer, caching, notifications |
| `Services/NativeUsageParser.swift` | Parses `~/.claude/projects/**/*.jsonl` — costs, tokens, hourly data |
| `Services/UsageAPIService.swift` | Reads OAuth token from macOS Keychain, calls `api.anthropic.com/api/oauth/usage` |
| `Services/UpdateChecker.swift` | Checks GitHub releases for updates |
| `Models/UsageSummary.swift` | All data models: `DailyUsage`, `HourlyUsage`, `RateLimitInfo`, `ClaudePlan` |
| `Views/` | SwiftUI views — dashboard, rate limits, heatmap, charts, settings |

### Data Sources

1. **Anthropic API** (`UsageAPIService`) — real rate limit utilization % and reset times
   - Reads OAuth token from Keychain (`kSecAttrService: "Claude Code-credentials"`)
   - `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <token>`
   - Also reads `rateLimitTier` from credential blob for plan auto-detection

2. **Local JSONL** (`NativeUsageParser`) — costs, model breakdowns, token counts, hourly activity
   - Scans `~/.claude/projects/` and `~/.config/claude/projects/`
   - Deduplicates by `requestId`, filters `<synthetic>` entries
   - Embedded pricing: Opus 4.5 ($5/$25), Sonnet ($3/$15), Haiku ($1/$5) per MTok

### Patterns

- API + local data fetched concurrently via `async let` in `refresh()`
- API data preferred for rate limits; local data used as fallback
- `UserDefaults` for caching summary + settings
- `UNUserNotificationCenter` for rate limit alerts (80% threshold, 1hr throttle)
- Timer-based auto-refresh (default 5 min)

## Release

Push a version tag to trigger automated release:
```bash
git tag v0.x.0
git push origin v0.x.0
```

GitHub Actions builds, ad-hoc signs, creates release zip, and updates Homebrew cask.

## Install

```bash
brew install Priyans-hu/tap/tokenmeter
```
