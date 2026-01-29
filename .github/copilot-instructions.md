# TokenMeter — Copilot Instructions

macOS menu bar app for tracking Claude Code usage, rate limits, and costs.

## Tech Stack
- Swift 5.9+, SwiftUI, macOS 14+ (Sonoma)
- Swift Package Manager — `cd TokenMeter && swift build -c release`
- Swift Concurrency — async/await, actors, @MainActor

## Architecture
- `TokenMeterApp.swift` — MenuBarExtra app entry point
- `UsageViewModel.swift` — @MainActor ObservableObject for all state
- `Services/NativeUsageParser.swift` — parses JSONL from ~/.claude/projects/
- `Services/UsageAPIService.swift` — actor, reads Keychain OAuth token, calls Anthropic API
- `Models/UsageSummary.swift` — data models (DailyUsage, HourlyUsage, RateLimitInfo, ClaudePlan)
- `Views/` — SwiftUI views

## Conventions
- UsageAPIService is an `actor` for thread safety
- UsageViewModel is `@MainActor` for UI updates
- Concurrent data fetching with `async let`
- No Xcode project — SPM only
- macOS 14+ minimum deployment target
