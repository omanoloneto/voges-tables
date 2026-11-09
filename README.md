# Voges Tables

A simple spreadsheet for the desktop: type numbers and text, write formulas, format cells, and open and save `.xlsx` and `.csv`. Part of the Voges suite, next to [Voges Word](https://github.com/omanoloneto/voges-word) and [Voges Pencil](https://github.com/omanoloneto/voges-pencil). Built with Flutter for macOS, Windows and Linux.

Installers are not published yet; for now, build it from the source (see [Build](#build)).

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
- **Editing:** copy, cut and paste inside the app (formulas follow the cells, as in Excel) and from other programs (tab-separated text); the fill handle continues number series and copies formulas; AutoSum; sort A to Z and Z to A; undo and redo for every change.
- **Sheets:** several sheets per file; add, rename (double click on the tab) and delete them. Resize columns and rows by dragging the header borders (a double click fits the column to its text), and freeze the top row or the rows and columns before the active cell.
- **Keyboard:** arrows, Enter, Tab, Page Up/Down, Home, Ctrl or ⌘ with the arrows to jump to the edge of the data, F2 to edit, Delete to clear, Esc to cancel.
- **Files:** opens `.xlsx`, `.xlsm` (without the macros), `.csv`, `.tsv` and `.txt`; saves `.xlsx` and `.csv`. CSV files use `;` in Portuguese and Spanish, as Excel does there, and are read with any separator and encoding. `.xls`, `.xlsb` and `.ods` are not supported yet.
- The status bar shows the sum, the average and the count of the selected cells, and the zoom (25% to 400%; Ctrl or ⌘ with the mouse wheel, or a pinch on the trackpad).
- Warns before closing or opening another file with unsaved changes, and opens files from the system's "Open with" and from the command line.
- Interface in English, Portuguese and Spanish. It follows the system language, and you can pick another one in the File menu.

## Build

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.41 or newer.

```sh
flutter pub get
flutter run -d macos     # or windows, linux
flutter test
```

