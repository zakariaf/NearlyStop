// The Riverpod entry points, headless — no widget is pumped to test state.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../support/db_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());

  ProviderContainer containerWith(List<Override> overrides) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  test('databaseProvider throws with no override', () {
    // Deliberately unimplemented. A provider that silently opened a database
    // would pass every other test in this file while jank-ing the first frame
    // on a real phone.
    // Riverpod 3 wraps a provider's throw, so the cause has to be unwrapped
    // rather than matched directly.
    Object? caught;
    try {
      containerWith(<Override>[]).read(databaseProvider);
    } on Object catch (error) {
      caught = error;
    }

    expect(caught, isNotNull);
    expect(caught.toString(), contains('UnimplementedError'));
    expect(caught.toString(), contains('must be overridden'));
  });

  test(
    'an overridden database gives a working repository, no channels',
    () async {
      final container = containerWith(<Override>[
        databaseProvider.overrideWithValue(db),
      ]);

      final repository = container.read(taperRepositoryProvider);
      final saved = await repository.savePlan(seededDraft());
      final snapshot = await repository.watchSnapshot().first;

      expect(saved, isA<Ok<void, StorageFailure>>());
      expect(snapshot, isA<Ok<TaperSnapshot, StorageFailure>>());
    },
  );

  test('clockProvider reaches the repository', () async {
    // The Riverpod half of the clock seam. The constructor half is covered in
    // taper_repository_test; both must agree, or a screen and a test disagree
    // about what "now" is.
    final container = containerWith(<Override>[
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(fixedClock),
    ]);
    final repository = container.read(taperRepositoryProvider);
    await repository.savePlan(seededDraft());

    await repository.markTaken(const LocalDate(2026, 4, 16), plannedMg: mg(9));

    expect((await db.select(db.doseLogs).get()).single.takenAt, fixedNow);
  });

  test('both repositories share one AppDatabase instance', () {
    final container = containerWith(<Override>[
      databaseProvider.overrideWithValue(db),
    ]);

    final taper = container.read(taperRepositoryProvider);
    final settings = container.read(settingsRepositoryProvider);
    final resolved = container.read(databaseProvider);

    // `identical`, not `==`: two AppDatabase objects over the same file would
    // compare unequal anyway, but two over the same *executor* would not, and
    // that is the leak this catches.
    expect(identical(resolved, db), isTrue);
    // And each repository is itself a singleton in the container, so a second
    // screen does not get a second object holding a second stream set.
    expect(identical(container.read(taperRepositoryProvider), taper), isTrue);
    expect(
      identical(container.read(settingsRepositoryProvider), settings),
      isTrue,
    );
  });

  test('disposing the container closes the database', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseOverride(db),
      ],
    );
    // The engine opens lazily, so the database has to have been USED before
    // closing it can mean anything.
    await container.read(taperRepositoryProvider).savePlan(seededDraft());

    container.dispose();
    // `close()` is async and `dispose()` does not await it.
    await pumpEventQueue(times: 50);

    // Proving `ref.onDispose(db.close)` is wired rather than merely written
    // down. `overrideWithValue` would silently skip it.
    await expectLater(
      db.select(db.taperPlans).get(),
      throwsA(isA<StateError>()),
    );
  });
}
