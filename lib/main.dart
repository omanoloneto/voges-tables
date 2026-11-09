import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voges_updater/voges_updater.dart'
    show UpdateCheck, UpdaterRequest, runUpdater, vogesTables;
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'files/spreadsheet_files.dart';
import 'files/system_open.dart';
import 'formula/locale.dart';
import 'l10n/app_language.dart';
import 'sheet/workbook.dart';
import 'shell/platform.dart';
import 'shell/title_bar.dart';
import 'shell/window_buttons.dart';
import 'workbook/workbook_controller.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // On Windows and Linux a copy of the app itself is the updater; on macOS
  // the updater is a separate app, because this one is sandboxed.
  if (!kIsWeb &&
      UpdaterRequest.isUpdaterLaunch(arguments, defaultTargetPlatform.name)) {
    final language = AppLanguage();
    await language.load();
    return runUpdater(
      arguments: arguments,
      host: vogesTables,
      locale: language.locale,
    );
  }
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'Voges Tables',
        size: Size(1280, 860),
        minimumSize: Size(640, 480),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
      ),
      () async {
        await placeNativeWindowButtons(titleBarHeight);
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final language = AppLanguage();
  await language.load();
  final files = SpreadsheetFiles();
  final controller = WorkbookController(
    workbook: Workbook.blank(
      firstSheetName(
        language.resolve(WidgetsBinding.instance.platformDispatcher.locales),
      ),
    ),
    locale: () => FormulaLocale.en,
  );

  runApp(
    VogesTablesApp(
      controller: controller,
      files: files,
      systemOpen: SystemOpen(files),
      language: language,
      launchArguments: arguments,
      windowButtons: await WindowButtonsLayout.forPlatform(),
      updates: isDesktopPlatform ? UpdateCheck.forPlatform(vogesTables) : null,
    ),
  );
}

/// The first sheet is named in the interface language, as Excel does.
String firstSheetName(Locale locale) => switch (locale.languageCode) {
  'pt' => 'Planilha1',
  'es' => 'Hoja1',
  _ => 'Sheet1',
};
