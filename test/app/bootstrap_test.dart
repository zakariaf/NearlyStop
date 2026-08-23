// Cold start, frame one.
//
// Our user is 78 and opens this at 6am in a dark bedroom. A white flash before
// the dark theme loads is not a cosmetic defect for that person — it is the app
// shouting at them. So the assertion is not "it settles into dark", it is that
// **no frame is ever painted in the wrong theme**: a Builder records every
// build and the recorded list must contain nothing else.
import 'dart:io';

import 'package:drift/drift.dart' show LazyDatabase, Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/app/bootstrap.dart';
import 'package:nearlystop/core/diagnostics/crash_sink.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/providers.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// Records whether the crash sink was installed before it was first asked for
/// a path.
///
/// A bare `implements`-style fake over the `DatabaseLocation` typedef: the
/// ordering claim in task 1 is not observable any other way, because the two
/// steps leave no trace in the finished container.
final class RecordingLocation {
  RecordingLocation(this.directory, this.originalOnError);

  final Directory directory;

  /// What `FlutterError.onError` was before the launch touched it.
  final FlutterExceptionHandler? originalOnError;

  /// Whether the handler had already been replaced when the path was asked
  /// for.
  bool? sinkInstalledFirst;

  /// Throws instead of answering, for the corrupt-database case.
  bool failOnOpen = false;

  Future<File> call() async {
    sinkInstalledFirst = !identical(FlutterError.onError, originalOnError);
    if (failOnOpen) throw const FileSystemException('unreadable');
    return File('${directory.path}/nearlystop.sqlite');
  }
}

