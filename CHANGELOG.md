# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

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
