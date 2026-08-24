// The app's own text-scale multiplier, composed with the OS scaler.
//
// `f(input) → output`, so no widget is pumped for the arithmetic; the one
// widget case is the composition reaching a `Text` through the real layer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/composed_text_scaler.dart';

import '../support/harness.dart';

void main() {
  test('the app factor MULTIPLIES the OS scaler, it does not replace it', () {
    // Replacing it discards the setting this audience is most likely to have
    // already found in their phone.
    const scaler = ComposedTextScaler(TextScaler.linear(1.5), 1.3);

    expect(scaler.scale(16), closeTo(31.2, 1e-9));
  });

  test('with the factor at 1.0 the OS value passes through untouched', () {
    // SPEC 10: usable at the LARGEST OS text size. The app never shrinks the
    // user's own choice, at any value.
    for (final base in <double>[0.5, 1, 3, 3.1]) {
      final scaler = ComposedTextScaler(TextScaler.linear(base), 1);
      expect(
        scaler.scale(16),
        closeTo(TextScaler.linear(base).scale(16), 1e-9),
        reason: 'base $base',
      );
    }
  });

  test('the PRODUCT is capped, and the cap is read from the constant', () {
    // iOS AX5 is ~3.1×; with the slider at 2.0 the product is 6.2×, which no
    // golden renders and no 320pt device survives. The cap bounds the product
    // ONLY — it never applies when the slider is at 1.0, because the layer
    // does not wrap at all then.
    const scaler = ComposedTextScaler(TextScaler.linear(3), 2);

    expect(scaler.scale(16), 16 * kMaxComposedTextScale);
    expect(kMaxComposedTextScale, 4.0);
  });

  test('a seeded sweep agrees with an independent oracle', () {
    var seed = 7;
    int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;

    for (var run = 0; run < 500; run++) {
      final base = 0.5 + (next() % 3000) / 1000;
      final factor = 1 + (next() % 1000) / 1000;
      final fontSize = 8 + (next() % 32).toDouble();

      final actual = ComposedTextScaler(
        TextScaler.linear(base),
        factor,
      ).scale(fontSize);
      final oracle =
          (base * factor * fontSize) < fontSize * kMaxComposedTextScale
          ? base * factor * fontSize
          : fontSize * kMaxComposedTextScale;

      expect(
        actual,
        closeTo(oracle, 1e-9),
        reason: 'base $base × factor $factor on $fontSize',
      );
    }
  });

  test('equality follows both halves, so MediaQuery rebuilds', () {
    // A `TextScaler` that compares equal after the factor changed is a screen
    // that never re-lays-out when the slider moves.
    const a = ComposedTextScaler(TextScaler.linear(1.5), 1.3);
    const b = ComposedTextScaler(TextScaler.linear(1.5), 1.3);
    const c = ComposedTextScaler(TextScaler.linear(1.5), 1.4);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('textScaleFactor composes too', () {
    // Deprecated upstream but still ABSTRACT on `TextScaler`, so a subclass
    // cannot compile without it. This test is what stops a reader deleting it.
    const scaler = ComposedTextScaler(TextScaler.linear(1.5), 1.2);

    expect(scaler.textScaleFactor, closeTo(1.8, 1e-9));
  });

  testWidgets('the composition reaches a Text through the real layer', (
    tester,
  ) async {
    late TextScaler resolved;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          resolved = MediaQuery.textScalerOf(context);
          return const SizedBox.shrink();
        },
      ),
      textScaler: const TextScaler.linear(1.5),
      userTextScale: 1.3,
    );

    expect(resolved, isA<ComposedTextScaler>());
    expect(resolved.scale(16), closeTo(31.2, 1e-9));
  });
}
