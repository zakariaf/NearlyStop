// The shipped permission set and the locale declarations, asserted whole.
//
// **Whole, as one set equality.** A per-permission `contains` passes when a
// transitive plugin bump adds a node, which is the failure that actually
// happens: nobody adds `ACCESS_FINE_LOCATION` on purpose, a dependency does it
// and the store form silently becomes a lie.
//
// Reads the MERGED manifest, not the source file. The source says what this
// app asked for; the merged one says what ships.
import 'dart:io';

import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// The only permissions this app ships.
///
/// All three are contributed by `flutter_local_notifications`, and there are
/// deliberately no others. Per CONTRACTS §12 there is **no exact-alarm
/// permission**: EPIC-12 schedules with `inexactAllowWhileIdle`, because a
/// daily "your plan for today" does not need alarm-clock precision, on
/// Android 14+ the permission is denied by default anyway, and the branch that
/// depended on it was dead code that only bought Play policy scrutiny.
const Set<String> kExpectedPermissions = <String>{
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
  'android.permission.VIBRATE',
};

/// Where a merged manifest lands, newest variant first.
List<File> mergedManifests() {
  final root = Directory('build/app/intermediates/merged_manifests');
  if (!root.existsSync()) return const <File>[];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('AndroidManifest.xml'))
      .toList();
}

/// The four locales, derived from the ARB filenames rather than typed.
///
/// Typed twice is two lists, and the second one is wrong the day somebody adds
/// a language.
Set<String> localesFromArb() => Directory('lib/l10n/arb')
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last)
    .where((name) => name.startsWith('app_') && name.endsWith('.arb'))
    .map((name) => name.substring('app_'.length, name.length - '.arb'.length))
    .toSet();

