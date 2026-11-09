// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get addSheet => 'Add sheet';

  @override
  String get alignBottom => 'Align bottom';

  @override
  String get alignCenter => 'Center';

  @override
  String get alignLeft => 'Align left';

  @override
  String get alignMiddle => 'Align middle';

  @override
  String get alignRight => 'Align right';

  @override
  String get alignTop => 'Align top';

  @override
  String get alignmentGroup => 'Alignment';

  @override
  String get allBorders => 'All borders';

  @override
  String get apply => 'Apply';

  @override
  String get autoSum => 'AutoSum';

  @override
  String get autoSumHint => 'Sum of the numbers above or to the left';

  @override
  String get automaticColor => 'Automatic';

  @override
  String get average => 'Average';

  @override
  String get bold => 'Bold';

  @override
  String get bottomBorder => 'Bottom border';

  @override
  String get cancel => 'Cancel';

  @override
  String get cellsGroup => 'Cells';

  @override
  String get clearContents => 'Clear contents';

  @override
  String get clearFormats => 'Clear formats';

  @override
  String get clipboardGroup => 'Clipboard';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get count => 'Count';

  @override
  String get csvOnlyActiveSheet =>
      'CSV keeps only the values of the open sheet.';

  @override
  String get cut => 'Cut';

  @override
  String get dataGroup => 'Data';

  @override
  String get deleteSheet => 'Delete sheet';

  @override
  String get dontSave => 'Don\'t save';

  @override
  String get fewerDecimals => 'Fewer decimals';

  @override
  String get fileMenu => 'File';

  @override
  String get fillColor => 'Fill color';

  @override
  String get fontGroup => 'Font';

  @override
  String get fontSize => 'Font size';

  @override
  String get formatCurrency => 'Currency';

  @override
  String get formatDate => 'Date';

  @override
  String get formatDateTime => 'Date and time';

  @override
  String get formatGeneral => 'General';

  @override
  String get formatNumber => 'Number';

  @override
  String get formatPercent => 'Percentage';

  @override
  String get formatText => 'Text';

  @override
  String get formatTime => 'Time';

  @override
  String get formulaBarHint => 'Type a value or a formula, like =SUM(A1:A5)';

  @override
  String get freezePanes => 'Freeze above and left of the active cell';

  @override
  String get freezeTopRow => 'Freeze top row';

  @override
  String get invalidSheetName => 'Up to 31 characters, without : \\ / ? * [ ]';

  @override
  String get italic => 'Italic';

  @override
  String get language => 'Language';

  @override
  String get maximize => 'Maximize';

  @override
  String get minimize => 'Minimize';

  @override
  String get moreDecimals => 'More decimals';

  @override
  String get newFile => 'New';

  @override
  String get noBorders => 'No borders';

  @override
  String get noFill => 'No fill';

  @override
  String get nothingToPaste => 'Nothing to paste.';

  @override
  String get numberFormat => 'Number format';

  @override
  String get numberGroup => 'Number';

  @override
  String get openFailed => 'This file could not be opened.';

  @override
  String get openFile => 'Open';

  @override
  String get openFileTitle => 'Open spreadsheet';

  @override
  String get paste => 'Paste';

  @override
  String get redo => 'Redo';

  @override
  String get renameSheet => 'Rename sheet';

  @override
  String get restore => 'Restore';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save as';

  @override
  String get saveChangesTitle => 'Save changes?';

  @override
  String get saveFailed => 'The file could not be saved.';

  @override
  String get saveFileTitle => 'Save spreadsheet';

  @override
  String get sheetNameTaken => 'Another sheet already has this name.';

  @override
  String get sortAscending => 'Sort A to Z';

  @override
  String get sortDescending => 'Sort Z to A';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get sum => 'Sum';

  @override
  String get systemLanguage => 'System language';

  @override
  String get textColor => 'Text color';

  @override
  String get underline => 'Underline';

  @override
  String get undo => 'Undo';

  @override
  String get unfreeze => 'Unfreeze';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get unsupportedFormat =>
      'This kind of file can\'t be opened yet. Save it as .xlsx or .csv in the other program.';

  @override
  String get untitled => 'Untitled';

  @override
  String get wrapText => 'Wrap text';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String deleteSheetMessage(String name) {
    return 'Delete the sheet \"$name\"? This can\'t be undone.';
  }

  @override
  String saveAsFormat(String format) {
    return 'Save as $format';
  }

  @override
  String saveChangesMessage(String name) {
    return 'Do you want to save the changes to \"$name\"?';
  }

  @override
  String sheetName(int number) {
    return 'Sheet$number';
  }
}
