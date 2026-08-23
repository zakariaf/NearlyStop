// No screen ships golden-only.
//
// A golden proves a screen LOOKS the same as last time. It cannot tell you
// that the button does anything, and a screen whose only test is a picture is
// a screen where every behaviour is unasserted while the suite reads green.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  /// Every screen in the app, and the directory its tests live in.
  const screens = <String, String>{
    'Today': 'test/features/today',
    'Schedule': 'test/features/schedule',
    'Progress': 'test/features/progress',
    'Plan': 'test/features/plan',
    'Settings': 'test/features/settings',
    'Welcome': 'test/features/welcome',
  };

  for (final MapEntry<String, String>(key: screen, value: directory)
      in screens.entries) {
    test('$screen has a test that is not a golden', () {
      final dir = Directory(directory);
      expect(dir.existsSync(), isTrue, reason: '$directory is missing');

      final behavioural = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('_test.dart'))
          .where((file) => !file.path.contains('golden'))
          // A file that only captures pictures under another name is still a
          // golden file: the tag is what the golden lane selects on, so the
          // tag is what this reads.
          .where(
            (file) =>
                !file.readAsStringSync().contains("@Tags(<String>['golden'])"),
          )
          .toList();

      expect(
        behavioural,
        isNotEmpty,
        reason: '$screen has only golden tests — nothing asserts what it does',
      );
    });
  }
}
