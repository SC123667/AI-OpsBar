# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] - 2026-03-11

### Added

- Added local Codex usage windows in the dashboard and quick status popover, with `5h`, `1d`, `7d`, `30d`, and `all` rollups derived from local session logs.

### Changed

- Fixed Codex local quota probing against newer `codex app-server` initialization requirements.
- Added a local-session-log fallback for Codex quota when the app-server is temporarily unavailable.
- Changed Codex spend monitoring to prefer local usage logs; when local logs expose token usage but not USD cost, AI OpsBar now shows token windows instead of an empty amount.
- Fixed local Codex session-log timestamp parsing so spend and usage windows populate correctly from fractional-second JSONL entries.
- Expanded local Codex usage aggregation to include archived session logs for more accurate long-window totals.
- Reworked Codex spend and usage window presentation into a structured grid instead of a single inline summary string.

## [0.4.0] - 2026-03-11

### Added

- Added persistent per-service health history with compact trend sparklines in the panel and status popover.
- Added macOS notifications for service degradation, recovery, and low-quota or rate-limit signals.
- Added user-defined custom services with editable web/API endpoints, group assignment, bearer-auth support, and Keychain-backed API key management.
- Added a quick status popover on left-clicking the menu bar icon, with top issues and recent health summaries.

### Changed

- Promoted quota monitoring into the main service summary flow, including low-quota alerting and history capture.
- Refactored service identity and definition handling so built-in and custom services share the same monitoring pipeline.
- Expanded the dashboard settings panel with notification controls and custom service management.

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
