// The five Material 3 window size classes, at their boundaries.
//
// Boundaries only. A test at 700 proves nothing a test at 599/600 does not,
// and every adaptive bug this repo has had lived on the edge: `>` where `>=`
// was meant, a rail that appeared one pixel late on a 600pt tablet.
import 'package:nearlystop/app/window_size.dart';
import 'package:test/test.dart';

void main() {
  const cases = <(double, WindowSizeClass)>[
    (0, WindowSizeClass.compact),
    (599.99, WindowSizeClass.compact),
    (600, WindowSizeClass.medium),
    (839.99, WindowSizeClass.medium),
    (840, WindowSizeClass.expanded),
    (1199.99, WindowSizeClass.expanded),
    (1200, WindowSizeClass.large),
    (1599.99, WindowSizeClass.large),
    (1600, WindowSizeClass.extraLarge),
  ];

  for (final (width, expected) in cases) {
    test('$width is ${expected.name}', () {
      expect(WindowSizeClass.forWidth(width), expected);
    });
  }

  test('the classes are ordered widest-last, so >= compares as it reads', () {
    expect(
      WindowSizeClass.values,
      orderedEquals(<WindowSizeClass>[
        WindowSizeClass.compact,
        WindowSizeClass.medium,
        WindowSizeClass.expanded,
        WindowSizeClass.large,
        WindowSizeClass.extraLarge,
      ]),
    );
    expect(WindowSizeClass.expanded.isAtLeast(WindowSizeClass.medium), isTrue);
    expect(WindowSizeClass.medium.isAtLeast(WindowSizeClass.expanded), isFalse);
    expect(WindowSizeClass.medium.isAtLeast(WindowSizeClass.medium), isTrue);
  });

  test('a negative width is compact, not a crash', () {
    // `MediaQuery.sizeOf` is zero during the first frame of some embedders.
    expect(WindowSizeClass.forWidth(-1), WindowSizeClass.compact);
  });
}
