// A restore swaps the database FILE under a running app.
//
// Every handle the app is holding then points at the old inode: on POSIX the
// rename succeeds and the old connection keeps reading a file nothing else
// will ever look at. The symptom is the worst one this app has — a restore
// that reports success and shows the pre-restore plan until the next launch.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/data/database_restart.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

void main() {
  test('the app keeps its first connection until the file is replaced', () {
    final first = AppDatabase.forTesting(NativeDatabase.memory());
    final second = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(first.close);
    addTearDown(second.close);
    final container = ProviderContainer(
      overrides: <Override>[databaseOverride(first, reopen: () => second)],
    );
    addTearDown(container.dispose);

    expect(container.read(databaseProvider), same(first));
  });

  test('replacing the file hands the app a new connection', () async {
    final first = AppDatabase.forTesting(NativeDatabase.memory());
    final second = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(second.close);
    final container = ProviderContainer(
      overrides: <Override>[databaseOverride(first, reopen: () => second)],
    );
    addTearDown(container.dispose);
    // USED, not just read. drift opens its executor lazily, and closing a
    // connection that never ran a statement is a no-op — so a test that skips
    // this passes whether the swap closes anything or not.
    await container.read(databaseProvider).customSelect('SELECT 1;').get();

    container.read(databaseGenerationProvider.notifier).replaced();

    expect(container.read(databaseProvider), same(second));
    // And the one that pointed at the replaced file is gone. A leaked handle
    // on the old inode holds a whole database file open for the process's
    // lifetime. `close()` is dropped deliberately inside `onDispose`, so this
    // lets its microtasks run before asking.
    await pumpEventQueue();
    await expectLater(
      first.customSelect('SELECT 1;').getSingle(),
      throwsA(anything),
    );
  });

  test('a container with no reopen keeps what it was given', () {
    // Every test in the suite constructs the override this way. A generation
    // bump must not hand them a second copy of the same database.
    final only = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(only.close);
    final container = ProviderContainer(
      overrides: <Override>[databaseOverride(only)],
    );
    addTearDown(container.dispose);

    expect(container.read(databaseProvider), same(only));
  });
}
