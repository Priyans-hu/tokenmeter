# Contributing to TokenMeter

Thanks for your interest in contributing.

## Getting Started

1. Fork the repo
2. Clone your fork
3. Install prerequisites:
   - [Rust](https://rustup.rs/)
   - Node.js
   - [ccusage](https://github.com/yucchiy/ccusage): `npm install -g ccusage`
4. Run `npm install`
5. Run `npm run tauri dev`

## Development

### Project Layout

- `src/` — Frontend (vanilla HTML/CSS/JS, no framework)
- `src-tauri/src/` — Rust backend (Tauri v2)
- `src-tauri/src/providers/` — Data provider modules

### Adding a Provider

Implement the `UsageProvider` trait in `src-tauri/src/providers/`:

```rust
pub trait UsageProvider: Send + Sync {
    fn name(&self) -> &str;
    fn fetch_daily(&self, since: &str, until: &str) -> Result<Vec<DailyUsage>, ProviderError>;
}
```

### Building

```bash
npm run tauri build -- --bundles app
```

## Submitting Changes

1. Create a branch: `git checkout -b feat/your-feature`
2. Make your changes
3. Test by running `npm run tauri dev`
4. Build with `npm run tauri build -- --bundles app`
5. Commit with a descriptive message
6. Push and open a PR against `main`

## Reporting Issues

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console output if applicable

## Code Style

- Rust: follow `cargo fmt` and `cargo clippy`
- JS: vanilla JS, no frameworks, keep it simple
- CSS: use CSS custom properties defined in `:root`
