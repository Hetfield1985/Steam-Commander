# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

---

## [2.1.2] - 2026-10-20

### Added
* **Saves search without launching games.** New magnifier button in the *Saves* group of the *Library / Import* toolbar finds the saves of the ticked games (database, emulators, Steam Cloud, heuristics) and remembers them. Games with several locations are shown in one window with check boxes; a report is shown at the end.
* **Actions without a selection.** With no games selected, *Update upscalers*, *Back up* and *Find saves* apply to all games of the current list.
* **Upscalers and saves in the tile menu.** The right-click menu now has *Find saves*, *Update upscalers* and *Restore original upscalers*, for one game or for all ticked ones.
* **Green check mark in the game card** when the saves of the game are found.
* **Saves are searched when a game is added** to Steam, without launching it.

### Improved
* **The saves detector in the card works without launching the game;** launching is offered only if nothing is found.
* **Cleaner list of save locations:** neighbouring files and folders are merged into their common folder.
* **Bulk backup and restore no longer make the window freeze.**
* **The library button is plain text:** *Library / Import / Saves / DLSS Swap*; the launcher icons are removed.

### Fixed
* **The check mark did not appear for saves in junction or OneDrive folders.**
* **The buttons of the card were not refreshed when it opened.**
* **An empty database folder stopped the heuristic search.**
* **An empty line without a path appeared in the detector window.**

### Changed
* Application version is now 2.1.2.

---

## [2.1.1] - 2026-10-18

### Added
* **Backup and restore of game saves.** New **Saves** group on the *Library / Import* toolbar with **Back up** and **Restore** buttons for the ticked games. Save locations come from the official Ludusavi database plus the known paths of emulators. If the saves did not change since the last backup, no new archive is created. Before a restore the current saves are put into a `pre-restore` safety archive; when a game has several backups, a picker lets you choose one. A table report shows the result for every game (*Created* / *Restored* / *Unchanged* / *No saves* / *No backup* / *Error*).
* **Saves for a single game.** The game card has a **Saves** group of four icon buttons: open the saves folder, detect saves, back up, restore. The same actions (*Saves folder*, *Back up saves*, *Restore saves...*) are in the right-click menu of every tile in *Library / Import*.
* **Saves detector.** The magnifier button in the card first looks the game up in the database; if nothing is found, it can launch the game, watch the files it creates and offer the most likely locations. The ticked locations are remembered for the game (the button turns green), and its right-click menu can detect again, track a game launch or reset the saved result.
* **Saves section in Settings** with the state of the saves database, an **Update** button (downloads a fresh Ludusavi database; nothing happens if it is up to date) and the common backup folder.
* **Launch button in the game card.** A button with a play icon, the same size as the *Browse* button, stands next to the EXE button (next to the ROM button in ROM cards) and starts the game: Steam games through Steam, shortcuts, launcher games and ROMs through their own executable and launch options. For a ROM it uses the saved library entry, so it is disabled for a ROM that has not been added yet.
* **Launch in the tile menu.** The right-click menu of every game and ROM in *Library / Import* now starts with **Launch**.
* **Full paths in the saves picker.** Hovering a location in the *Saves detector* window shows its full path in a tooltip, and the right-click menu **Open folder** opens it (a file is shown selected in Explorer) so you can check whether the save files are really there.

### Improved
* **New sharp icons on the save buttons.** The magnifier, floppy disk and restore buttons in the card, and the backup / restore buttons in the library (a larger variant), are drawn by code instead of emoji and symbol fonts, so they stay crisp at any scale and match the other icon buttons. The library *Refresh* button uses the same two-arrow icon as *Update upscalers*, and the library's upscaler restore button uses the restore icon.
* **Cover paths are cached more precisely.** The cache entry of a game is invalidated only by changes to the files of that game (`config\grid`, `librarycache`, `appcache\librarycache`), not by any change in the shared folders, so editing one card or starting Steam no longer makes the covers of the whole library be searched again.
* **Buttons stay in place while covers load.** The EXE button and the eye button no longer disappear during loading; they stay on top of the spinner and are only disabled.
* **Group captions in the library toolbar** (*Emulators*, *Saves*, *Upscalers*) make the button groups easier to tell apart.

### Fixed
* **Tiles at the end of a long list disappeared** in a narrow library window with hundreds of games, because Windows does not draw child windows beyond ~32 767 px of height. A tall grid is now split into several sections laid out one under another; far sections are hidden. Short grids use one section as before.
* **The Steam restart button in the library no longer breaks the grid.** It is an overlay strip over the bottom of the list, so showing or hiding it does not change the list size or recalculate the columns.

