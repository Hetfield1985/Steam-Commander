# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

---

## [2.0.5] - 2026-10-10

### Fixed
* **Steam app icons were not found for newer games** (for example *Gears of War: E-Day*): the slot stayed empty. Steam now serves community / client icons from `shared.fastly.steamstatic.com` and `shared.akamai.steamstatic.com` under `/community_assets/images/apps/<appid>/<hash>`, while the old hosts (`cdn.cloudflare.steamstatic.com`, `cdn.akamai.steamstatic.com`, `media.steampowered.com`, `steamcdn-a.akamaihd.net`) return 404 for such games. The new hosts are tried first, the old ones stay as a fallback for older games.
* **SteamGridDB requests could hang until the timeout** although the site answered instantly in a browser. Requests (including the API key check) now go through the system `curl.exe` and fall back to the built-in .NET client only if it is missing. The .NET connection limit per host (2 by default) is raised to 32, `Expect: 100-continue` is turned off and idle connections are dropped after 15 s. After an aborted request or a network error the SteamGridDB connections are closed, so one stuck request no longer blocks all the following ones (cards, key check). Stopping a background request no longer waits for the blocking network call to return.
* **The Settings window opened only after the API keys had been checked** (up to 25 s for SteamGridDB and as long again for the Steam Web API when a service did not answer). The window now opens at once; the badge next to a key appears as soon as its check finishes. Changing the key text cancels the check of the old text, and *Cancel* restores the real state of the checks instead of "not checked yet".
* **The logo could stick out of the background preview** at 100 % size. The logo together with its margins is now kept inside the background.
* **A card showed the shared default logo position instead of the game's own saved one** when the "default for all games" checkbox was on, and saving then overwrote the game's own value. The saved position of a game / ROM is now shown first; the default is used only when the game has none yet.
* **ROMs launched from an archive (through `SCLauncher.exe`) showed the launcher's icon instead of the emulator's** in Library, on hover and in the list. The emulator is now taken from the `--emu` launch argument, such shortcuts are recognised as ROMs, the card opens the archive as the ROM and "open location" points to the file itself.

### Improved
* **Cards of games that are already in the library open without the network.** The name comes from the shortcut, covers from `config\grid`, App ID and the list of cover regions from `cover_sources\<id>.json`; for licensed games the official images are taken from the local Steam client cache (`appcache\librarycache`: capsule, header, hero, logo, icon). Nothing is downloaded until you change something: the Steam launch-exe hint is skipped, and the full list of regions is loaded when you click the region button. If a saved Steam icon is missing or completely black (a broken old `.ico` → `.png`), it is replaced with the icon from the local Steam cache.
* **App ID, its source (Steam / SteamGridDB) and the list of regions are now saved** in `cover_sources\<id>.json` when a game is added (including silent import) or a card is saved. The values already written are kept if a new save does not provide them.
* For games added before this metadata existed, the card looks up the App ID in the local Steam apps database (*Settings → Steam Web API*), using the game folder name, then the shortcut name, then the card title. Only an exact match is used; if several games share the name, nothing is guessed and the App ID field stays empty. The region of such games is taken as English and the source badge as Steam.
* ROM archive listing is cached (path + size + date), so reopening a card no longer runs 7-Zip again; the 7-Zip location is cached too.
* Picking the main file in a ROM folder is faster for folders with many files (the check for a neighbouring `.cue` / `.m3u` / `.ccd` / `.mds` / `.toc` is done once per folder).
* The delay before the autocomplete search starts after typing in the name field is 300 ms instead of 150 ms, so it fires less often while you are still typing.

### Changed
* Application version is now 2.0.5.

---

## [2.0.4] - 2026-10-09

### Added
* **Platform-aware SteamGridDB covers for ROMs.** SteamGridDB cannot filter covers by platform, so a game used to get covers from every release (Game Boy, GBA, SNES, PS1, ...) mixed together. The ROM's platform is now detected from the file extension (including the file inside an archive), the emulator profile (known emulators such as Flycast, snes9x, Dolphin), the RetroArch core, the emulator's extensions, or the names of the nearest folders. Covers whose description names that platform go first, covers with no platform mentioned stay in the middle, and covers for another platform go last. It is a priority, not a filter, so nothing is hidden. Applies to silent ROM import, the ROM card (loading and the alternatives list of the vertical and horizontal covers) and follows a change of emulator or ROM in the card.
* **Archive extraction progress window.** If unpacking a ROM archive takes longer than about a second, a small window with a progress bar, percentage, unpacked / total size and a **Cancel** button is shown (zip: exact size; 7z / rar: percent reported by 7-Zip). Small archives unpack without the window flashing. `SCLauncher.exe` is regenerated automatically (helper version 34).
* **Full file names on hover.** In both panels, hovering over a name that does not fit into the *Name* column shows a tooltip with the full name (useful for ROMs like `Alone in the Dark - The New Nightmare (USA) (Disc 1).cue`).

