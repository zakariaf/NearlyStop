/// The plan designed to break a serializer, not to read nicely.
///
/// Every value here is one somebody actually has. A drug name with an
/// apostrophe and a comma is what the box says; a note with an embedded
/// newline is what happens when a phone keyboard has a return key; a
/// whitespace-only note is what a mis-tap leaves; `=cmd()` is a real sentence
/// in English that Excel treats as a formula.
///
/// Shared rather than re-declared per file: the whole point is that a column
/// added to a table has ONE hostile row to keep working, and four private
/// copies is how three of them quietly stop covering it.
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';

import '../support/db_harness.dart';

/// A drug name with an apostrophe, a comma and a double quote in it.
const String hostileDrugName = "Prednisolon 'Actavis', \"5mg\"";

/// A note with a double quote and an embedded newline.
///
/// NDJSON is line-delimited, so a newline inside a value is the obvious way to
/// split one row into two.
const String hostileQuotedNote = 'felt fine, "no aches"\nslept well';

/// A note that begins with `=`, which Excel runs as a formula.
///
/// Not hypothetical: `-2 today` is a sentence somebody writes about their dose
/// and a live formula in a spreadsheet.
const String hostileFormulaNote = '=cmd()|"/c calc"!A1';

/// A note in Persian, carrying an explicit bidi mark.
///
/// U+200F is a RIGHT-TO-LEFT MARK. It is invisible, it is meaningful, and a
/// codec that trims or normalizes strings loses it silently.
const String hostileRtlNote = '‏درد کمتر شد ‎(10mg)‏';

/// A note that is nothing but whitespace — a mis-tap, and a real row.
const String hostileBlankNote = '   \t  ';

/// A note with an emoji outside the basic multilingual plane.
const String hostileEmojiNote = 'better today 🌅💊';

/// An instant inside the hour the UK repeats when the clocks go back.
///
/// 2025-10-26 01:30 London happens twice. Stored as UTC, it is unambiguous;
/// a codec that round-trips through a LOCAL instant picks one of the two and
/// the value moves by an hour every time it is exported.
final DateTime hostileAmbiguousInstant = DateTime.utc(2025, 10, 26, 0, 30);

/// Seeds every hostile row into [db], and returns the plan's row id.
///
/// Rows are inserted in a deliberately awkward order — a later date before an
/// earlier one — because `ORDER BY uid` in the writer is the only thing that
/// makes two exports of the same data byte-identical, and insertion order is
/// what would otherwise leak into the file.
Future<int> seedHostilePlan(AppDatabase db) async {
  final planId = await seedPlan(
    db,
    drugName: hostileDrugName,
    createdAt: hostileAmbiguousInstant,
    // A quarter-milligram dose, which only survives if doses are stored and
    // encoded as integer hundredths.
    startingDose: const Milligrams.fromHundredths(1025),
    strengths: const <Milligrams>[
      Milligrams.fromHundredths(500),
      Milligrams.fromHundredths(250),
      Milligrams.fromHundredths(100),
    ],
  );
  await seedStep(db, planId, index: 1, uid: 'step-1');
  await seedStep(db, planId);

  // A null note and an empty note are different facts. One says "nothing to
  // add", the other says "never asked".
  await seedLog(db, planId, const LocalDate(2026, 4, 2), uid: 'log-b');
  await seedLog(
    db,
    planId,
    const LocalDate(2026, 4, 1),
    uid: 'log-a',
    note: hostileQuotedNote,
    takenAt: hostileAmbiguousInstant,
  );
  await seedLog(
    db,
    planId,
    const LocalDate(2026, 4, 3),
    uid: 'log-formula',
    note: hostileFormulaNote,
  );
  await seedLog(
    db,
    planId,
    const LocalDate(2026, 4, 4),
    uid: 'log-rtl',
    note: hostileRtlNote,
  );
  await seedLog(
    db,
    planId,
    const LocalDate(2026, 4, 5),
    uid: 'log-blank',
    note: hostileBlankNote,
  );
  await seedLog(
    db,
    planId,
    const LocalDate(2026, 4, 6),
    uid: 'log-emoji',
    note: hostileEmojiNote,
    // Half a milligram, and NOT taken — so the cumulative total and the
    // adherence count disagree, which is the only way to tell the two apart.
    actualMg: const Milligrams.fromHundredths(50),
    taken: false,
  );
  // A leap day, and a note that is empty rather than absent.
  await seedLog(
    db,
    planId,
    const LocalDate(2024, 2, 29),
    uid: 'log-leap',
    note: '',
  );

  await db.planDao.insertFlare(
    FlareEventsCompanion.insert(
      uid: 'flare-1',
      planId: planId,
      date: const LocalDate(2026, 4, 3),
      revertToDose: const Milligrams.fromHundredths(1500),
      note: const Value<String?>(hostileRtlNote),
    ),
  );
  await db.stepDao.insertHold(
    HoldEventsCompanion.insert(
      uid: 'hold-1',
      stepId: 1,
      fromDate: const LocalDate(2026, 4, 4),
      extraDays: 7,
      note: const Value<String?>(hostileBlankNote),
    ),
  );

  // The settings row too. It is one of the six tables the backup carries, and
  // a fixture that leaves it empty makes every per-table assertion vacuous for
  // exactly one table — which is the one nobody notices.
  await db.settingsDao.ensureRowExists('settings-hostile');
  await db.settingsDao.updateSettings(
    SettingsRowsCompanion(
      reminderEnabled: const Value<bool>(true),
      reminderMinuteOfDay: const Value<int?>(545),
      // A locale whose tag carries a script subtag, which is the one that
      // broke `intl` on a device.
      localeTag: const Value<String?>('ckb-Arab'),
      textScale: const Value<double>(1.3),
      disclaimerAcceptedAt: Value<DateTime?>(hostileAmbiguousInstant),
    ),
  );

  return planId;
}
