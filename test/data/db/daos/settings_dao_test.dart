// SettingsDao against a real engine.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/data/db/app_database.dart';

import '../../../support/db_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());

  test('ensureRowExists writes the defaults row and is idempotent', () async {
    await db.settingsDao.ensureRowExists('settings-1');
    await db.settingsDao.updateSettings(
      const SettingsRowsCompanion(highContrast: Value<bool>(true)),
    );
    // A second open must not clobber what the user has already chosen —
    // `insertOrIgnore`, not `insertOrReplace`.
    await db.settingsDao.ensureRowExists('settings-2');

    final rows = await db.select(db.settingsRows).get();

    expect(rows, hasLength(1));
    expect(rows.single.uid, 'settings-1');
    expect(rows.single.highContrast, isTrue);
  });

  test(
    'the defaults are the ones the pre-first-paint read depends on',
    () async {
      await db.settingsDao.ensureRowExists('settings-1');

      final row = await db.settingsDao.readSettingsOnce();

      expect(row, isNotNull);
      expect(row!.reminderEnabled, isFalse);
      expect(row.reminderMinuteOfDay, isNull);
      expect(row.textScale, 1.0);
      expect(row.highContrast, isFalse);
      expect(row.disclaimerAcceptedAt, isNull);
      expect(row.localeTag, isNull);
      expect(row.themeMode, 'system');
    },
  );

  test('readSettingsOnce is null before the row exists', () async {
    // Bootstrap reads this before `ensureRowExists`; a throw here is a crash
    // on the very first launch.
    expect(await db.settingsDao.readSettingsOnce(), isNull);
  });

  test('a per-field update leaves every other field untouched', () async {
    await db.settingsDao.ensureRowExists('settings-1');
    await db.settingsDao.updateSettings(
      const SettingsRowsCompanion(
        reminderEnabled: Value<bool>(true),
        reminderMinuteOfDay: Value<int?>(7 * 60 + 30),
      ),
    );

    await db.settingsDao.updateSettings(
      const SettingsRowsCompanion(textScale: Value<double>(1.3)),
    );

    final row = await db.settingsDao.readSettingsOnce();
    expect(row!.textScale, 1.3);
    expect(row.reminderEnabled, isTrue);
    // A reminder is a WALL-CLOCK time. Minutes since local midnight, never an
    // instant — storing it as one is the DST bug in a different hat.
    expect(row.reminderMinuteOfDay, 450);
    expect(row.themeMode, 'system');
  });

  test('watchSettings re-emits on a write', () async {
    await db.settingsDao.ensureRowExists('settings-1');
    final emissions = <SettingsRow?>[];
    final sub = db.settingsDao.watchSettings().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await db.settingsDao.updateSettings(
      const SettingsRowsCompanion(themeMode: Value<String>('dark')),
    );
    await pumpEventQueue();

    expect(emissions.first!.themeMode, 'system');
    expect(emissions.last!.themeMode, 'dark');
  });
}