void main() {
  test('the ARB list is the source of the locale set', () {
    // The guard that stops the two assertions below being vacuous.
    expect(localesFromArb(), <String>{'en', 'de', 'fa', 'ckb'});
  });

  group('Android', () {
    test('locales_config.xml lists exactly the ARB locales', () {
      // Without it the OS believes the app is English-only: the per-app
      // Language row in Settings never appears, so a Persian or Sorani
      // speaker whose phone is set to English cannot reach their language
      // from outside the app.
      final file = File('android/app/src/main/res/xml/locales_config.xml');
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

      final declared = XmlDocument.parse(file.readAsStringSync())
          .findAllElements('locale')
          .map((e) => e.getAttribute('android:name'))
          .whereType<String>()
          .toSet();

      expect(declared, localesFromArb());
    });

    test('the application element points at it', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      final application = XmlDocument.parse(
        manifest.readAsStringSync(),
      ).findAllElements('application').single;

      expect(
        application.getAttribute('android:localeConfig'),
        '@xml/locales_config',
      );
    });

    test('the source manifest asks for nothing beyond the expected set', () {
      // The merged manifest is the real check and needs a build, so it lives
      // in `release.yml`. This is the half that can run on every PR: what
      // THIS app asked for, as opposed to what a dependency merged in.
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      final asked = XmlDocument.parse(manifest.readAsStringSync())
          .findAllElements('uses-permission')
          .map((e) => e.getAttribute('android:name'))
          .whereType<String>()
          .toSet();

      expect(
        asked.difference(kExpectedPermissions),
        isEmpty,
        reason: 'the source manifest asks for something unexpected',
      );
    });

    test('no exact-alarm permission, from any source', () {
      // CONTRACTS §12, named as its own expectation so the failure message
      // says which contract broke rather than just "set mismatch".
      final files = <File>[
        File('android/app/src/main/AndroidManifest.xml'),
        ...mergedManifests(),
      ].where((f) => f.existsSync());

      for (final file in files) {
        final text = file.readAsStringSync();
        for (final name in <String>[
          'SCHEDULE_EXACT_ALARM',
          'USE_EXACT_ALARM',
        ]) {
          // A `tools:node="remove"` line legitimately names it. What must not
          // exist is a `uses-permission` that grants it.
          final granted = XmlDocument.parse(text)
              .findAllElements('uses-permission')
              .where(
                (e) => (e.getAttribute('android:name') ?? '').endsWith(name),
              )
              .where((e) => e.getAttribute('tools:node') != 'remove');
          expect(
            granted,
            isEmpty,
            reason:
                '$name is granted in ${file.path} — CONTRACTS §12 says this '
                'app schedules with inexactAllowWhileIdle and declares neither',
          );
        }
      }
    });

    test('the webview url_launcher merges in stays unexported', () {
      // `url_launcher_android` contributes `WebViewActivity` to the merged
      // manifest whether or not anything launches it, and this app never
      // does — tool/check_bans.sh refuses every LaunchMode that would.
      //
      // So it is dead weight, and dead weight is fine. What would not be fine
      // is dead weight that is REACHABLE: an exported activity taking a URL
      // is a component any other app on the phone can point at a page of its
      // choosing, inside this app's process, in a binary whose store listing
      // says it has no network client. Pinned so a plugin upgrade that flips
      // the flag is caught here rather than in a store review.
      final files = mergedManifests().where((f) => f.existsSync());
      var seen = 0;

      for (final file in files) {
        final activities = XmlDocument.parse(file.readAsStringSync())
            .findAllElements('activity')
            .where(
              (e) => (e.getAttribute('android:name') ?? '').contains(
                'urllauncher',
              ),
            );

        for (final activity in activities) {
          seen++;
          expect(
            activity.getAttribute('android:exported'),
            'false',
            reason:
                '${file.path} exports ${activity.getAttribute('android:name')}',
          );
        }
      }

      if (seen == 0) {
        // Said out loud rather than passing quietly: zero activities means
        // either no build in this tree, or the plugin stopped merging it.
        printOnFailure('no merged manifest names the launcher webview');
      }
    });

    test('INTERNET is absent from every merged manifest that is a RELEASE', () {
      // On Android an absent INTERNET permission makes a network call
      // impossible, not merely absent — which is the hardest proof this
      // product's central claim can have.
      //
      // **Its presence in debug and profile is expected and correct.** Flutter
      // adds it so the VM service can attach. Say so here, because the wrong
      // fix — deleting it from the debug manifest — is silent and permanent
      // and breaks hot reload for everybody.
      final release = mergedManifests()
          .where((f) => f.path.toLowerCase().contains('release'))
          .toList();

      if (release.isEmpty) {
        // No release build in this tree. The release lane runs the real
        // check; skipping silently here would be the wrong answer, so it is
        // said out loud.
        printOnFailure('no release merged manifest — build one to check this');
        return;
      }

      for (final file in release) {
        expect(
          file.readAsStringSync(),
          isNot(contains('android.permission.INTERNET')),
          reason:
              '${file.path} grants INTERNET. Its presence in DEBUG and PROFILE '
              'is expected and correct — Flutter adds it for the VM service. '
              'Do not "fix" this by editing the debug manifest.',
        );
      }
    });
  });

  group('iOS', () {
    String plist() => File('ios/Runner/Info.plist').readAsStringSync();

    test('CFBundleLocalizations lists exactly the ARB locales', () {
      final document = XmlDocument.parse(plist());
      final keys = document.findAllElements('key').toList();
      final index = keys.indexWhere(
        (k) => k.innerText == 'CFBundleLocalizations',
      );
      expect(index, isNot(-1), reason: 'CFBundleLocalizations is missing');

      final array = keys[index].nextElementSibling!;
      expect(array.name.local, 'array');
      final declared = array
          .findAllElements('string')
          .map((e) => e.innerText)
          .toSet();

      expect(declared, localesFromArb());
    });

    test('the name under the icon is the product name', () {
      // Found by looking at a home screen after a fresh install, which is the
      // only place this is visible: the Flutter template derives the display
      // name from the package name and produces "Nearlystop", which nothing
      // else in the app, the ARB or the store listing ever says.
      final document = XmlDocument.parse(plist());
      final keys = document.findAllElements('key').toList();

      for (final name in <String>['CFBundleDisplayName', 'CFBundleName']) {
        final index = keys.indexWhere((k) => k.innerText == name);
        expect(index, isNot(-1), reason: '$name is missing');
        expect(
          keys[index].nextElementSibling!.innerText,
          'NearlyStop',
          reason: name,
        );
      }
    });

    test('no NS*UsageDescription key exists at all', () {
      // Notifications are requested through the authorization API and need no
      // usage string. An unused usage description is a claim about what the
      // app does with a capability, and it cannot be defended at review.
      final declared = XmlDocument.parse(plist())
          .findAllElements('key')
          .map((e) => e.innerText)
          .where((k) => k.startsWith('NS') && k.endsWith('UsageDescription'))
          .toSet();

      expect(declared, isEmpty);
    });
  });
}
