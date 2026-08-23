/// The composition root.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/app/day_ticker.dart';
import 'package:nearlystop/core/diagnostics/crash_sink.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/core/time/clock.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/database_location.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/settings_repository.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/providers.dart';
import 'package:path_provider/path_provider.dart';
// `Override` is not in riverpod 3's default barrel.
import 'package:riverpod/misc.dart' show Override;

/// The bundled faces, and the OFL text file that licenses each.
///
/// Both are SIL Open Font License 1.1, verified from the shipped files rather
/// than from memory.
const Map<String, String> bundledFontLicenses = <String, String>{
  'Nunito': 'assets/fonts/OFL-Nunito.txt',
  'Vazirmatn': 'assets/fonts/OFL-Vazirmatn.txt',
};

/// Registers the bundled fonts' OFL text with the framework.
///
/// An unregistered OFL font makes the app's own licenses page a lie, and
/// nothing else in the suite would notice.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: path)
        in bundledFontLicenses.entries) {
      yield LicenseEntryWithLineBreaks(
        <String>[family],
        await rootBundle.loadString(path),
      );
    }
  });
}

/// Routes every uncaught error into a **local** file and nowhere else.
///
/// `SPEC.md` §5.3 bans any crash SDK that phones home. This is installed first
/// thing after the binding, before anything that can throw — most of all before
/// the database is opened, because a corrupt database is exactly the crash
/// worth having a record of.
///
/// The `FlutterErrorDetails` → `(error, stack, context)` adaptation happens
/// **here**, not in the sink: the sink lives under `lib/core/`, which
/// `check_core_purity` keeps free of Flutter.
///
/// Returns a closure that puts both handlers back. An installer that cannot be
/// uninstalled is untestable by construction — `flutter_test` fails any test
/// that leaves `FlutterError.onError` changed, and rightly: one test's sink
/// silently swallowing the next test's failures is how a suite stops meaning
/// anything.
void Function() installCrashSink(CrashSink sink) {
  final previousOnError = FlutterError.onError;
  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  FlutterError.onError = (details) {
    sink.record(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    sink.record(error, stack, context: 'PlatformDispatcher');
    return true;
  };
  return () {
    FlutterError.onError = previousOnError;
    PlatformDispatcher.instance.onError = previousPlatformOnError;
  };
}

/// Builds the app's infrastructure and runs it.
///
/// **Order is the whole point**, and each step earns its place:
/// 1. the binding, because `path_provider` needs it;
/// 2. the crash sink, so a failure in step 3 is recorded rather than lost;
/// 3. `intl`'s symbol data for the two locales that reach `DateFormat`;
/// 4. the database, and a **single** settings read — the only pre-`runApp`
///    await, and the thing that buys a first frame in the right theme;
/// 5. `runApp`.
///
/// There is no `FutureBuilder` and no splash widget anywhere in this path: the
/// native splash covers step 4, and a spinner would be the flash by another
/// name.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final launched = await startUp(
    location: appDocumentsDatabaseFile,
    diagnosticsDirectory: directory.path,
  );
  runApp(
    UncontrolledProviderScope(
      container: launched.container,
      child: const NearlyStopApp(),
    ),
  );
  // Started by the LAUNCH, not by a widget's `initState`. A widget that starts
  // a real timer makes every widget test that pumps the app leak one — and
  // `testWidgets` reports a pending timer as a hang, not a message. The ticker
  // belongs to the container's lifetime anyway; it must keep running while the
  // app is up whether or not anything is currently watching the date.
  launched.container.read(dayTickerProvider);
}

