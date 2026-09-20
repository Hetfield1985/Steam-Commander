# Contributing to Steam Commander

Thanks for your interest! Bug reports, ideas and pull requests are welcome.

## Reporting a bug
Open an issue using the **Bug report** template. Please include:
- Steam Commander version (shown in the window title and at the bottom of Settings);
- Windows version and UI language;
- steps to reproduce, and what you expected;
- for cover/search problems: the game title and its Steam App ID.

Never paste your SteamGridDB API key or `config.ini` into an issue.

## Running from source
```powershell
# elevated PowerShell
powershell -ExecutionPolicy Bypass -File .\src\Steam_Commander.ps1
```

## Coding notes
- **Encoding:** `src/Steam_Commander.ps1` must stay **UTF-8 with BOM** (it contains Cyrillic and CJK text; Windows PowerShell 5.1 misreads it otherwise). Keep CRLF line endings.
- **Single file by design:** the whole application lives in one script so it can be compiled to a single exe.
- **Localisation:** every user-visible string goes through `T 'key'` and lives in the `$script:I18n` table. Add the key to **all** languages. To add a language, add a branch to `$script:I18n` and an entry to `$script:languageList` (with the Steam language name used for localised covers).
- **App name/version:** change only `$global:appTitle` and `$global:appVersion`; the window title, Settings footer, User-Agent and build script all read them.
- **Small changes:** prefer small, focused pull requests over large refactors.
- **Steam data:** anything that writes `shortcuts.vdf` must be safe to run on a real library. Test on a copy or after making a backup from Settings.

## Pull requests
1. Fork and create a branch from `main`.
2. Make your change; update `CHANGELOG.md` under an *Unreleased* heading.
3. Describe what you changed and how you tested it.

## Releasing (maintainers)
1. Bump `$global:appVersion` in the script and update `CHANGELOG.md`.
2. Commit, then tag: `git tag v1.0.0 && git push --tags`.
3. The *Release* workflow builds the exe and attaches it to the GitHub release.
