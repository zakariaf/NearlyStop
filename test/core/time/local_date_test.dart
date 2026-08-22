// Pure `package:test`. LocalDate is a calendar value, not an instant, and every
// assertion here is about the calendar.
//
// The BAN on constructing a local instant from a LocalDate is a review and
// `tool/check_bans.sh` matter, not something this file can assert: Dart cannot
// change the process's local zone in-process. The zone-sensitive claim is
// proven instead by CI re-running this directory under a second zone
// (`TZ=Europe/Berlin flutter test test/core/time/`).
import 'dart:math';

import 'package:nearlystop/core/time/local_date.dart';
import 'package:test/test.dart';

void main() {
  group('addDays', () {
    test('crosses the two European DST edges as plain calendar days', () {
      expect(
        const LocalDate(2026, 3, 28).addDays(1),
        const LocalDate(2026, 3, 29),
      );
      expect(
        const LocalDate(2026, 10, 24).addDays(1),
        const LocalDate(2026, 10, 25),
      );
    });

    test('crosses a leap day and a year boundary', () {
      expect(
        const LocalDate(2028, 2, 28).addDays(1),
        const LocalDate(2028, 2, 29),
      );
      expect(
        const LocalDate(2026, 12, 31).addDays(1),
        const LocalDate(2027, 1, 1),
      );
    });

    test('goes backwards', () {
      expect(
        const LocalDate(2026, 1, 1).addDays(-1),
        const LocalDate(2025, 12, 31),
      );
    });
  });

  group('difference', () {
    test('counts calendar days, signed', () {
      expect(
        const LocalDate(2026, 4, 30).difference(const LocalDate(2026, 4, 1)),
        29,
      );
      expect(
        const LocalDate(2026, 4, 1).difference(const LocalDate(2026, 4, 30)),
        -29,
      );
      expect(
        const LocalDate(2026, 4, 1).difference(const LocalDate(2026, 4, 1)),
        0,
      );
    });
  });

  group('iso', () {
    test('formats zero-padded yyyy-MM-dd and parses it back', () {
      expect(const LocalDate(2026, 4, 1).toIso8601(), '2026-04-01');
      expect(LocalDate.parse('2026-04-01'), const LocalDate(2026, 4, 1));
      expect(LocalDate.tryParse('not a date'), isNull);
      expect(LocalDate.tryParse('2026-13-01'), isNull);
    });
  });

  group('toUtcMidnight', () {
    test('is UTC at hour zero', () {
      for (final date in const [
        LocalDate(2026, 1, 1),
        LocalDate(2026, 3, 29),
        LocalDate(2028, 2, 29),
      ]) {
        final instant = date.toUtcMidnight();
        expect(instant.isUtc, isTrue, reason: '$date');
        expect(instant.hour, 0, reason: '$date');
        expect(instant.year, date.year);
        expect(instant.month, date.month);
        expect(instant.day, date.day);
      }
    });
  });

  group('ordering', () {
    test('compares chronologically', () {
      expect(const LocalDate(2026, 4, 1) < const LocalDate(2026, 4, 2), isTrue);
      expect(
        const LocalDate(2026, 5, 1) > const LocalDate(2026, 4, 30),
        isTrue,
      );
      expect(
        const LocalDate(2026, 4, 1) <= const LocalDate(2026, 4, 1),
        isTrue,
      );
      expect(
        const LocalDate(2026, 4, 1) >= const LocalDate(2026, 4, 1),
        isTrue,
      );
      final dates = <LocalDate>[
        const LocalDate(2026, 5, 1),
        const LocalDate(2026, 4, 1),
        const LocalDate(2025, 12, 31),
      ]..sort();
      expect(dates.first, const LocalDate(2025, 12, 31));
      expect(dates.last, const LocalDate(2026, 5, 1));
    });
  });

  group('fuzz against an independent DateTime.utc oracle', () {
    test('iso round-trips and addDays/difference agree for n in -400..400', () {
      final rng = Random(20260421);
      for (var seed = 0; seed < 3000; seed++) {
        final epoch = DateTime.utc(2020);
        final oracle = epoch.add(Duration(days: rng.nextInt(4000)));
        final date = LocalDate(oracle.year, oracle.month, oracle.day);
        final n = rng.nextInt(801) - 400;

        expect(
          LocalDate.parse(date.toIso8601()),
          date,
          reason: 'seed=$seed date=$date',
        );

        final shifted = date.addDays(n);
        final oracleShifted = oracle.add(Duration(days: n));
        expect(
          shifted,
          LocalDate(oracleShifted.year, oracleShifted.month, oracleShifted.day),
          reason: 'seed=$seed date=$date n=$n',
        );
        expect(
          shifted.difference(date),
          n,
          reason: 'seed=$seed date=$date n=$n',
        );
      }
    });
  });
}