/// Everything [bootstrap] does **except** `runApp`.
///
/// Split out so a widget test can drive the launch order and then pump the
/// resulting tree itself, asserting on frame one. It is also the seam for the
/// two platform dependencies: [location] and [openDatabase].
///
/// **[openDatabase] exists because the shipping connection cannot be opened
/// inside `testWidgets`.** `AppDatabase(location)` is
/// `NativeDatabase.createInBackground`, which runs the engine on its own
/// isolate; under `flutter_test`'s binding that never resolves and the test
/// hangs rather than failing. Verified, not assumed. The shipping connection is
/// covered by `test/data/background_connection_test.dart`, which is a plain
/// `test()` and can await an isolate; what this seam lets a widget test cover
/// is the launch ORDER, which is what the no-flash promise actually rests on.
Future<
  ({
    ProviderContainer container,
    Object? failure,
    void Function() restoreHandlers,
  })
>
startUp({
  required DatabaseLocation location,
  required String diagnosticsDirectory,
  AppDatabase Function(DatabaseLocation location) openDatabase =
      AppDatabase.new,
}) async {
  registerFontLicenses();
  final sink = CrashSink(directory: diagnosticsDirectory);
  final restoreHandlers = installCrashSink(sink);

  // `DateFormat('de')` throws on first use without this — but the ZERO-ARG
  // form materialises the symbol tables for every locale `intl` ships, on the
  // blocking path before the first frame, for an app with four locales. Only
  // `en` and `de` reach `DateFormat` at all: `fa` goes through `shamsi_date`
  // and `ckb` is composed from the ARB (see lib/l10n/date_formats.dart).
  for (final locale in <String>['en', 'de']) {
    await initializeDateFormatting(locale);
  }

  final opened = await _openAndReadSettings(location, openDatabase, sink);
  return (
    restoreHandlers: restoreHandlers,
    container: ProviderContainer(
      overrides: <Override>[
        if (opened.database case final database?) databaseOverride(database),
        bootstrapSettingsProvider.overrideWithValue(opened.settings),
        bootstrapErrorProvider.overrideWithValue(opened.failure),
      ],
    ),
    failure: opened.failure,
  );
}

/// Opens the database and reads the one row the first frame depends on.
///
/// A throw here is a corrupt or unreadable database — the worst thing that can
/// happen to a person 400 days into a taper — and the answer is **defaults plus
/// a recoverable error**, never a black screen. The failure reaches the UI
/// through `bootstrapErrorProvider`; the crash sink already has the stack.
Future<({AppDatabase? database, AppSettings settings, Object? failure})>
_openAndReadSettings(
  DatabaseLocation location,
  AppDatabase Function(DatabaseLocation location) openDatabase,
  CrashSink sink,
) async {
  AppDatabase? database;
  try {
    database = openDatabase(location);
    final repository = SettingsRepository(database, systemClock);
    // `ensureExists` RETURNS its failure rather than throwing — that is the
    // repository's contract, and it is why a `try` alone left this whole error
    // path unreachable. The first write is also the first time the file is
    // actually touched, so it is where an unreadable database shows up.
    final ensured = await repository.ensureExists();
    if (ensured case Err<void, StorageFailure>(:final failure)) {
      return _fallback(sink, database, failure, StackTrace.current);
    }
    return (
      database: database,
      settings: await repository.readOnce(),
      failure: null,
    );
  } on Object catch (error, stack) {
    return _fallback(sink, database, error, stack);
  }
}

/// Defaults plus a recoverable error, and the crash sink already has the stack.
///
/// **Never a black screen.** A person 400 days into a taper needs the app to
/// open far more than they need it to be right about their theme.
({AppDatabase? database, AppSettings settings, Object? failure}) _fallback(
  CrashSink sink,
  AppDatabase? database,
  Object error,
  StackTrace stack,
) {
  // Straight to the sink, NOT through `FlutterError.reportError`. This is a
  // failure the launch already knows about and already has an answer for —
  // routing it through the global handler would present it as an unhandled
  // crash on top of being handled, which in a test is two exceptions for one
  // problem and in production is a console dump the user cannot act on.
  sink.record(error, stack, context: 'opening the database at startup');
  unawaited(database?.close().catchError((_) {}));
  return (database: null, settings: AppSettings.defaults, failure: error);
}
