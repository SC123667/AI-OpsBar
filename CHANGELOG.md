# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - 2026-03-11

### Added

- Renamed the product to `AI OpsBar`.
- Added bilingual English and Simplified Chinese project documentation.
- Added grouped service monitoring for Codex, Gemini, Claude, Cursor, GitHub Copilot, AntiGravity, Droid, Z.ai, MiniMax, and DeepSeek.
- Added grouped dashboard layout with issue filtering and per-service failure summaries.
- Added grouped status bar menu layout closer to menu bar utility workflows.
- Added API key storage for multiple providers via macOS Keychain.
- Added LaunchAgent-based manual launch-at-login support.
- Added double-clickable `.app` bundle build script.

### Changed

- Reduced background overhead with adaptive refresh intervals and timer tolerance.
- Switched status bar presentation to custom-drawn icon states.
- Changed interaction model so the dashboard opens only from the menu.

### Notes

- Some providers currently support web-only availability checks because a stable public API endpoint suitable for generic availability probing is not exposed.
- Quota and usage monitoring are planned next.
