// Pure `package:test`: no flutter_test, no widget binding. Milligrams is
// f(input) -> output, so this is the cheapest tier that can assert it.
import 'dart:math';

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/unit_failure.dart';
import 'package:test/test.dart';

Milligrams mg(int hundredths) => Milligrams.fromHundredths(hundredths);

void main() {
  group('toDisplayString', () {
    test('trims trailing zeros and uses no locale separator', () {
      expect(mg(950).toDisplayString(), '9.5');
      expect(mg(25).toDisplayString(), '0.25');
      expect(mg(900).toDisplayString(), '9');
      expect(mg(1000).toDisplayString(), '10');
      expect(mg(0).toDisplayString(), '0');
      expect(mg(5).toDisplayString(), '0.05');
      expect(mg(125).toDisplayString(), '1.25');
      expect(mg(600000).toDisplayString(), '6000');
    });
  });

  group('parse', () {
    test('round-trips every dose from 0.25mg to 60mg in 0.25 steps', () {
      for (var h = 25; h <= 6000; h += 25) {
        final value = mg(h);
        final parsed = Milligrams.parse(value.toDisplayString());
        expect(
          parsed,
          Ok<Milligrams, UnitFailure>(value),
          // `==` on the integer hundredths, never closeTo: a dose that is
          // "close enough" is a dose someone swallows.
          reason: 'round trip failed at $h hundredths',
        );
      }
    });

    test('accepts a padded fraction and a leading dot', () {
      expect(Milligrams.parse('9.50'), Ok<Milligrams, UnitFailure>(mg(950)));
      expect(Milligrams.parse('.5'), Ok<Milligrams, UnitFailure>(mg(50)));
    });

    test('rejects everything that is not a plain two-decimal number', () {
      for (final input in ['9.005', '', '-1', '9,5', 'abc', '9.', '1e3']) {
        expect(
          Milligrams.parse(input),
          isA<Err<Milligrams, UnitFailure>>(),
          reason: 'accepted $input',
        );
      }
    });

    test('names why it rejected, so the presentation layer can say it', () {
      // A Failure is switched on, never compared by value (it carries no
      // `==` on purpose), so assert the variant and its payload.
      UnitFailure failureOf(String input) =>
          (Milligrams.parse(input) as Err<Milligrams, UnitFailure>).failure;

      expect(
        failureOf('9.005'),
        isA<DoseTooPrecise>()
            .having((f) => f.input, 'input', '9.005')
            .having((f) => f.code, 'code', 'unit.dose_too_precise'),
      );
      expect(
        failureOf('-1'),
        isA<NegativeDose>().having((f) => f.input, 'input', '-1'),
      );
      expect(
        failureOf('9,5'),
        isA<InvalidDoseFormat>().having((f) => f.input, 'input', '9,5'),
      );
    });
  });

  group('arithmetic a double implementation gets wrong', () {
    test('10mg - 9.9mg is exactly 10 hundredths', () {
      expect((mg(1000) - mg(990)).hundredths, 10);
    });

    test('0.1mg + 0.2mg is exactly 30 hundredths', () {
      expect((mg(10) + mg(20)).hundredths, 30);
    });

    test('0.1mg * 3 is exactly 30 hundredths', () {
      expect((mg(10) * 3).hundredths, 30);
    });
  });

  group('half', () {
    test('halves an even number of hundredths', () {
      expect(mg(50).half(), Ok<Milligrams, UnitFailure>(mg(25)));
      expect(mg(1000).half(), Ok<Milligrams, UnitFailure>(mg(500)));
    });

    test('refuses an odd number rather than rounding to 12 or 13', () {
      final result = mg(25).half();
      expect(result, isA<Err<Milligrams, UnitFailure>>());
      expect(
        (result as Err<Milligrams, UnitFailure>).failure,
        isA<DoseNotHalvable>().having((f) => f.hundredths, 'hundredths', 25),
      );
    });
  });

  group('ordering and equality', () {
    test('compares and equates on the integer hundredths', () {
      expect(mg(950), mg(950));
      expect(mg(950).hashCode, mg(950).hashCode);
      expect(mg(950) == mg(951), isFalse);
      expect(mg(100) < mg(101), isTrue);
      expect(mg(100) <= mg(100), isTrue);
      expect(mg(101) > mg(100), isTrue);
      expect(mg(100) >= mg(100), isTrue);
      expect(<Milligrams>[mg(300), mg(100), mg(200)]..sort(), <Milligrams>[
        mg(100),
        mg(200),
        mg(300),
      ]);
      expect(Milligrams.zero.isZero, isTrue);
    });
  });

  group('fuzz', () {
    test('parse(toDisplayString(m)) == m for random doses', () {
      final rng = Random(20260421);
      for (var seed = 0; seed < 3000; seed++) {
        final h = rng.nextInt(600001);
        final value = mg(h);
        expect(
          Milligrams.parse(value.toDisplayString()),
          Ok<Milligrams, UnitFailure>(value),
          reason: 'seed=$seed hundredths=$h text=${value.toDisplayString()}',
        );
      }
    });
  });
}