### Changed
* `SCLauncher.exe` is regenerated automatically (helper version 36).
* Debug log files are no longer written.
* Application version is now 2.1.1.

---

## [2.1.0] - 2026-10-17

### Added
* **The logo position set by the developer in Steam is used.** For a licensed game with no saved position, the card takes the official position and size from Steam (PICS `logo_position`) instead of the fixed "bottom left, 50 %".
* **More places to look for the vertical cover.** If the usual one is missing, the program tries all capsule links from PICS (`image2x` / `image`, interface language, English, any other) on all three Steam CDN hosts, the standard file names, and the local Steam client cache.

### Improved
* **The logo scale is shown correctly when the logo frame is not square.** For example, with a width of 38 % and a height of 100 % the slider now shows the equivalent scale instead of the width only; the saved position is not changed.
* **Logo defaults in cards of games already in Steam.** The *default for all games* value is applied only to games not added yet. For added games the real position from Steam is shown, the lock is not turned on when the card opens but still works (it makes the current position the new default), and it turns on by itself when the position and scale equal the default.
* **Changing the cover language is cleaner.** The old logo is hidden while covers load, all covers are applied at once, and the previous logo is restored if the new one cannot be downloaded.
* **Local Steam covers are searched in hashed subfolders** (`appcache\librarycache\<appid>\<hash>\`) as well, in the card and in the library.

### Fixed
* **The vertical cover stayed empty although it exists in Steam.** Only one capsule link was tried; if that file was missing on the CDN (for example the Russian one), nothing was shown. See the new fallbacks above.
* **The progress bar of a move jumped to full at once** with `robocopy`, which pre-allocates the file. It now counts the bytes actually written.

### Changed
* **The search source switch is the segmented control `[ Steam | SGDB ]` again** instead of a single toggle button.

---

## [2.0.9] - 2026-10-16

### Added
* **Upscaler libraries are updated when a game is added.** New **Update on add** tick in *Settings → Upscaler libraries* (off by default). When a game is added to Steam (manually, from a card or by auto-import), DLSS / FSR / XeSS / XeLL in the game folder are replaced with the versions selected in the settings (or the newest downloaded ones). A file that is already the same version or newer is not touched, the original is kept as `.sc_orig`, and a failure never blocks adding the game. ROMs are skipped. The setting is stored in `config.ini`.
* **A full report for "Update upscalers" and "Restore backups".** Instead of a plain message box, a resizable window shows a short summary and a table of *all* processed games: game, result (*Done* / *Unchanged* / *Not found* / *Error*) and the libraries or the error text. Errors are listed first; rows can be selected and copied.
* **Steam framing button in the *Background & logo* preview** (left of the eye). It shows the background the way the Steam client does: the top part hidden under Steam's top bar is darkened and blurred, and the tail below the sharp part is blurred and fades into the window colour. Off by default (the whole background is drawn, as before); the choice is saved in `config.ini` and applies to all cards.
* **Position marks while dragging the logo.** Green marks show the five Steam positions (corners on the left, bars at the top / bottom centre, a square in the centre); the one the logo will snap to is brighter and thicker.
* **Size of the ticked games by panel.** Pressing Space now shows the size separately for the left and right panel with the drive letter and the number of ticked games, plus a total when both panels have ticks: `Left (C:) 20.1 GB (2) · Right (D:) 4012.5 GB (141) · Total ...`.
* **Hint in the status line of the main window.** It explains that games are ticked to add them to the library or move them, and after you tick something it suggests pressing Space to calculate the size. It is replaced when the ticks or a folder change and never overwrites the status of a move, an import or an error.

### Improved
* **The logo position and size in the card match Steam more closely.** The logo area is now calculated from the sharp upper part of the hero image (the top ~74 px at 1635 px width are hidden under Steam's top bar), with the margins and the size reference measured from Steam at 50 % and 100 %. The constants are kept in one place so they are easy to adjust.
* **Snapping the logo to a position is more predictable.** The column (left / centre) and the row (top / centre / bottom) are chosen separately, and the vertical thresholds cannot shrink below a share of the visible area. Before, a large logo covered almost the whole area, the centres of several positions coincided and the choice looked random and did not match the highlighted mark.
* **Icons of the eye, lock and Steam framing buttons are drawn by code** instead of Segoe MDL2 Assets glyphs, so they look the same in every Windows version (no empty squares where the font is missing), stay sharp and follow the screen scale. A hidden logo now also highlights the eye button with the accent colour.
* **The emulator picker remembers its page.** While the program is running, it opens on the page where you chose an emulator last time instead of the first one.
* **The status of the *Upscaler libraries* section** is shown in brackets right after the section title, and the freed place in the button row is used by the *Update on add* tick.

### Fixed
* **`config.ini` could be damaged if saving was interrupted** (disk, permissions, antivirus). The settings are now written to a temporary file and swapped in, so the previous file stays intact on failure; a direct write is used only as a fallback. Save errors are written to `config_error.log` next to `config.ini` (the log is restarted when it grows over ~512 KB).
* **"Cannot move" was reported misleadingly.** When the ticked games do not fit, the status now shows the total size and how much space is missing, taking into account that moving in both directions frees space on the other drive (*Cannot move. Ticked: ... Short by ...*). Before, it showed only the part that would fit or the shortage of a single game.

### Changed
* The messages about the size of the ticked games no longer repeat the number of games (it is shown per panel now); the texts are updated in all six languages.
* Application version is now 2.0.9.

---

## [2.0.8] - 2026-10-14

### Improved
* **Refreshing the panels is faster.** The "already in Steam" map is cached (by the panel folders and the size / date of `shortcuts.vdf`) and is not rebuilt when nothing has changed. Switching the ROMs mode or the emulator keeps the current map instead of rescanning `shortcuts.vdf`. Cleaning up `cover_sources` of games that were removed from Steam now runs in the background shortly after the refresh, so it no longer delays the panels.
* **Folders with thousands of ROMs no longer freeze the window.** The panel contents are read with a direct directory enumeration instead of `Get-ChildItem` with array appends, and the window shows the wait cursor while the panels are being refreshed.
* **Library / Import is smoother.**
  * Tiles of every tab (Steam, Epic, ...) are kept, so switching between tabs no longer rebuilds them from scratch.
  * A tab is always built in portions: the visible screen first, the rest after the window is shown, so a tab or filter change on hundreds of games does not block the window.
  * Loading of tiles and covers is paused while you scroll or hold a mouse button, so scrolling no longer stutters.
  * The search and the filters also work while a tab is still being filled; the Steam tab is rebuilt after a refresh.

### Fixed
* **The icon source badge was wrong when a saved game was opened.** If the icon of a game in `config\grid` was taken from its EXE, the card still showed the *Steam* badge. The badge now matches the real icon (*Local*).

### Changed
* Application version is now 2.0.8.

---

## [2.0.7] - 2026-10-13

### Added
* **Quick emulator switch for ROMs already in Steam.** Right-click a ROM tile in *Library / Import* → **Switch emulator** (or **Switch for all "X" games**); no card is needed, only `Exe`, the working folder and the launch options change, while the title, covers and icon stay. Works for all ticked ROMs, asks for confirmation if the ROM extension does not fit the new emulator, and opens a core picker with search for RetroArch. The same is available from the *Switch emulator* button of the library toolbar and from the main window (in ROMs mode, when only games already in Steam are ticked, the main button switches them to the emulator chosen under *Refresh*).
* **Steam restart mode (Settings):** *Automatically* (as before) or *Manually*. In the manual mode the program asks you to close Steam, writes `shortcuts.vdf` and writes it again after Steam exits (Steam overwrites it from memory when it quits). A **Restart Steam** button on the main window restarts it for you.
* **Filter by emulator in Library / Import:** a tick for the ROM games of each emulator, **Undetected** for ROMs with an unknown emulator, and **Hide all**.

### Changed
* The *Filter*, *Select all* and *Deselect all* buttons of the library are icons now. The right mouse button no longer opens a card or ticks a tile (it opens the ROM context menu).
* The emulator dialog and the Settings window are aligned (28 px fields and folder button).
* Moving games, adding games and saving a card respect the Steam restart mode.
* Application version is now 2.0.7.

### Improved
* The ROM context menu opens at once, and the launcher filter no longer freezes the library (launcher games are indexed by path once).

### Fixed
* **ROMs with an `.ico` icon had no icon in the panels** (the archive placeholder was shown) although the icon was present in Steam, in the card and in `config\grid`. The panel now reads icons the same way as the card (by content, not by extension) and tries the neighbouring `<appid>_icon.*` files if one cannot be read.
* ROM shortcuts without an icon in `config\grid` take it from the Steam client cache (`appcache\librarycache`).
* ROMs inside a game folder (Switch, Wii U) are marked correctly: separately added ROM files get the "in library" tick, not the folder.
* A logo hidden with the eye could be lost after saving. A copy is now kept in `%AppData%\Steam Commander\hidden_logos`, so the logo can be switched back on when the card is opened again.
* The default logo position and size apply at once when the lock is pressed.
* Changes waiting for Steam to close are no longer lost when the program is closed.

---

## [2.0.6] - 2026-10-11

### Added
* **A logo hidden with the eye button is no longer saved to Steam.** Before, the eye only hid the logo in the card preview, and `<id>_logo.png` was still copied to `config\grid`. Now, if the logo is hidden when you press *Add* / *Save*, the file is not left in Steam: it is removed from `config\grid` of all Steam profiles (for an edited shortcut, under both the old and the new id after a rename; for a licensed game, the custom logo is removed and Steam falls back to its own). Works for a new shortcut, an edited shortcut and a licensed game, including ROMs opened in the card. Toggling the eye counts as a change of the card, so saving works even if nothing else was touched. Silent import and batch adding have no eye and behave as before: they only use the "default for all games" lock.
* **A game in SteamGridDB is found by its Steam App ID.** When the card title is localized (for example a Steam region name), SteamGridDB knows the game under the original name and the search by the localized title found nothing. Switching the source to SteamGridDB now first looks the game up by the Steam App ID and keeps the title in the card unchanged. For a game added earlier, whose SGDB ID is not saved, the ID is resolved by name when you click a cover slot and is put into the SGDB ID field.

### Changed
* **"Default for all games" is now a lock button instead of a checkbox.** It has the same size and look as the eye and stands next to it in the row under the preview: *open lock* = off, *closed lock on the accent colour* = the logo position and size are saved as the defaults for all cards, ROMs and import. The old checkbox label is now the first line of the tooltip. The bottom row of the slot (label, eye, lock, slider) is centred in the free strip under the preview.
* **Moving games no longer keeps Steam closed during the copy.** `shortcuts.vdf` is not touched while files are being copied, so it always points to existing files and no rollback is needed. Steam is closed once, at the end, and only if at least one game was actually moved; the shortcuts of the moved games are fixed in one pass, then Steam is started again.
* **Battle.net games are launched by the client.** The shortcut sends the launch command to Battle.net (like the *Play* button), so Hearthstone and other games log in through the Blizzard service. If the client was not running, it is started first and the command is sent after about 12 s; the command is repeated up to 3 times every 25 s until the game appears. A direct start of the exe is only a fallback, after 75 s. `SCLauncher.exe` is regenerated automatically (helper version 35).
* Application version is now 2.0.6.

### Improved
* **Cover thumbnails download in parallel.** All images of a game (cover, header, background, logo, icon) are downloaded at the same time, one `curl.exe` per file, and each thumbnail appears in its slot as soon as its file is ready. Before, the files were downloaded one after another and their delays added up (a full set took about 10 s). The whole download is limited to 55 s, and a switch of the source or closing the card stops all running downloads.
* **SteamGridDB requests (grids, heroes, logos, icons) are sent together** instead of one by one for a game by Steam App ID and by SGDB ID, so their delays no longer add up. The `curl.exe` connect timeout is 5 s instead of 8 s.
* **SteamGridDB works for users whose `curl.exe` cannot reach `www.steamgriddb.com`.** After the first failure of `curl.exe` the requests go through the built-in .NET client (the mode is shared by all threads); if .NET stops reaching the server too, requests start with `curl.exe` again.
* **The loading animation of the thumbnails starts at once** when you switch the source (Steam / SteamGridDB), not after the network search of the game. If the search finishes without starting the loader (nothing found, error), the spinners are removed and the placeholders are shown.
* **Switching back to Steam from SteamGridDB** restores the remembered Steam App ID, the cover region and the title (including a localized one) if you did not edit the title yourself, with no search by name. The highlighted region button matches the region that was really loaded.
* **For a game already in the library, the full list of cover regions is loaded in the background right after the card opens** (when it is not saved in `cover_sources`), not by a click on the single button. Without a network the list stays pending and the click on the button retries.
* In the switch of the SGDB title the dropdown of title variants is filled after the covers are shown, so the covers and the *Add* button are no longer delayed by the search.

### Fixed
* **The progress bar of a game move was frozen at 100 % and reset while files were still copying**, and the percentage was rounded up before the move was finished. The percentage is now rounded down and cannot reach 100 % until the file is done; the progress bar is not hidden while the move is in progress. The size of the games to move is counted with a faster function.
* **The error window when adding an emulator no longer shows a debugging text** (exception text and script position); it shows the normal message again.
* Temporary timing code of the library opening (`Write-Tm` and counters) is removed; it only slowed the library down.

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