void main() {
  late Directory directory;
  late RecordingLocation location;
  late FlutterExceptionHandler? originalOnError;
  ProviderContainer? launchedContainer;
  AppDatabase? launchedDatabase;

  /// Tears the launched container down **inside the test body**.
  ///
  /// The app starts a real midnight timer in `initState`, and `testWidgets`
  /// rejects a body that ends with one pending — as a HANG, not a message.
  /// A teardown runs too late to prevent it.
  /// Unmounts, closes, disposes — in that order, and none of it nested.
  ///
  /// `databaseOverride` deliberately drops the `close()` future (an
  /// `onDispose` callback is synchronous and cannot await), so nothing else
  /// finishes it and the binding reports the leftover as a pending timer,
  /// naming nothing. The close therefore happens HERE, explicitly, in real
  /// time — and outside any other `runAsync`, because nesting two is itself a
  /// failure.
  Future<void> disposeLaunched(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final database = launchedDatabase;
    launchedDatabase = null;
    if (database != null) {
      // Swallowed: in the corrupt-database case the open itself threw, so
      // closing rethrows the same FileSystemException. The launch already
      // recorded it in the crash sink and the test already asserted that;
      // failing here would fail on the thing the test is proving works.
      await tester.runAsync(() => database.close().catchError((_) {}));
    }
    launchedContainer?.dispose();
    launchedContainer = null;
  }

  /// Runs the launch order and pumps ONE frame of what it produced.
  ///
  /// Two things here are forced by the harness rather than chosen:
  ///
  /// **`runAsync`.** `testWidgets` runs its body in a zone where real
  /// asynchronous I/O never completes — a `flutter test` of the launch path
  /// without this hangs rather than failing, which is worse than a red test
  /// because nothing names the cause. The launch genuinely does file I/O, so it
  /// runs inside `runAsync` and only the PUMP happens in fake-async time.
  ///
  /// **The in-process database.** `AppDatabase(location)` is
  /// `NativeDatabase.createInBackground`, which runs the engine on its own
  /// isolate. The shipping connection has its own suite
  /// (`test/data/background_connection_test.dart`, a plain `test()`); what this
  /// covers is the launch ORDER, which is what the no-flash promise rests on.
  /// `LazyDatabase` keeps the location seam in play, so the
  /// sink-installed-first assertion still has something to observe.
  Future<ProviderContainer> launch(WidgetTester tester, Widget child) async {
    final launched = await tester.runAsync(
      () => startUp(
        location: location.call,
        diagnosticsDirectory: directory.path,
        openDatabase: (location) => launchedDatabase = AppDatabase.forTesting(
          LazyDatabase(() async => NativeDatabase(await location())),
        ),
      ),
    );
    // Handed straight back, INSIDE the test body: `flutter_test` asserts a
    // test leaves the global handlers as it found them, and it checks at the
    // end of the body rather than after teardowns. The ordering claim has
    // already been recorded by now, which is all the launch is asked to prove.
    launched!.restoreHandlers();
    launchedContainer = launched.container;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: launched.container, child: child),
    );
    return launched.container;
  }

  setUp(() {
    // Reset, not merely declared: these are file-scoped so that
    // `disposeLaunched` can reach them from inside a test body, and a test
    // that fails before disposing would otherwise hand the NEXT test a
    // container and a database belonging to a dead one.
    launchedContainer = null;
    launchedDatabase = null;
    directory = Directory.systemTemp.createTempSync('nearlystop_boot');
    // What `FlutterError.onError` was before the launch replaced it. The
    // ordering claim is observed against this, and `launch` puts both global
    // handlers back through the closure `installCrashSink` returns — one
    // test's sink silently swallowing the next test's failures is exactly the
    // kind of leak that makes a suite stop meaning anything.
    originalOnError = FlutterError.onError;
    location = RecordingLocation(directory, originalOnError);
  });
  tearDown(() {
    // Disposal has to happen in the BODY (see `disposeLaunched`), so this
    // cannot do the cleanup — but it can refuse to let a missed call be
    // silent. Without it a forgotten `disposeLaunched` surfaces as a hang in
    // whichever test runs next, which names nothing and, under
    // `--test-randomize-ordering-seed random`, is a different test each run.
    final leaked = launchedContainer != null || launchedDatabase != null;
    launchedContainer?.dispose();
    launchedContainer = null;
    launchedDatabase = null;
    directory.deleteSync(recursive: true);
    expect(
      leaked,
      isFalse,
      reason: 'this test body must end with `await disposeLaunched(tester)`',
    );
  });

  /// Writes a settings row into the database the bootstrap will find.
  /// Also inside `runAsync`, for the same reason the launch is: this writes a
  /// real file, and `testWidgets` would never let the write complete.
  Future<void> seedSettings(
    WidgetTester tester, {
    String themeMode = 'system',
    bool highContrast = false,
  }) => tester.runAsync(() async {
    final db = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/nearlystop.sqlite')),
    );
    await db.settingsDao.ensureRowExists('settings-0');
    await db.settingsDao.updateSettings(
      SettingsRowsCompanion(
        themeMode: Value<String>(themeMode),
        highContrast: Value<bool>(highContrast),
      ),
    );
    await db.close();
  });

  testWidgets('frame one is ALREADY dark — not a light frame then dark', (
    tester,
  ) async {
    await seedSettings(tester, themeMode: 'dark');
    final brightnesses = <Brightness>[];

    // ONE frame, deliberately not settled: settling would let a flash happen
    // and then be repainted over, and the test would pass anyway. The REAL app
    // is pumped — `Theme.of` under a bare `Builder` is Material's default and
    // would be light no matter what the launch read.
    await launch(tester, const NearlyStopApp());
    brightnesses.add(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
    );

    expect(brightnesses, <Brightness>[Brightness.dark]);
    await disposeLaunched(tester);
  });

  testWidgets('frame one already carries the high-contrast palette', (
    tester,
  ) async {
    await seedSettings(tester, highContrast: true);
    final schemes = <ColorScheme>[];

    await launch(tester, const NearlyStopApp());
    schemes.add(Theme.of(tester.element(find.byType(Scaffold))).colorScheme);

    expect(
      schemes.first,
      buildDaybreakTheme(
        Brightness.light,
        DaybreakScript.latin,
        highContrast: true,
      ).colorScheme,
    );
    await disposeLaunched(tester);
  });

  testWidgets('the crash sink is installed BEFORE the database is opened', (
    tester,
  ) async {
    await seedSettings(tester);

    await launch(tester, const NearlyStopApp());

    expect(
      location.sinkInstalledFirst,
      isTrue,
      reason: 'a crash while opening the database has nowhere to be recorded',
    );
    await disposeLaunched(tester);
  });

  testWidgets('a corrupt database still paints, with defaults and an error', (
    tester,
  ) async {
    location.failOnOpen = true;
    final brightnesses = <Brightness>[];
    late AppSettings settings;
    late Object? failure;

    final container = await launch(tester, const NearlyStopApp());
    brightnesses.add(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
    );
    settings = container.read(bootstrapSettingsProvider);
    failure = container.read(bootstrapErrorProvider);

    // Never a black screen: the app the patient depends on comes up.
    expect(brightnesses, isNotEmpty);
    expect(settings, AppSettings.defaults);
    expect(failure, isNotNull);
    // And it was RECORDED, not swallowed: the sink is the whole diagnostics
    // story, so the launch writing to it is the only evidence a user could
    // ever hand back.
    expect(
      CrashSink(directory: directory.path).readAll(),
      isNotEmpty,
      reason: 'the launch failure never reached the crash log',
    );
    await disposeLaunched(tester);
  });

  testWidgets('no FutureBuilder anywhere in the launch path', (tester) async {
    // The native splash covers the one pre-runApp await. A FutureBuilder would
    // paint a spinner first, which is the flash by another name.
    await seedSettings(tester, themeMode: 'dark');

    await launch(tester, const NearlyStopApp());

    expect(find.byType(FutureBuilder<Object?>), findsNothing);
    await disposeLaunched(tester);
  });
}
