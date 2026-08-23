// Ticking a dose survives the app being closed.
//
// A FILE-backed database, not `NativeDatabase.memory()`: the claim is about
// durability, and bytes that never left memory prove nothing about it.
//
// A widget test cannot kill the host process, so "kill and relaunch" is not a
// claim this suite can make. Rebuilding the provider container over the SAME
// file is the honest form of the same assurance, and it is how EPIC-05 already
// proves its own persistence.
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../../support/db_harness.dart';

void main() {
  const today = LocalDate(2026, 4, 16);

  setUpAll(initializeDateFormatting);

  ProviderContainer containerOver(AppDatabase database) {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(today),
        clockProvider.overrideWithValue(Clock.fixed(DateTime.utc(2026, 4, 16))),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<TodayViewState> firstState(ProviderContainer container) async {
    container.listen(todayViewProvider, (_, _) {});
    return container.read(todayViewProvider.future);
  }

  test('a tick survives the container being torn down and rebuilt', () async {
    final (:db, :file) = openTempFileDatabase();
    final first = containerOver(db);
    await first.read(taperRepositoryProvider).savePlan(seededDraft());
    await firstState(first);
    await first.read(todayViewProvider.notifier).markTakenToday();
    // The write commits, then the watched stream re-emits. Reading before that
    // lands reads the state from BEFORE the tick.
    await Future<void>.delayed(Duration.zero);
    final before = first.read(todayViewProvider).requireValue as TodayDose;
    expect(before.taken, isTrue);

    // Everything the app held is gone: the container, the notifier, the
    // derivation. Only the bytes remain.
    first.dispose();
    await db.close();

    final reopened = reopenFileDatabase(file);
    final second = containerOver(reopened);
    final after = await firstState(second) as TodayDose;

    expect(after.taken, isTrue, reason: 'the tick did not survive');
    // Byte for byte, not just "still ticked": the dose, the tablets, the
    // context line and the date all have to come back the same, or something
    // in the projection depends on state that did not persist.
    expect(after, before);
  });

  test('a note survives too, and does not become a tick', () async {
    final (:db, :file) = openTempFileDatabase();
    final first = containerOver(db);
    await first.read(taperRepositoryProvider).savePlan(seededDraft());
    await firstState(first);
    await first.read(todayViewProvider.notifier).saveNote('slept badly');
    await Future<void>.delayed(Duration.zero);
    first.dispose();
    await db.close();

    final second = containerOver(reopenFileDatabase(file));
    final after = await firstState(second) as TodayDose;

    expect(after.noteText, 'slept badly');
    expect(after.taken, isFalse, reason: 'a note became a tick');
  });
}
