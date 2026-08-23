// Route paths, as data.
//
// Small, but the file it guards is the reason a typo'd navigation is a compile
// error rather than a silent trip to the error page.
import 'package:nearlystop/routing/routes.dart';
import 'package:test/test.dart';

void main() {
  test('the five branches are the five tab destinations, in order', () {
    expect(Routes.branches, <String>[
      Routes.today,
      Routes.schedule,
      Routes.progress,
      Routes.plan,
      Routes.settings,
    ]);
  });

  test('every path is absolute and distinct', () {
    const all = <String>[
      Routes.welcome,
      ...Routes.branches,
      Routes.disclaimerReread,
    ];

    for (final path in all) {
      expect(path, startsWith('/'), reason: path);
      expect(path, isNot(endsWith('/')), reason: path);
    }
    expect(all.toSet(), hasLength(all.length), reason: 'a duplicate path');
  });

  test('the re-read is a CHILD of settings, not a sibling of welcome', () {
    // Its parent decides where back goes. Under Settings, back returns to
    // Settings with that tab's stack intact; as a top-level route it would
    // dump the user on Today.
    expect(Routes.disclaimerReread, startsWith('${Routes.settings}/'));
    expect(Routes.disclaimerReread, isNot(startsWith(Routes.welcome)));
  });

  test('the gate is OUTSIDE the shell', () {
    // If /welcome were a branch the tab bar would render behind it, and the
    // gate would be one tap from being bypassed.
    expect(Routes.branches, isNot(contains(Routes.welcome)));
  });
}
