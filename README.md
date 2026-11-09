# Voges Tables

A simple spreadsheet for the desktop: type numbers and text, write formulas, format cells, and open and save `.xlsx` and `.csv`. Part of the Voges suite, next to [Voges Word](https://github.com/omanoloneto/voges-word) and [Voges Pencil](https://github.com/omanoloneto/voges-pencil). Built with Flutter for macOS, Windows and Linux.

## Install

The installers are in the [latest release](https://github.com/omanoloneto/voges-tables/releases/latest) and on the [omanoloneto.pro/voges/tables](https://omanoloneto.pro/voges/tables/) page.

- **macOS** 10.15 or newer, Apple Silicon and Intel: [`VogesTables-macos.dmg`](https://github.com/omanoloneto/voges-tables/releases/latest/download/VogesTables-macos.dmg). Open it and drag Voges Tables to Applications. The app is not notarized by Apple; the first time, allow it in System Settings → Privacy & Security → Open Anyway.
- **Windows** 10 or 11, 64-bit: [`VogesTables-windows-setup.exe`](https://github.com/omanoloneto/voges-tables/releases/latest/download/VogesTables-windows-setup.exe). It installs without administrator rights and shows up in "Open with" for `.xlsx`, `.xlsm`, `.csv` and `.tsv`, without becoming the default program. If SmartScreen warns you, click "More info" and then "Run anyway".
- **Linux** (Ubuntu 22.04, Debian 12 or newer and derivatives, 64-bit): [`voges-tables-linux-amd64.deb`](https://github.com/omanoloneto/voges-tables/releases/latest/download/voges-tables-linux-amd64.deb), then `sudo apt install ./voges-tables-linux-amd64.deb`.

`SHA256SUMS.txt` in each release lists the SHA-256 of every installer, and `SHA256SUMS.txt.sig` is its signature.

### Updates

Voges Tables checks for a new version every time it opens and says in the status bar whether it is up to date. When there is an update, clicking it asks about unsaved changes, closes the app and opens **Voges Updater**, which lists every installed app of the Voges suite that has an update; update all of them or only some. When it finishes, Voges Tables opens again.

- The check reads the number of the latest release from github.com; nothing about you or your spreadsheets is sent.
- Every update is verified before it is installed: its files must match the `SHA256SUMS.txt` of the release, and that file must carry the Ed25519 signature of the project's key, which is built into the app. A download that doesn't match is never installed.
- **macOS:** the updater replaces the app in its folder; if your account can't write to it, it puts the verified `.dmg` in Downloads for you to install. Voges Tables stays sandboxed: the updater is a separate app inside it (`Contents/Helpers/Voges Updater.app`).
- **Windows:** the installer runs silently; installs for all users ask for administrator permission.
- **Linux:** the update is installed with `apt`, after the system asks for your password (polkit). Without a password window, the updater shows the command to run in a terminal.

## What it does

- **Cells:** type numbers, text, dates, times, percentages and money the way you would in Excel in your language (`10,5`, `05/11/2026` and `R$ 5,50` in Portuguese; `10.5`, `11/5/2026` and `$5.50` in English). Text wider than its cell spills over empty neighbors, and numbers that don't fit show `###`.
- **Formulas:** about 90 functions, typed with the names of your language: `=SOMA(A1:A5)` and `=PROCV(...)` in Portuguese, `=SUMA(...)` and `=BUSCARV(...)` in Spanish, `=SUM(...)` and `=VLOOKUP(...)` in English (English names work in every language). Files always store the English names, so they open in any spreadsheet program.
  - Math and statistics: SUM, AVERAGE, MIN, MAX, COUNT, COUNTA, COUNTBLANK, COUNTIF(S), SUMIF(S), AVERAGEIF, ROUND, ROUNDUP, ROUNDDOWN, INT, TRUNC, ABS, MOD, POWER, SQRT, PI, PRODUCT, RAND, RANDBETWEEN, MEDIAN, MODE, STDEV, VAR, LARGE, SMALL, RANK.
  - Logic: IF, IFS, IFERROR, AND, OR, NOT, XOR.
  - Lookup: VLOOKUP, HLOOKUP, XLOOKUP, MATCH, INDEX, CHOOSE, ROW, COLUMN, ROWS, COLUMNS.
  - Text: LEN, LEFT, RIGHT, MID, UPPER, LOWER, PROPER, TRIM, CONCATENATE, CONCAT, TEXTJOIN, TEXT, VALUE, FIND, SEARCH, SUBSTITUTE, REPT, EXACT.
  - Dates: TODAY, NOW, DATE, YEAR, MONTH, DAY, WEEKDAY, DATEDIF, DAYS, EDATE, EOMONTH, HOUR, MINUTE, SECOND, TIME.
  - Information: ISBLANK, ISNUMBER, ISTEXT, ISERROR, ISNA, NA.
  - References like `A1`, `$A$1`, `A1:B5`, `A:A`, `1:3` and other sheets (`Notas!B2`, `'My sheet'!A1:A9`). Only the cells that depend on a change are calculated again; circular references show `#CIRC!`.
  - While typing a formula, clicking or dragging over cells writes their reference.
- **Formatting:** bold, italic, underline, strikethrough, font size, text and fill colors, horizontal and vertical alignment, wrap text, borders, and number formats (general, number, currency, percentage, date, time, date and time, text) with more or fewer decimals.
- **Editing:** copy, cut and paste inside the app (formulas and merged cells follow the cells, as in Excel) and from other programs (tab-separated text); the fill handle continues number series and copies formulas; AutoSum; sort A to Z and Z to A; undo and redo for every change.
- **Rows and columns:** insert and delete whole rows or columns from the ribbon, the right-click menu or Ctrl/⌘+Shift+= and Ctrl/⌘+Shift+-. References in every sheet follow, as in Excel: ranges across the edit grow or shrink and references to deleted cells become `#REF!`.
- **Merged cells:** Merge & Center and unmerge; selections, arrows and typing treat a merge as one cell.
- **Find and replace:** Ctrl/⌘+F and Ctrl/⌘+H, with match case, whole cell, Excel wildcards (`*`, `?`, `~`) and a search in formulas; Replace all is one undo step.
- **Charts:** column, bar, line, area, pie and scatter charts from the selection, or from the block around the active cell. Text headers name the series and a text first column gives the categories, as Excel does. Drag to move, use the handles to resize, and change the type, the title and the legend from the chart's toolbar. Charts follow inserted and deleted rows and columns.
- **Sheets:** several sheets per file; add, rename (double click on the tab) and delete them. Resize columns and rows by dragging the header borders (a double click fits the column to its text), and freeze the top row or the rows and columns before the active cell.
- **Keyboard:** arrows, Enter, Tab, Page Up/Down, Home, Ctrl or ⌘ with the arrows to jump to the edge of the data, F2 to edit, Delete to clear, Esc to cancel.
- **Files:** opens `.xlsx`, `.xlsm` (without the macros), `.csv`, `.tsv` and `.txt`; saves `.xlsx` and `.csv`. Merged cells and charts are kept in `.xlsx`; charts of other kinds that Excel makes (radar, bubble, stock...) are left out when opening. CSV files use `;` in Portuguese and Spanish, as Excel does there, and are read with any separator and encoding. `.xls`, `.xlsb` and `.ods` are not supported yet.
- The status bar shows the sum, the average and the count of the selected cells, and the zoom (25% to 400%; Ctrl or ⌘ with the mouse wheel, or a pinch on the trackpad).
- Warns before closing or opening another file with unsaved changes, and opens files from the system's "Open with" (on macOS and, through the installers, Windows and Linux, without becoming the default app) and from the command line.
- Updates itself on macOS, Windows and Linux: the status bar shows when a new version exists (see [Updates](#updates)).
- Interface in English, Portuguese and Spanish. It follows the system language, and you can pick another one in the File menu.

## Build

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.41 or newer.

```sh
flutter pub get --enforce-lockfile
flutter run -d macos     # or windows, linux
flutter test
```

Updates come from the `voges_updater` package of [Voges Word](https://github.com/omanoloneto/voges-word/tree/main/packages/voges_updater), a git dependency pinned to a commit in `pubspec.yaml` and `pubspec.lock`; `--enforce-lockfile` gets the locked commit.

## Releases

1. Set the new `version` in `pubspec.yaml` and write `packaging/release-notes.md`.
2. Push a `vX.Y.Z` tag with the same version. `.github/workflows/release.yml` builds the three installers (the macOS one with Voges Updater embedded) and creates a draft release with them and `SHA256SUMS.txt`.
3. Sign and publish the draft on the owner's Mac, from a Voges Word checkout:

   ```sh
   cd packages/voges_updater
   dart run tool/release_signing.dart publish omanoloneto/voges-tables vX.Y.Z --clone <path to the voges-tables clone>
   ```

Release builds pass `--dart-define=VOGES_VERSION=<version>`; without it, as in `flutter run`, the update indicator stays hidden.

