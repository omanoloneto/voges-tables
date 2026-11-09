import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @addSheet.
  ///
  /// In en, this message translates to:
  /// **'Add sheet'**
  String get addSheet;

  /// No description provided for @alignBottom.
  ///
  /// In en, this message translates to:
  /// **'Align bottom'**
  String get alignBottom;

  /// No description provided for @alignCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get alignCenter;

  /// No description provided for @alignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align left'**
  String get alignLeft;

  /// No description provided for @alignMiddle.
  ///
  /// In en, this message translates to:
  /// **'Align middle'**
  String get alignMiddle;

  /// No description provided for @alignRight.
  ///
  /// In en, this message translates to:
  /// **'Align right'**
  String get alignRight;

  /// No description provided for @alignTop.
  ///
  /// In en, this message translates to:
  /// **'Align top'**
  String get alignTop;

  /// No description provided for @alignmentGroup.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get alignmentGroup;

  /// No description provided for @allBorders.
  ///
  /// In en, this message translates to:
  /// **'All borders'**
  String get allBorders;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @autoSum.
  ///
  /// In en, this message translates to:
  /// **'AutoSum'**
  String get autoSum;

  /// No description provided for @autoSumHint.
  ///
  /// In en, this message translates to:
  /// **'Sum of the numbers above or to the left'**
  String get autoSumHint;

  /// No description provided for @automaticColor.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automaticColor;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @bottomBorder.
  ///
  /// In en, this message translates to:
  /// **'Bottom border'**
  String get bottomBorder;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cellsGroup.
  ///
  /// In en, this message translates to:
  /// **'Cells'**
  String get cellsGroup;

  /// No description provided for @clearContents.
  ///
  /// In en, this message translates to:
  /// **'Clear contents'**
  String get clearContents;

  /// No description provided for @clearFormats.
  ///
  /// In en, this message translates to:
  /// **'Clear formats'**
  String get clearFormats;

  /// No description provided for @clipboardGroup.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboardGroup;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @count.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get count;

  /// No description provided for @csvOnlyActiveSheet.
  ///
  /// In en, this message translates to:
  /// **'CSV keeps only the values of the open sheet.'**
  String get csvOnlyActiveSheet;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @dataGroup.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataGroup;

  /// No description provided for @deleteSheet.
  ///
  /// In en, this message translates to:
  /// **'Delete sheet'**
  String get deleteSheet;

  /// No description provided for @dontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get dontSave;

  /// No description provided for @fewerDecimals.
  ///
  /// In en, this message translates to:
  /// **'Fewer decimals'**
  String get fewerDecimals;

  /// No description provided for @fileMenu.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileMenu;

  /// No description provided for @fillColor.
  ///
  /// In en, this message translates to:
  /// **'Fill color'**
  String get fillColor;

  /// No description provided for @fontGroup.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontGroup;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @formatCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get formatCurrency;

  /// No description provided for @formatDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get formatDate;

  /// No description provided for @formatDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get formatDateTime;

  /// No description provided for @formatGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get formatGeneral;

  /// No description provided for @formatNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get formatNumber;

  /// No description provided for @formatPercent.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get formatPercent;

  /// No description provided for @formatText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get formatText;

  /// No description provided for @formatTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get formatTime;

  /// No description provided for @formulaBarHint.
  ///
  /// In en, this message translates to:
  /// **'Type a value or a formula, like =SUM(A1:A5)'**
  String get formulaBarHint;

  /// No description provided for @freezePanes.
  ///
  /// In en, this message translates to:
  /// **'Freeze above and left of the active cell'**
  String get freezePanes;

  /// No description provided for @freezeTopRow.
  ///
  /// In en, this message translates to:
  /// **'Freeze top row'**
  String get freezeTopRow;

  /// No description provided for @invalidSheetName.
  ///
  /// In en, this message translates to:
  /// **'Up to 31 characters, without : \\ / ? * [ ]'**
  String get invalidSheetName;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @moreDecimals.
  ///
  /// In en, this message translates to:
  /// **'More decimals'**
  String get moreDecimals;

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newFile;

  /// No description provided for @noBorders.
  ///
  /// In en, this message translates to:
  /// **'No borders'**
  String get noBorders;

  /// No description provided for @noFill.
  ///
  /// In en, this message translates to:
  /// **'No fill'**
  String get noFill;

  /// No description provided for @nothingToPaste.
  ///
  /// In en, this message translates to:
  /// **'Nothing to paste.'**
  String get nothingToPaste;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get numberFormat;

  /// No description provided for @numberGroup.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get numberGroup;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'This file could not be opened.'**
  String get openFailed;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @openFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Open spreadsheet'**
  String get openFileTitle;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @renameSheet.
  ///
  /// In en, this message translates to:
  /// **'Rename sheet'**
  String get renameSheet;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get saveAs;

  /// No description provided for @saveChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get saveChangesTitle;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be saved.'**
  String get saveFailed;

  /// No description provided for @saveFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Save spreadsheet'**
  String get saveFileTitle;

  /// No description provided for @sheetNameTaken.
  ///
  /// In en, this message translates to:
  /// **'Another sheet already has this name.'**
  String get sheetNameTaken;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Sort A to Z'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Sort Z to A'**
  String get sortDescending;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// No description provided for @sum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get sum;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get systemLanguage;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get textColor;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @unfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze'**
  String get unfreeze;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @unsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'This kind of file can\'t be opened yet. Save it as .xlsx or .csv in the other program.'**
  String get unsupportedFormat;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @wrapText.
  ///
  /// In en, this message translates to:
  /// **'Wrap text'**
  String get wrapText;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @deleteSheetMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete the sheet \"{name}\"? This can\'t be undone.'**
  String deleteSheetMessage(String name);

  /// No description provided for @saveAsFormat.
  ///
  /// In en, this message translates to:
  /// **'Save as {format}'**
  String saveAsFormat(String format);

  /// No description provided for @saveChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save the changes to \"{name}\"?'**
  String saveChangesMessage(String name);

  /// No description provided for @sheetName.
  ///
  /// In en, this message translates to:
  /// **'Sheet{number}'**
  String sheetName(int number);

  /// No description provided for @insertCells.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insertCells;

  /// No description provided for @deleteCells.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteCells;

  /// No description provided for @insertRows.
  ///
  /// In en, this message translates to:
  /// **'Insert rows'**
  String get insertRows;

  /// No description provided for @insertColumns.
  ///
  /// In en, this message translates to:
  /// **'Insert columns'**
  String get insertColumns;

  /// No description provided for @deleteRows.
  ///
  /// In en, this message translates to:
  /// **'Delete rows'**
  String get deleteRows;

  /// No description provided for @deleteColumns.
  ///
  /// In en, this message translates to:
  /// **'Delete columns'**
  String get deleteColumns;

  /// No description provided for @insertNoRoom.
  ///
  /// In en, this message translates to:
  /// **'There is no room: the last rows or columns of the sheet have data.'**
  String get insertNoRoom;

  /// No description provided for @mergeCenter.
  ///
  /// In en, this message translates to:
  /// **'Merge & Center'**
  String get mergeCenter;

  /// No description provided for @unmergeCells.
  ///
  /// In en, this message translates to:
  /// **'Unmerge cells'**
  String get unmergeCells;

  /// No description provided for @mergeClearsData.
  ///
  /// In en, this message translates to:
  /// **'Merging keeps only the value of the top left cell. Merge anyway?'**
  String get mergeClearsData;

  /// No description provided for @mergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergeAction;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceAll;

  /// No description provided for @replaceWith.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceWith;

  /// No description provided for @findNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get findNext;

  /// No description provided for @findPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get findPrevious;

  /// No description provided for @matchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get matchCase;

  /// No description provided for @wholeCell.
  ///
  /// In en, this message translates to:
  /// **'Match the whole cell'**
  String get wholeCell;

  /// No description provided for @lookInFormulas.
  ///
  /// In en, this message translates to:
  /// **'Search in formulas'**
  String get lookInFormulas;

  /// No description provided for @findResult.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String findResult(int current, int total);

  /// No description provided for @findNone.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get findNone;

  /// No description provided for @replacedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing replaced} =1{1 cell replaced} other{{count} cells replaced}}'**
  String replacedCount(int count);

  /// No description provided for @chartGroup.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get chartGroup;

  /// No description provided for @insertChart.
  ///
  /// In en, this message translates to:
  /// **'Insert chart'**
  String get insertChart;

  /// No description provided for @chartColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get chartColumn;

  /// No description provided for @chartBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get chartBar;

  /// No description provided for @chartLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get chartLine;

  /// No description provided for @chartArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get chartArea;

  /// No description provided for @chartPie.
  ///
  /// In en, this message translates to:
  /// **'Pie'**
  String get chartPie;

  /// No description provided for @chartScatter.
  ///
  /// In en, this message translates to:
  /// **'Scatter'**
  String get chartScatter;

  /// No description provided for @chartType.
  ///
  /// In en, this message translates to:
  /// **'Chart type'**
  String get chartType;

  /// No description provided for @chartTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart title'**
  String get chartTitle;

  /// No description provided for @chartLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get chartLegend;

  /// No description provided for @deleteChart.
  ///
  /// In en, this message translates to:
  /// **'Delete chart'**
  String get deleteChart;

  /// No description provided for @chartNoNumbers.
  ///
  /// In en, this message translates to:
  /// **'Select cells with numbers to make a chart.'**
  String get chartNoNumbers;

  /// No description provided for @chartNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get chartNoData;

  /// No description provided for @chartSeries.
  ///
  /// In en, this message translates to:
  /// **'Series {number}'**
  String chartSeries(int number);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
