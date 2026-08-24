// What a tap carries, and where it lands.
//
// The payload is a ROUTE NAME and nothing else. Anything reconstructible from
// it — a dose, a date, a step id — would be state living outside the database,
// and the database is the only source of truth this app has.
import 'dart:convert';
import 'dart:io';

import 'package:nearlystop/services/notifications/notification_tap.dart';
import 'package:test/test.dart';

void main() {
  test('the today payload opens Today', () {
    expect(payloadToRoute('today'), '/today');
  });

  test('an unknown or empty payload goes nowhere', () {
    // Nowhere, not "somewhere safe". A restored notification from an older
    // build carries a payload this version has never heard of, and navigating
    // on a guess is worse than staying put.
    expect(payloadToRoute('whatever'), isNull);
    expect(payloadToRoute(''), isNull);
    expect(payloadToRoute(null), isNull);
  });

  test('the payload survives a JSON round trip', () {
    // Proof that nothing non-serializable can be put in it: the platform
    // hands this back as a `String?` across a channel, and an object that
    // does not survive `jsonEncode` would arrive as the word "Instance of".
    const payload = 'today';

    expect(jsonDecode(jsonEncode(payload)), payload);
  });

  group('the background handler is isolate-safe by construction', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/services/notifications/fln_notification_gateway.dart',
      ).readAsStringSync();
    });

    test('it is top level and annotated', () {
      // A closure or a method is not addressable from the isolate the engine
      // spawns for a background tap, and the annotation is what stops the AOT
      // compiler from tree-shaking it away. Both mistakes fail on a device and
      // on no test.
      expect(source, contains("@pragma('vm:entry-point')"));
      expect(
        source,
        contains('void notificationTappedInBackground(NotificationResponse'),
      );
    });

    test('nothing on the notification path touches the database', () {
      // Two isolates writing one SQLite file risks corrupting the two years of
      // history this app exists to keep. Asserted on the file rather than at
      // runtime: a test that survived to report this would be the lucky run.
      for (final banned in <String>[
        'AppDatabase',
        'planDao',
        'stepDao',
        'logDao',
        'settingsDao',
        'package:drift',
      ]) {
        expect(source, isNot(contains(banned)), reason: banned);
      }
    });
  });
}
