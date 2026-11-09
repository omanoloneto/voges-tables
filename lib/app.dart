import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:voges_updater/voges_updater.dart'
    show UpdateCheck, UpdaterLocalizations;

import 'editor/editor_screen.dart';
import 'files/spreadsheet_files.dart';
import 'files/system_open.dart';
import 'l10n/app_language.dart';
import 'l10n/l10n.dart';
import 'shell/window_buttons.dart';
import 'workbook/workbook_controller.dart';

const brandColor = Color(0xFF1D6B3E);

class VogesTablesApp extends StatelessWidget {
  const VogesTablesApp({
    required this.controller,
    required this.files,
    required this.systemOpen,
    required this.language,
    required this.launchArguments,
    this.windowButtons = WindowButtonsLayout.right,
    this.updates,
    super.key,
  });

  final WorkbookController controller;
  final SpreadsheetFiles files;
  final SystemOpen systemOpen;
  final AppLanguage language;
  final List<String> launchArguments;
  final WindowButtonsLayout windowButtons;
  final UpdateCheck? updates;

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    ),
    visualDensity: VisualDensity.standard,
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: language,
      builder: (context, _) => MaterialApp(
        title: 'Voges Tables',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: language.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          UpdaterLocalizations.delegate,
        ],
        home: EditorScreen(
          controller: controller,
          files: files,
          systemOpen: systemOpen,
          language: language,
          launchArguments: launchArguments,
          windowButtons: windowButtons,
          updates: updates,
        ),
      ),
    );
  }
}