### Fixed
* **A ROM archive was marked as "not sure" and opened in the card although there was only one correct file:**
  * `(v1.1)` after the region (`Dino Crisis (USA) (v1.1).7z`) was treated as a patch version. Revisions in No-Intro / Redump style are now recognised as the game itself.
  * A numeral that is part of the title (`Micro Machines V3 (USA)`) was treated as a version.
  * An archive that contains a single disc image (`.cue` + `.bin` parts) is now judged by the file inside, not by the archive name.
  * Nintendo Switch is not affected: `[vN]` in `.nsp` / `.xci` names is still an update and is never picked automatically.
* **Wrong game and no covers for titles with a trailing article** (`Mummy, The (USA)` found *Mummy on the run*). `Name, The` / `A` / `An` is now turned into `The Name` before searching SteamGridDB, in the card, batch add and the autocomplete list.
* **The logo "default for all games" checkbox stayed on for every next card**, and changing the logo in a card silently replaced the saved default. The checkbox is now unchecked as soon as the logo position or size differs from the default (dragging, slider, scale). A new default is saved only when the checkbox is ticked again. Saving a card where the checkbox was unchecked because of a deviation no longer turns the saved default off for other games; unchecking it by hand without changing anything still disables the default.
* **ROM shortcuts without an icon in Library / Import:** if the shortcut has no icon path, the icon is now looked up in `config\grid` (`<appid>_icon.*`) next to `shortcuts.vdf`.
* **Tiny icons from SteamGridDB (pixel art under 512 bytes) were rejected as a failed download.** The size threshold for icons is lowered; covers keep the old one.
* If the full-size cover could not be downloaded but its thumbnail from the picker window was loaded, the thumbnail is used instead of resetting the slot to the placeholder.
* The status line showed **"5 of 4"** after loading covers from SteamGridDB (there are five slots including the icon). Now "5 of 5" in all languages.

### Changed
* The ePSXe preset now has default launch arguments `-f -nogui -loadbin {rom}`.

---

## [2.0.3] - 2026-10-09

### Fixed
* **The window froze ("Not responding") after pressing *Add selected games to library*, before the first card appeared.** The "already in Steam" check re-parsed the whole `shortcuts.vdf` for every selected game, and Steam was closed with a call that did not let the window process messages. The file is now parsed once and cached (it is re-read only when it changes), and Steam is closed without blocking the window.
* **Silent ROM import: a sequel could get the title and covers of the first game** (for example *Dead to Rights II* was matched to *Dead to Rights*, so both shortcuts ended up with the same name and cover). Part numbers (`2`, `II`, `Part 2`) are now taken into account when ranking SteamGridDB results, and if the best match is a different part, the ROM is opened in the regular card instead of being added automatically.
* Two ROMs with the same title on the same emulator (for example *Disc 2* of a game) could get the same shortcut ID, so Steam merged them and the second one lost its covers. A free ID is now chosen automatically.
* Editing a ROM shortcut could change another shortcut that uses the same emulator and ROM folder. The shortcut is now re-read by its ID before saving.
* SteamGridDB temporary failures (429, 5xx, timeouts, dropped connections) are retried with a growing delay instead of immediately showing "covers failed to load". A network error while checking the API key at startup no longer greys out the SteamGridDB button until the app is restarted.
* Cancelling a batch or closing a card now stops reading a 7z / rar archive right away.

### Improved
* Refreshing the panels is faster: `shortcuts.vdf` is looked up only in the Steam profile folders instead of scanning the whole `userdata` folder (thousands of cover images), and the drive label and free space no longer go through WMI. This is noticeable after adding games and with *Refresh* / `F5`.
* A batch started from the main window refreshes the panels once at the end instead of after every card.

### Changed
* Silent ROM import adds a shortcut directly, without opening a hidden card, when everything is detected confidently; otherwise the ROM goes to the regular card queue.

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
