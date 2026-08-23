/// The data layer's Riverpod entry points.
///
/// `package:riverpod`, not `flutter_riverpod`: nothing here touches a widget.
library;

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
Override databaseOverride(AppDatabase database) =>
    databaseProvider.overrideWith((ref) {
      ref.onDispose(database.close);
      return database;
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
