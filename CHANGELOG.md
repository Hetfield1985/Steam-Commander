# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

---

## [2.0.2] - 2026-10-08

### Added
* **Background and logo composition in the game card** — the hero background and the logo are now one preview slot, like in Steam: the logo is drawn over the background. Drag the logo to move it (it snaps to the five positions Steam supports: top left, top center, center, bottom left, bottom center) and use the mouse wheel or the slider to resize it from 10 to 100 %. 
* **Logo position is saved to Steam** — position and size are written to the Steam config of every profile for new shortcuts, edited shortcuts and licensed games, and are read back when the card is opened again.
* **Default logo position and size** — new checkbox under the scale slider in the *Background & logo* slot. When it is on, the current logo position and size are saved as the default and applied to every card (new games, existing shortcuts and ROMs) and to auto-import / batch add, including games added without covers. Turning it off returns to per-game values. The setting is stored in `config.ini`.

### Fixed
* **Silent ROM auto-import** 

### Changed
* The game card layout: the vertical cover stays on the left, the horizontal cover moves under it, and the hero slot is widened and shows the background with the logo. The separate logo slot is hidden but still holds the logo image, source and alternatives.

---

## [2.0.1] - 2026-10-05

### Fixed
* The **Only with upscaler libraries** filter in Library / Import now also hides ROM shortcuts that have no libraries. Previously ROMs were always shown.
* Upscaler libraries (DLSS, DLSS RR, DLSS FG, FSR, XeSS, XeLL) located deep inside a game folder were not detected, for example Unreal Engine games with `Engine\Plugins\Runtime\Nvidia\DLSS\Binaries\ThirdParty\Win64`. The folder scan depth is increased from 6 to 12 levels in all scanners: tile version, `.sc_orig` backup search, game folder walk and the game card.

---

## [2.0.0] - 2026-10-04

Major feature release: launcher import, ROMs/emulation, upscaler management, built-in Steam database, and large-scale UI/architecture improvements.

### Added
* **Launcher import (Library / Import)** — detect and import installed games from Epic Games, GOG Galaxy, Ubisoft Connect, EA App, Battle.net and Xbox into Steam as non-Steam shortcuts. Dedicated tabs, filters (“From launchers”), auto-import option, launcher-specific badges, covers and launch handling (including silent client start / cleanup for Ubisoft and Battle.net).
* **ROMs mode** — browse folders and ROM files filtered by the active emulator’s extensions. Adding a ROM creates a Steam shortcut that launches it through the selected emulator.
* **Emulator profiles** — full manager in Settings (add / edit / remove). Custom launch-argument templates, ROM extensions, archive-extraction options and per-emulator icons.
* **RetroArch integration** — core picker (default core stored per emulator profile), detection of cores that can read archives natively, smart temporary extraction when needed.
* **ROM archive support** — zip / 7z / rar / tar / gz / bz2 / xz via 7-Zip (optional download). Temporary extraction + cleanup after the emulator exits. Generated **SCLauncher.exe** helper for archive and complex launcher wrappers.
* **Upscaler libraries** — download and version management of DLSS / FSR / XeSS / XeLL. Replace libraries inside selected games (originals kept as `.sc_orig`), restore later, and filter the library view to games that contain upscaler DLLs.
* **Built-in Steam apps database** — gzip+base64 snapshot of the Steam application list is embedded and extracted on first run. Title/AppID search works immediately without a Steam Web API key; users can still refresh the database with their own key.
* **Startup splash screen** — animated loading screen with progress while types are compiled, libraries loaded and configuration read.
* **Small-screen / high-DPI adaptation** — fixed-layout windows shrink to the working area and become scrollable when necessary; sizable windows are constrained to the screen. Correct behaviour under Windows display scaling (e.g. 150 %).
* **External / community language files** — localisation can be overridden or extended via editable files in the `lang` folder (format validation + fallback to built-in strings).
* **Library preheating** — background loading of Steam library and launcher data while the main window is idle, so the Library/Import browser opens faster.

### Improved
* Steam Library browser completely reworked: multi-source view (Steam + launchers), filters, upscaler actions, seamless transition from the main window, performance and visual polish.
* Batch-add flow (progress, cancellation, status text) and overall UI responsiveness during long network / file operations.
* Game card editor extended for ROM entries, launcher-style shortcuts and upscaler controls.
* Settings dialog reorganised to host Emulators (ROMs) and Upscaler libraries sections.
* Path handling, free-space checks and inter-panel move operations.
* Local Steam database search (in-memory index, tier/junk scoring).
* Overall stability, localisation coverage and consistency across all supported languages.

### Changed
* Main “Steam Library” button renamed to **Library / Import** to reflect the new multi-source capabilities.
* Application version bumped to 2.0.0 (major version for the new launcher-import, ROMs and upscaler feature set and the corresponding architectural growth).

---

## [1.2.2] - 2026-09-26
### Fixes
* Fixed detection of games already added to Steam
* The actual game path is now checked instead of relying only on the game name. The actual location on disk is checked.
* Steam CDN remains as a fallback when no local icon is available.
* The button now correctly shows the number of new games only.
* If only games already in Steam are selected, the Add button is hidden.

### Added
* Path fields in both panels are now fully editable. Press Enter after entering a path to navigate to it.
* Panel headers now show the volume name + drive letter instead of the generic folder name.

---

## [1.2.1] - 2026-09-26

### Added

* **Steam Library** — browse and edit games directly in the library.
* **Licensed games support** — covers and launch parameters can now be viewed and edited.
* Improved Steam profile and game data detection.
* Improved EXE and launch parameter detection.
* Added automatic backups before modifying Steam data.

### Fixed

* Various issues with Steam data, game detection, covers, and launch parameters.


---
## [1.1.1] - 2026-09-22
### Added
- Region setting for Steam cover language, independent of the interface language.
- Full grid of available cover languages in the game card, showing only languages that actually have covers for that game.
- Automatic game title translation when switching the cover language.
- Custom application icons are now saved and applied to shortcuts, with automatic SteamGridDB fallback when Steam has none.
### Improved
- Improved App ID matching for already-added games, based on folder and shortcut names.
- Improved custom icon downloading, format detection, and rendering reliability.
- Improved responsiveness during automatic batch game addition.
- Improved thumbnail selection windows with centered, evenly spaced layouts.
- Improved accuracy of cover language availability detection.
- Improved Settings dialog layout; removed a redundant profile status label.

---

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

---

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
