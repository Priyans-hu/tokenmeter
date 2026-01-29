# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| < Latest | No       |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue
2. Email mailpriyanshugarg@gmail.com with details
3. Include steps to reproduce if possible

You should receive a response within 48 hours.

## Security Considerations

TokenMeter accesses the macOS Keychain to read Claude Code's OAuth token. This token is:
- Read-only from the keychain (never written or modified)
- Only sent to `api.anthropic.com` over HTTPS
- Never stored outside the keychain
- Never logged or transmitted elsewhere

The app also reads JSONL files from `~/.claude/projects/` locally. No data leaves your machine except the API call to Anthropic for rate limit information.
