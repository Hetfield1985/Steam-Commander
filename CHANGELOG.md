# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

[1.1.1] - 2026-09-22
Added
Region setting for Steam cover language, independent of the interface language.
Full grid of available cover languages in the game card, showing only languages that actually have covers for that game.
Automatic game title translation when switching the cover language.
Custom application icons are now saved and applied to shortcuts, with automatic SteamGridDB fallback when Steam has none.
Improved
Improved App ID matching for already-added games, based on folder and shortcut names.
Improved custom icon downloading, format detection, and rendering reliability.
Improved responsiveness during automatic batch game addition.
Improved thumbnail selection windows with centered, evenly spaced layouts.
Improved accuracy of cover language availability detection.
Improved Settings dialog layout; removed a redundant profile status label.

## [1.1.0] - 2026-09-21

### Added
- Steam Web API support for more accurate game title and App ID searches.
- Local Steam game database with saved titles and App IDs for faster searches.
- EXE filter setting to optionally include game launchers in executable suggestions.

### Improved
- Improved application stability and responsiveness during network operations and cover loading.
- Improved search speed using the local game database and in-memory index.
- Improved SteamGridDB and cover loading behavior.
- Improved cancellation and skipping of ongoing operations.
- Improved title and launch parameter suggestions and focus handling.
- Improved overall UI consistency and localization.

## [1.0.1] - 2026-09-20

### Fixed
- Covers from a previously opened game card could be applied to a game without a Steam App ID.
- A game whose executable sits in a common subfolder (for example `bin`) was wrongly reported as already in the Steam library.

---

## [1.0.0] - 2026-09-20

First public release.

### Added
- Two-panel game library browser (panels **C** and **D**) with search, sorting, folder sizes and an "already in Steam library" marker.
- Adding non-Steam games to Steam: single game card or batch mode with optional auto-fill for confidently detected games.
- Game card editor: title, executable, start folder, launch parameters and four cover slots (vertical, horizontal, hero, logo).
- Cover sources: official Steam assets (with cover-region selection) and SteamGridDB (API key required).
- Executable detection, including a hint taken from Steam's own launch data.
- Moving games between the two panel folders with progress, speed and free-space checks; Steam shortcuts are updated to the new paths.
- Manual backup and restore of `shortcuts.vdf`.
- Interface languages: Русский, English, 简体中文, Español, Português (Brasil), Deutsch.
- Keyboard shortcuts for both panels (Enter, Space, Delete, Ctrl+A).
- Application icon, embedded into the window and the executable.
- Build script (`build/build.ps1`) and a GitHub Actions release workflow.
