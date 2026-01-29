# Contributing to TokenMeter

Thanks for your interest in contributing to TokenMeter!

## Getting Started

1. Fork and clone the repo
2. Build the project:
   ```bash
   cd TokenMeter
   swift build -c release
   ```
3. Create a feature branch: `git checkout -b feat/my-feature`

## Development

### Requirements
- macOS 14 (Sonoma) or later
- Swift 5.9+
- Claude Code installed (for testing with real data)

### Project Structure
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
└── Views/                           # SwiftUI views
```

### Building and Testing

```bash
cd TokenMeter
swift build -c release
```

To install locally for testing:
```bash
cp .build/release/TokenMeter /Applications/TokenMeter.app/Contents/MacOS/TokenMeter
```

## Submitting Changes

1. Ensure `swift build -c release` passes
2. Keep commits focused and atomic
3. Write clear commit messages
4. Submit a PR to `main`

## Reporting Issues

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) for bugs
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) for new ideas

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
