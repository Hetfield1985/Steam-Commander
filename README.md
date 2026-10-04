<div align="center">

<img src="assets/icon/steam_commander_1024.png" alt="Steam Commander icon" width="128" height="128">

# Steam Commander

**Add non-Steam games and ROMs to Steam, import libraries from Epic / GOG / Ubisoft / EA / Battle.net / Xbox, set covers, configure launch options, and update DLSS / FSR / XeSS / XeLL — all in one window.**

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE)
![License](https://img.shields.io/badge/license-MIT-green)
[![Downloads](https://img.shields.io/github/downloads/Hetfield1985/Steam-Commander/total)](https://github.com/Hetfield1985/Steam-Commander/releases)

---

[![Download](https://img.shields.io/badge/Download-Steam%20Commander.exe-blue?style=for-the-badge)](https://github.com/Hetfield1985/Steam-Commander/releases/latest)

<p align="center">
  <a href="https://donatty.com/vitalibabinok"><img src="https://img.shields.io/badge/Donatty-Support-orange?style=for-the-badge" alt="Donatty"></a>
  <a href="https://destream.net/live/VitaliBabinok"><img src="https://img.shields.io/badge/DeStream-Support-blueviolet?style=for-the-badge" alt="DeStream"></a>
  <a href="https://boosty.to/babinok/donate"><img src="https://img.shields.io/badge/Boosty-Support-f15f2c?style=for-the-badge" alt="Boosty"></a>
  <a href="#support"><img src="https://img.shields.io/badge/USDT-ERC20%20%7C%20TRC20%20%7C%20BEP20-26A17B?style=for-the-badge" alt="USDT"></a>
</p>

<p align="center">
  <a href="README.ru.md">Русский</a> · <b>English</b>
</p>

---

</div>

## What the program can do

### Adding games to Steam

Add non-Steam games to your Steam library with automatic detection of the game title, EXE file, convenient selection of official launch parameters (or your own), and a full set of covers from two selectable sources (Steam + SteamGridDB). Batch adding with auto-fill for all data the program is confident about; when detection is uncertain, it asks the user for the missing details. Built-in Steam game title database — used for more accurate search, contains all games as of the program’s release; for precise search of new games, it is recommended to obtain and enter your own API key (see Settings).

<p align="center">
  <img src="assets/screenshots/add_games.gif" width="700" alt="Adding games to Steam">
</p>

### Import from launchers

Epic Games, GOG Galaxy, Ubisoft Connect, EA App, Battle.net, Xbox. Import selected games into Steam (manual and automatic). Cover customization is also available. Launch uses a built-in silent launcher that ensures the third-party launcher starts in quiet mode, focuses the game, and closes the third-party launcher after the game exits — so it feels like you are playing a Steam game rather than one from another launcher.

<p align="center">
  <img src="assets/screenshots/import_launchers.gif" width="700" alt="Import from launchers">
</p>

### Automatic import

For those who want to save time: with the auto-import option enabled, you can add games in large numbers very quickly with no interaction during the process.

<p align="center">
  <img src="assets/screenshots/auto_import.gif" width="700" alt="Automatic import">
</p>

### ROMs mode and emulators

Panels show folders and ROM files filtered by the active emulator’s extensions. Emulator manager, RetroArch support with core selection, archives (zip, 7z, rar, and others) with temporary extraction.

<p align="center">
  <img src="assets/screenshots/roms_emulators.gif" width="700" alt="ROMs mode and emulators">
</p>

### Upscaler libraries

Download and choose versions of DLSS / FSR / XeSS / XeLL. Replace libraries in selected games. Originals are kept as `.sc_orig` and can be restored in one action.

<p align="center">
  <img src="assets/screenshots/upscalers.gif" width="700" alt="Upscaler libraries">
</p>

### Two-panel browser

Two independent panels (any folders / drives). Search, sorting, folder sizes, “already in Steam” marker with the game icon. Move game folders and ROMs between panels with progress and Steam shortcut path updates. Smart move works both ways between folders/drives.

<p align="center">
  <img src="assets/screenshots/two_panels.gif" width="700" alt="Two-panel browser">
</p>

### Library editing

Edit non-Steam and licensed Steam games (covers, launch parameters). Backup and restore of `shortcuts.vdf`.

<p align="center">
  <img src="assets/screenshots/edit_library.gif" width="700" alt="Library editing">
</p>

---

## System requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (only when running the `.ps1`)
- Steam installed (and launched at least once)
- **Administrator rights**
- Internet — for game search, covers, and downloading upscalers
- Optional: [Steam Web API key](https://steamcommunity.com/dev/apikey) and [SteamGridDB API key](https://www.steamgriddb.com/profile/preferences)
- For ROM archives: 7-Zip (the program may offer to download it)

---

## Installation

### Ready-made exe
1. Download `Steam Commander.exe` from the [Releases](../../releases) page
2. Run it (the program will request administrator rights)

### Script
```powershell
# PowerShell run as administrator
powershell -ExecutionPolicy Bypass -File .\src\Steam_Commander.ps1
```

### Building the exe
```powershell
Install-Module ps2exe -Scope CurrentUser   # once
.\build\build.ps1
```
Result — `dist\Steam Commander.exe`.

---

## Initial setup

1. Open **Settings** → set the Steam folder and `userdata` profile
2. *(Optional)* Add Steam Web API and SteamGridDB API keys
3. If needed, add emulators and download upscaler libraries
4. Add emulator profiles with the path to the exe

> When writing to `shortcuts.vdf`, the program closes Steam and starts it again. Close running games and wait for Steam sync to finish before the operation.

---

## Keyboard shortcuts

| Key | Action |
|---|---|
| Double-click / **Enter** | Open game card |
| **Space** | Folder size / selected items |
| **Delete** | Remove from list (files on disk are not touched) |
| **Ctrl+A** | Select all in the panel |
| **Esc** | Close the card |
| **Alt+Shift+Enter** | Size of all folders in the panel |
| **F5** | Refresh panels |

---

## Where data is stored

| What | Where |
|---|---|
| Settings, emulator profiles | `%APPDATA%\Steam Commander` |
| Steam games database | `%APPDATA%\Steam Commander\steam_apps_db.json` |
| Upscaler libraries | `%APPDATA%\Steam Commander` |
| Language files | `%APPDATA%\Steam Commander\lang` |
| `shortcuts.vdf` backups | `backups` folder next to the exe |
| Temporary files | `%TEMP%\SteamCommander` |
| Steam shortcuts and covers | `Steam\userdata\<id>\config\` |

API keys are stored in plain text in `config.ini` — do not share this file.

---

## Privacy and network

No telemetry. The program only contacts:

- `store.steampowered.com`, `api.steampowered.com`, `*.steamstatic.com`
- `api.steamcmd.net`
- `www.steamgriddb.com` (when a key is set)
- upscaler library sources

---

## Project structure

```text
Steam-Commander/
├── src/Steam_Commander.ps1
├── build/build.ps1
├── assets/icon/
├── .github/
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## Known limitations

- For new or obscure games, Steam covers may be missing — SteamGridDB helps
- Title matching is heuristic; confidence indicators show when to check manually
- Launcher import depends on how each launcher stores installed-game data
- Windows only

---

## Contributing

Bug reports and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).  
You can also add language files in the `lang` folder.

---

## Disclaimer

Steam Commander is an unofficial community project. It is not affiliated with, endorsed by, or sponsored by Valve Corporation.  
*Steam* and the Steam logo are trademarks of Valve Corporation.  
Covers belong to their respective owners. The application icon is an original design.

The program modifies `shortcuts.vdf` and may replace upscaler DLLs. Use at your own risk. Create a backup before large operations.

---

## License

[MIT](LICENSE)

---

## Support

If you find Steam Commander useful:

- [Donatty](https://donatty.com/vitalibabinok)
- [DeStream](https://destream.net/live/VitaliBabinok)
- [Boosty](https://boosty.to/babinok/donate)

**USDT** (minimum 5 USDT):

- ERC-20: `0x2503cdb205ac6e41222e114d77b0dcc48ed83686`
- TRC-20: `TSE4BZQC6h9qES2QsgJjcfyDbGYNDATSv4`
- BEP-20: `0x2503cdb205ac6e41222e114d77b0dcc48ed83686`

Send USDT only via the network listed next to the address. Transfers under 5 USDT or via another network will be lost.
