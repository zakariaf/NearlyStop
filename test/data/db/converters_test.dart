// Pure `package:test`: a TypeConverter is f(input) -> output and needs no
// database. Every conversion gets a ROUND TRIP and boundary goldens, because a
// converter that is wrong in one direction only is a converter that passes a
// spot check and loses a patient's data.
import 'dart:math';

import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/converters.dart';
import 'package:test/test.dart';

void main() {
  group('MilligramsConverter', () {
    // The SQL type parameter is `int`, so declaring
    // `TypeConverter<Milligrams, double>` stops this file compiling — which is
    // the point. A dose is never a REAL column.
    const converter = MilligramsConverter();

    test('stores hundredths, both ways', () {
      expect(converter.toSql(const Milligrams.fromHundredths(25)), 25);
      expect(converter.fromSql(25), const Milligrams.fromHundredths(25));
    });

    test('round-trips every dose from 0.25mg to 60mg in 0.25 steps', () {
      for (var h = 25; h <= 6000; h += 25) {
        final value = Milligrams.fromHundredths(h);
        expect(
          converter.fromSql(converter.toSql(value)).hundredths,
          h,
          reason: '$h hundredths',
        );
      }
    });
  });

  group('LocalDateConverter', () {
    const converter = LocalDateConverter();

    test('zero-pads, which the naive interpolation gets wrong', () {
      expect(converter.toSql(const LocalDate(2026, 1, 5)), '2026-01-05');
    });

    test('round-trips the leap day and both year boundaries', () {
      for (final date in const <LocalDate>[
        LocalDate(2028, 2, 29),
        LocalDate(2026, 1, 1),
        LocalDate(2026, 12, 31),
      ]) {
        expect(converter.fromSql(converter.toSql(date)), date, reason: '$date');
      }
    });

    test('round-trips a seeded 2,000-date sample', () {
      final rng = Random(20260421);
      final epoch = DateTime.utc(2020);
      for (var seed = 0; seed < 2000; seed++) {
        final moment = epoch.add(Duration(days: rng.nextInt(4000)));
        final date = LocalDate(moment.year, moment.month, moment.day);
        expect(
          converter.fromSql(converter.toSql(date)),
          date,
          reason: 'seed=$seed date=$date',
        );
      }
    });

    test('throws on anything that is not yyyy-MM-dd', () {
      // The DAO turns this into StorageFailure.corrupt rather than crashing.
      expect(() => converter.fromSql('2026-4-16'), throwsFormatException);
      expect(() => converter.fromSql('16/04/2026'), throwsFormatException);
    });
  });

  group('StrengthListConverter', () {
    const converter = StrengthListConverter();

    test('sorts descending and deduplicates on write', () {
      expect(
        converter.toSql(<Milligrams>[
          const Milligrams.fromHundredths(100),
          const Milligrams.fromHundredths(500),
          const Milligrams.fromHundredths(100),
        ]),
        '500,100',
      );
    });

    test('round-trips a six-strength list', () {
      final held = <Milligrams>[
        for (final mg in <num>[25, 20, 10, 5, 2.5, 1])
          Milligrams.fromHundredths((mg * 100).round()),
      ];
      expect(converter.fromSql(converter.toSql(held)), held);
    });

    test("an empty string is an empty list — rejecting it is the repository's "
        "job, not the encoding's", () {
      expect(converter.fromSql(''), isEmpty);
    });

    test('throws on a malformed list', () {
      expect(() => converter.fromSql('500,abc'), throwsFormatException);
    });
  });

  group('TaperMethodConverter', () {
    const converter = TaperMethodConverter();

    test('all three arms round-trip through name', () {
      for (final method in TaperMethod.values) {
        expect(converter.fromSql(converter.toSql(method)), method);
      }
      expect(converter.toSql(TaperMethod.fixedMg), 'fixedMg');
    });

    test('an unknown method throws, which becomes Corrupt', () {
      expect(() => converter.fromSql('weekly'), throwsFormatException);
    });
  });

  group('StepStatusConverter', () {
    const converter = StepStatusConverter();

    test('all four arms round-trip through name', () {
      for (final status in StepStatus.values) {
        expect(converter.fromSql(converter.toSql(status)), status);
      }
    });

    test('an unknown status throws', () {
      expect(() => converter.fromSql('paused'), throwsFormatException);
    });
  });

  group('UtcInstantConverter', () {
    const converter = UtcInstantConverter();

    test('an instant is UTC epoch ms, and comes back as UTC', () {
      final moment = DateTime.utc(2026, 4, 16, 7, 30);

      expect(converter.toSql(moment), moment.millisecondsSinceEpoch);
      expect(converter.fromSql(converter.toSql(moment)), moment);
      expect(converter.fromSql(converter.toSql(moment)).isUtc, isTrue);
    });

    test('a LOCAL instant is normalised to UTC on write', () {
      // The bug this converter exists to make impossible: a caller handing in
      // `DateTime.now()` — local — and the zone offset being stored as if it
      // were UTC. It must round-trip equal AS AN INSTANT, and come back UTC.
      final local = DateTime(2026, 4, 16, 7, 30);

      final read = converter.fromSql(converter.toSql(local));

      expect(read.isUtc, isTrue);
      expect(read.isAtSameMomentAs(local), isTrue);
      expect(converter.toSql(local), local.toUtc().millisecondsSinceEpoch);
    });

    test('the epoch and a pre-epoch instant both survive', () {
      for (final moment in <DateTime>[
        DateTime.utc(1970),
        DateTime.utc(1969, 12, 31, 23, 59, 59),
        DateTime.utc(2038, 1, 19, 3, 14, 8),
      ]) {
        expect(
          converter.fromSql(converter.toSql(moment)),
          moment,
          reason: '$moment',
        );
      }
    });
  });
}
