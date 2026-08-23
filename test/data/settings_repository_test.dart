// SettingsRepository against a real engine and an injected clock.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/settings_repository.dart';
import 'package:nearlystop/data/storage_failure.dart';

import '../support/db_harness.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = openTestDatabase();
    settings = SettingsRepository(db, fixedClock);
  });

  Future<void> expectOk(Future<Result<void, StorageFailure>> write) async {
    expect(await write, isA<Ok<void, StorageFailure>>());
  }

  test('readOnce answers the defaults before the row exists', () async {
    // Bootstrap reads settings before first paint, and on a fresh install
    // there is no row. Returning defaults rather than throwing is what stops
    // the very first launch crashing.
    final read = await settings.readOnce();

    expect(read, AppSettings.defaults);
    expect(read.themeMode, 'system');
    expect(read.textScale, 1.0);
    expect(read.hasAcceptedDisclaimer, isFalse);
  });

  test('ensureExists is idempotent and does not clobber a choice', () async {
    await expectOk(settings.ensureExists());
    await expectOk(settings.setThemeMode('dark'));

    await expectOk(settings.ensureExists());

    expect(await db.select(db.settingsRows).get(), hasLength(1));
    expect((await settings.readOnce()).themeMode, 'dark');
  });

  test('every setter writes its own field and no other', () async {
    await expectOk(settings.ensureExists());

    await expectOk(settings.setReminderEnabled(enabled: true));
    await expectOk(settings.setReminderMinuteOfDay(7 * 60 + 30));
    await expectOk(settings.setTextScale(1.6));
    await expectOk(settings.setHighContrast(enabled: true));
    await expectOk(settings.setLocaleTag('fa'));
    await expectOk(settings.setThemeMode('dark'));
    await expectOk(settings.acceptDisclaimer());

    final read = await settings.readOnce();
    expect(read.reminderEnabled, isTrue);
    // Minutes since LOCAL midnight — a wall-clock time, never an instant.
    expect(read.reminderMinuteOfDay, 450);
    expect(read.textScale, 1.6);
    expect(read.highContrast, isTrue);
    expect(read.localeTag, 'fa');
    expect(read.themeMode, 'dark');
    expect(read.disclaimerAcceptedAt, fixedNow);
    expect(read.hasAcceptedDisclaimer, isTrue);
  });

  test('acceptDisclaimer stamps the injected clock, in UTC', () async {
    await expectOk(settings.ensureExists());

    await expectOk(settings.acceptDisclaimer());

    final stamped = (await settings.readOnce()).disclaimerAcceptedAt!;
    expect(stamped, fixedNow);
    expect(stamped.isUtc, isTrue);
  });

  test('clearing the reminder minute writes null, not zero', () async {
    // 0 is midnight, a legal reminder time. Conflating it with "unset" turns
    // a cleared reminder into a 00:00 alarm.
    await expectOk(settings.ensureExists());
    await expectOk(settings.setReminderMinuteOfDay(0));
    expect((await settings.readOnce()).reminderMinuteOfDay, 0);

    await expectOk(settings.setReminderMinuteOfDay(null));

    expect((await settings.readOnce()).reminderMinuteOfDay, isNull);
  });

  test('AppSettings is a value: equal fields, equal hash', () async {
    // It goes straight into a Riverpod state. Without value equality every
    // rebuild re-notifies, and every screen listening to settings repaints on
    // a frame nothing changed.
    await expectOk(settings.ensureExists());
    final first = await settings.readOnce();
    final second = await settings.readOnce();

    expect(first, second);
    expect(<AppSettings>{first, second}, hasLength(1));
    await expectOk(settings.setTextScale(1.4));
    expect(await settings.readOnce(), isNot(first));
  });

  test('a closed database is Io, not an escaping StateError', () async {
    await expectOk(settings.ensureExists());
    await db.close();

    final result = await settings.setThemeMode('dark');

    expect((result as Err<void, StorageFailure>).failure, isA<Io>());
  });

  test('watchSettings emits defaults, then re-emits on a write', () async {
    final emissions = <AppSettings>[];
    final sub = settings.watchSettings().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await expectOk(settings.ensureExists());
    await expectOk(settings.setTextScale(1.3));
    await pumpEventQueue();

    expect(emissions.first, AppSettings.defaults);
    expect(emissions.last.textScale, 1.3);
  });
}
