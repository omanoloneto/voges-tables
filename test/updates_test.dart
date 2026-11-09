import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voges_tables/app.dart';
import 'package:voges_tables/files/spreadsheet_files.dart';
import 'package:voges_tables/files/system_open.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/l10n/app_language.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:voges_tables/workbook/selection.dart';
import 'package:voges_tables/workbook/workbook_controller.dart';
import 'package:voges_updater/voges_updater.dart'
    show
        LaunchAvailability,
        LaunchResult,
        ReleaseFeed,
        ReleaseVersion,
        UpdateCheck,
        UpdaterLauncher,
        vogesTables;

Future<WorkbookController> _pump(
  WidgetTester tester, {
  required UpdateCheck updates,
  Locale? locale,
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = WorkbookController(
    workbook: Workbook.blank('Sheet1'),
    locale: () => FormulaLocale.en,
  );
  final files = SpreadsheetFiles();
  await tester.pumpWidget(
    VogesTablesApp(
      controller: controller,
      files: files,
      systemOpen: SystemOpen(files),
      language: AppLanguage(locale),
      launchArguments: const [],
      updates: updates,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

final class _Feed implements ReleaseFeed {
  const _Feed(this.version);

  final ReleaseVersion version;

  @override
  Future<ReleaseVersion> latest(String repository) async => version;
}

final class _OfflineFeed implements ReleaseFeed {
  const _OfflineFeed();

  @override
  Future<ReleaseVersion> latest(String repository) async =>
      throw const SocketException('offline');
}

final class _Launcher implements UpdaterLauncher {
  _Launcher(this.result, {this.opening});

  final LaunchResult result;

  /// Holds the launch open until completed, like the Windows copy does.
  final Completer<LaunchResult>? opening;
  var launches = 0;

  @override
  LaunchAvailability get availability => LaunchAvailability.here;

  @override
  Future<LaunchResult> launch() async {
    launches++;
    return opening?.future ?? result;
  }

  @override
  Future<void> cleanUp() async {}
}

UpdateCheck _updates(
  _Launcher launcher, {
  ReleaseFeed feed = const _Feed(ReleaseVersion(9, 9, 9)),
}) => UpdateCheck(
  app: vogesTables,
  current: const ReleaseVersion(1, 0, 0),
  feed: feed,
  launcher: launcher,
);

/// The calls the app makes to the window, such as `destroy`.
List<String> _recordWindowCalls() {
  final calls = <String>[];
  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

void _change(WorkbookController controller) =>
    controller.enter(const CellAddress(0, 0), '${controller.revision + 1}');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the status bar says when the app is up to date', (tester) async {
    await _pump(
      tester,
      updates: _updates(
        _Launcher(LaunchResult.started),
        feed: const _Feed(ReleaseVersion(1, 0, 0)),
      ),
    );

    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets('a long status fits the smallest window', (tester) async {
    await _pump(
      tester,
      size: const Size(640, 480),
      locale: const Locale('pt'),
      updates: _updates(
        _Launcher(LaunchResult.started),
        feed: const _OfflineFeed(),
      ),
    );

    expect(find.text('Não foi possível procurar atualizações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long status shrinks to leave room for the totals', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      size: const Size(1000, 700),
      locale: const Locale('pt'),
      updates: _updates(
        _Launcher(LaunchResult.started),
        feed: const _OfflineFeed(),
      ),
    );
    controller
      ..enter(const CellAddress(0, 0), '1234,5')
      ..enter(const CellAddress(0, 1), '98765,25')
      ..select(const Selection(CellAddress(0, 0), CellAddress(0, 1)));
    await tester.pumpAndSettle();

    expect(find.text('Soma: 99999,75'), findsOneWidget);
    expect(find.text('Não foi possível procurar atualizações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with unsaved work, Cancel keeps the app open', (tester) async {
    final launcher = _Launcher(LaunchResult.started);
    final calls = _recordWindowCalls();
    final controller = await _pump(tester, updates: _updates(launcher));
    _change(controller);
    await tester.pump();

    await tester.tap(find.text('Update to 9.9.9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(launcher.launches, 0);
    expect(calls, isNot(contains('destroy')));
  });

  testWidgets("Don't save opens the updater and closes the app", (
    tester,
  ) async {
    final launcher = _Launcher(LaunchResult.started);
    final calls = _recordWindowCalls();
    final controller = await _pump(tester, updates: _updates(launcher));
    _change(controller);
    await tester.pump();

    await tester.tap(find.text('Update to 9.9.9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't save"));
    // the indicator spins until the window is gone
    await tester.pump();
    await tester.pump();

    expect(launcher.launches, 1);
    expect(calls, contains('destroy'));
  });

  testWidgets('a change made while the updater opens is asked about again', (
    tester,
  ) async {
    final opening = Completer<LaunchResult>();
    final launcher = _Launcher(LaunchResult.started, opening: opening);
    final calls = _recordWindowCalls();
    final controller = await _pump(tester, updates: _updates(launcher));
    _change(controller);
    await tester.pump();

    await tester.tap(find.text('Update to 9.9.9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't save"));
    await tester.pump();
    _change(controller);
    opening.complete(LaunchResult.started);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Don't save"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, isNot(contains('destroy')));
  });

  testWidgets('when the updater does not open, the app stays open', (
    tester,
  ) async {
    final launcher = _Launcher(LaunchResult.failed);
    final calls = _recordWindowCalls();
    final controller = await _pump(tester, updates: _updates(launcher));
    _change(controller);
    await tester.pump();

    await tester.tap(find.text('Update to 9.9.9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't save"));
    await tester.pumpAndSettle();

    expect(launcher.launches, 1);
    expect(calls, isNot(contains('destroy')));
    expect(find.text("Couldn't open the updater."), findsOneWidget);
    expect(find.text('Update to 9.9.9'), findsOneWidget);
  });
}
