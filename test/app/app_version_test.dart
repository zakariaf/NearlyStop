// The version the About card shows IS the version in pubspec.yaml.
//
// It is generated rather than read from the platform, because reading it from
// the platform costs `package_info_plus`, which pulls `package:http` into the
// shipped binary. A network client in an app whose whole premise is that it
// has no network path is not a dependency this project can carry — and the
// version is a build-time constant, not a runtime question.
import 'dart:io';

import 'package:nearlystop/app/app_version.dart';
import 'package:test/test.dart';

void main() {
  /// `version: 1.2.3+45` from pubspec.yaml, as (name, semver, build).
  (String, String, String) fromPubspec() {
    final lines = File('pubspec.yaml').readAsLinesSync();
    String field(String key) => lines
        .firstWhere((line) => line.startsWith('$key:'))
        .substring(key.length + 1)
        .trim();
    final version = field('version').split('+');
    return (field('name'), version.first, version.last);
  }

  test('the generated constants are the pubspec', () {
    final (name, semver, build) = fromPubspec();

    expect(kAppPackageName, name);
    expect(kAppVersion, semver);
    expect(kAppBuildNumber, build);
  });

  test('the displayed version reads as the About card shows it', () {
    expect(kAppVersionLabel, '$kAppVersion ($kAppBuildNumber)');
  });

  test('nothing here is empty', () {
    // A generator that wrote empty strings would pass a shape check and put a
    // blank line under "Version" on the one screen a reader checks before
    // reporting a problem.
    for (final value in <String>[
      kAppPackageName,
      kAppVersion,
      kAppBuildNumber,
      kAppVersionLabel,
    ]) {
      expect(value, isNotEmpty);
    }
  });
}
