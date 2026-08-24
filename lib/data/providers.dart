/// The data layer's Riverpod entry points.
///
/// `package:riverpod`, not `flutter_riverpod`: nothing here touches a widget.
library;

import 'dart:async';

import 'package:nearlystop/data/database_restart.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/settings_repository.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/providers.dart';
// `Override` is not in riverpod 3's default barrel; `misc.dart` is where it
// is published.
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

export 'package:nearlystop/providers.dart' show clockProvider;

/// The open database.
///
/// **Throws by default, on purpose.** EPIC-06's `bootstrap()` overrides it with
/// an already-opened instance, so no screen can ever await the database
/// opening on the UI thread — and a provider that silently opened one would
/// pass every test in the suite while jank-ing the first frame on a real phone.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden at the composition root with an '
    'already-opened AppDatabase (bootstrap) or a test database.',
  );
});

/// The override that hands the container an open database **and takes
/// ownership of closing it**.
///
/// `overrideWithValue` replaces the provider body wholesale, so an
/// `ref.onDispose` written inside [databaseProvider] would never run for the
/// only configuration that ever supplies a database. Putting the disposal in
/// the override is the one place both EPIC-06's bootstrap and every test can
/// share, so a container that goes away always takes its database with it.
///
/// [reopen] builds a connection to whatever file is there **now**. It is used
/// only after `DatabaseGeneration.replaced()` — see
/// [databaseGenerationProvider] for why a restore has to have it. A container
/// that never restores (every test but one) may leave it out, and keeps the
/// instance it was given forever.
Override databaseOverride(
  AppDatabase database, {
  AppDatabase Function()? reopen,
}) => databaseProvider.overrideWith((ref) {
  final generation = ref.watch(databaseGenerationProvider);
  // Generation 0 is the connection bootstrap already opened before the first
  // frame. Building a second one here would open the file twice and throw
  // away the one thing the pre-`runApp` await bought.
  final current = generation == 0 || reopen == null ? database : reopen();
  // `onDispose` is synchronous and `close()` is not, so the future is
  // dropped either way. Dropping it DELIBERATELY, with the error handled,
  // is the difference between "closing is fire-and-forget" and "a throw
  // from close becomes an unhandled async error with no zone to catch it".
  // A caller that must know the file is closed — EPIC-13's restore —
  // awaits `close()` itself.
  ref.onDispose(() => unawaited(current.close().catchError((_) {})));
  return current;
});

/// The single object the app talks to about a taper.
final Provider<TaperRepository> taperRepositoryProvider =
    Provider<TaperRepository>(
      (ref) => TaperRepository(
        ref.watch(databaseProvider),
        ref.watch(clockProvider),
      ),
    );

/// The single object the app talks to about settings.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (ref) => SettingsRepository(
        ref.watch(databaseProvider),
        ref.watch(clockProvider),
      ),
    );
