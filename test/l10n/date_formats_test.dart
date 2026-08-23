// Dates, off canonical `LocalDate`s.
//
// **The second-zone arm is an environment assertion, not an in-process one.**
// Dart has no API to change the process's local timezone at runtime, so CI
// re-runs this file under a second `TZ`. Faking an in-process zone switch would
// be a green test over a structurally untestable path — worse than an admitted
// gap.
//
// The zone is `America/Los_Angeles`, chosen by experiment. The failure this
// guards is a UTC midnight read back through local fields
// (`toUtcMidnight().toLocal()`), and that only crosses a date boundary WEST of
// UTC: planted into `date_formats.dart` it is invisible under both UTC and
// Pacific/Auckland — which the epic names, and which is UTC+12, so a UTC
// midnight is still the same calendar day there — and fails four of the
// assertions below under Los Angeles. Every expectation here is an absolute
// string for that reason: a shifted date fails it outright rather than needing
// the two runs diffed by hand.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

const _en = Locale('en');
const _de = Locale('de');
const _fa = Locale('fa');

/// The repo's shared fixture date. A Wednesday.
const fixture = LocalDate(2025, 4, 16);

void main() {
  setUpAll(initializeDateFormatting);

  test('en and de are Gregorian, from intl symbol data', () {
    expect(formatDayLabel(fixture, _en), 'Wed, Apr 16');
    // Pinned as a golden rather than recomputed by the test — recomputing it
    // with the same DateFormat call the implementation makes asserts nothing.
    expect(formatDayLabel(fixture, _de), 'Mi., 16. Apr.');
  });

  test('every locale label carries the WEEKDAY', () {
    // The Schedule screen exists to answer "which day am I on" inside a 52-day
    // pattern that ignores weeks. A label without the weekday answers the one
    // question the screen is for — and Persian was the only locale missing it.
    for (final locale in kSupportedLocales) {
      final label = formatDayLabel(fixture, locale);
      final withoutWeekday = formatDayLabel(fixture, locale).split(
        RegExp('[،,]'),
      );

      expect(
        withoutWeekday.length,
        greaterThan(1),
        reason: '${locale.toLanguageTag()} label "$label" has no weekday',
      );
    }
    // 2025-04-16 is a Wednesday, in each locale's own word for it. Spaces are
    // squeezed before comparing: `shamsi_date` spells the Persian weekday
    // `چهار شنبه` and the design mockup writes `چهارشنبه`. Both are correct
    // Persian; pinning one orthography here would fail the day the package
    // changes its mind about a space. EPIC-14's parity pass settles which one
    // ships.
    String squeezed(Locale locale) =>
        formatDayLabel(fixture, locale).replaceAll(' ', '');

    expect(formatDayLabel(fixture, _en), startsWith('Wed'));
    expect(formatDayLabel(fixture, _de), startsWith('Mi'));
    expect(squeezed(_fa), contains('چهارشنبه'));
    expect(squeezed(kurdishSorani), contains('چوارشەممە'));
  });

  test('fa is Jalali, 27 Farvardin 1404, in Persian digits', () {
    // 1 Farvardin 1404 fell on 2025-03-21, so 2025-04-16 is day 27.
    final label = formatDayLabel(fixture, _fa);

    expect(label, contains('۲۷'));
    expect(label, contains('فروردین'));
    for (final code in label.runes) {
      expect(
        code,
        isNot(inInclusiveRange(0x0030, 0x0039)),
        reason: 'ASCII digit in "$label"',
      );
    }
  });

  test('the Jalali leap boundary — the reason this is a dependency', () {
    // 1403 IS a leap year, so 30 Esfand exists. A hand-rolled converter is
    // right for a year and then quietly wrong somewhere inside a 780-day taper.
    expect(jalaliParts(const LocalDate(2025, 3, 20)), (1403, 12, 30));
    expect(jalaliParts(const LocalDate(2025, 3, 21)), (1404, 1, 1));
  });

  test('ckb is Gregorian, composed from the app ARB, not from DateFormat', () {
    final l10n = lookupAppLocalizations(kurdishSorani);
    final label = formatDayLabel(fixture, kurdishSorani);

    // 2025-04-16 is a Wednesday: index 2 with a Monday-first list.
    expect(label, contains(l10n.ckbWeekdayNames.split('|')[2]));
    expect(label, contains(l10n.ckbMonthNames.split('|')[3]));
    // The day number comes through the fa formatter, so the digits match the
    // rest of the app.
    expect(label, contains('۱۶'));
  });

  test('DateFormat is never constructed with ckb — it throws', () {
    // The constraint that forces the ARB-composed path above, asserted so
    // nobody later "simplifies" ckb back into intl.
    expect(() => DateFormat.MMMEd('ckb'), throwsA(anything));
  });

  test('no date string mixes digit blocks', () {
    for (final locale in kSupportedLocales) {
      final label = formatDayLabel(fixture, locale);
      final digits = label.runes.where(
        (r) =>
            (r >= 0x0030 && r <= 0x0039) ||
            (r >= 0x0660 && r <= 0x0669) ||
            (r >= 0x06F0 && r <= 0x06F9),
      );

      expect(digits, isNotEmpty, reason: '$locale has no digits at all');
      final ascii = digits.every((r) => r <= 0x0039);
      final persian = digits.every((r) => r >= 0x06F0);
      expect(
        ascii || persian,
        isTrue,
        reason: 'mixed blocks in "$label" (${locale.toLanguageTag()})',
      );
      // Borrowing `ar` symbols would put U+066x in here beside U+06Fx, which is
      // exactly why it was rejected for ckb.
      for (final r in digits) {
        expect(r, isNot(inInclusiveRange(0x0660, 0x0669)));
      }
    }
  });

  test('the display bridge is UTC-only', () {
    // Constructing a LOCAL instant from a LocalDate is how a Jalali date lands
    // one day off for everyone east of UTC — on the screen where the patient
    // checks which day they are on.
    final bridged = fixture.toUtcMidnight();

    expect(bridged.isUtc, isTrue);
    expect((bridged.year, bridged.month, bridged.day), (2025, 4, 16));
    expect(bridged.hour, 0);
  });

  test('every month name list has twelve entries and weekdays seven', () {
    for (final locale in kSupportedLocales) {
      final l10n = lookupAppLocalizations(locale);

      expect(l10n.ckbMonthNames.split('|'), hasLength(12), reason: '$locale');
      expect(l10n.ckbWeekdayNames.split('|'), hasLength(7), reason: '$locale');
    }
  });
}
