// The static gate, driven over a fixture tree in BOTH directions.
//
// A grep rule that has never matched anything is a grep rule with a typo in
// it, and an absence-of-a-failure-class rule passes vacuously the day it is
// written. So every rule asserted here gets a file that trips it AND a file
// that must not.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('nearlystop_bans');
    Directory('${root.path}/lib').createSync(recursive: true);
    File(
      '${root.path}/analysis_options.yaml',
    ).writeAsStringSync('analyzer:\n  errors:\n');
  });
  tearDown(() => root.deleteSync(recursive: true));

  void write(String relative, String source) {
    File('${root.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);
  }

  Future<ProcessResult> runGate() => Process.run('bash', <String>[
    '${Directory.current.path}/tool/check_bans.sh',
    root.path,
  ]);

  group('the Schedule may not become a calendar', () {
    /// Every needle, with a line that trips it.
    const offenders = <String, String>{
      'GridView': 'final w = GridView.count(crossAxisCount: 7);',
      'SliverGrid': 'final w = SliverGrid.count(crossAxisCount: 7);',
      'GridDelegate': 'final d = SliverGridDelegateWithFixedCrossAxisCount();',
      'table_calendar': "import 'package:table_calendar/table_calendar.dart';",
      'CalendarDatePicker': 'final w = CalendarDatePicker();',
      'showDatePicker': 'final f = showDatePicker(context: c);',
    };

    for (final MapEntry<String, String>(key: needle, value: line)
        in offenders.entries) {
      test('$needle in the Schedule feature turns the build red', () async {
        write(
          'lib/features/schedule/presentation/planted.dart',
          '/// Scratch.\n$line\n',
        );

        final result = await runGate();
        final output = '${result.stdout}${result.stderr}';

        expect(result.exitCode, 1, reason: needle);
        expect(output, contains('planted.dart'));
        expect(
          output,
          contains('SPEC.md 4.2'),
          reason: 'the failure must say WHY, not just fail',
        );
      });
    }

    test('date ENTRY stays legal in the Plan feature', () async {
      // The counter-case. The ban is about rendering a taper as a month grid,
      // not about ever asking someone for a date; scoping it to the Schedule
      // directory is how the rule says so precisely.
      write(
        'lib/features/plan/presentation/plan_screen.dart',
        '/// Scratch.\nfinal f = showDatePicker(context: c);\n',
      );

      final result = await runGate();

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}${result.stderr}',
      );
    });

    test('a grid elsewhere in the app is not this rule’s business', () async {
      write(
        'lib/features/progress/presentation/planted.dart',
        '/// Scratch.\nfinal w = GridView.count(crossAxisCount: 2);\n',
      );

      final result = await runGate();

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}${result.stderr}',
      );
    });
  });

  group('no numeral literal outside lib/l10n', () {
    // EPIC-03's rule, extended: the Perso-Arabic DECIMAL SEPARATOR is the
    // character the original class missed, and it is the one that matters
    // most. A field whose formatter allows a literal `\u066B` while the parser
    // reads its separator from intl symbol data accepts a keystroke it then
    // refuses, with nothing on screen to tell the two apart.
    const offenders = <String, String>{
      'a digit': "const s = '\u06F5';",
      'a digit range': "final r = RegExp('[0-9\u0660-\u0669]');",
      'the decimal separator': "const sep = '\u066B';",
      'the thousands separator': "const sep = '\u066C';",
    };

    for (final MapEntry<String, String>(key: what, value: line)
        in offenders.entries) {
      test('$what under lib/features turns the build red', () async {
        write(
          'lib/features/plan/presentation/planted.dart',
          '/// Scratch.\n$line\n',
        );

        final result = await runGate();
        final output = '${result.stdout}${result.stderr}';

        expect(result.exitCode, 1, reason: what);
        expect(output, contains('planted.dart'));
        expect(output, contains('digit table'));
      });
    }

    test('the rule has NO exemption, not even for lib/l10n', () async {
      // The counter-case is a SPELLING, not a directory. `lib/l10n` owns the
      // character set and still may not type it out: the exemption that used
      // to sit here protected nothing, because comments are stripped before
      // matching and the file passed on its own anyway.
      write(
        'lib/l10n/planted.dart',
        "/// Scratch.\nconst sep = '\u066B';\n",
      );

      final result = await runGate();

      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
    });

    test(
      'the same character named by code point is how it is written',
      () async {
        write(
          'lib/l10n/numeric_input.dart',
          '/// Scratch.\n'
              'const int sep = 0x066B;\n'
              'const List<int> d = <int>[0x06F0];\n',
        );

        final result = await runGate();

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      },
    );
  });

  group('a painter takes a snapshot, not a context', () {
    for (final needle in <String>[
      'BuildContext',
      'Theme.of',
      'MediaQuery',
      'Localizations',
    ]) {
      test('$needle in a painter turns the build red', () async {
        write(
          'lib/features/progress/presentation/widgets/planted_painter.dart',
          '/// Scratch.\nfinal x = $needle;\n',
        );

        final result = await runGate();

        expect(result.exitCode, 1, reason: needle);
        expect(
          '${result.stdout}${result.stderr}',
          contains('planted_painter'),
        );
      });
    }

    test('the painter’s own dartdoc may say the words', () async {
      // The rule is comment-stripped. A gate that fires on the documentation
      // explaining it is a gate somebody deletes.
      write(
        'lib/features/progress/presentation/widgets/documented_painter.dart',
        '/// Takes a snapshot: no BuildContext, no Theme.of, no MediaQuery.\n'
            'final x = 1;\n',
      );

      final result = await runGate();

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('an ordinary widget may still take a BuildContext', () async {
      write(
        'lib/features/progress/presentation/widgets/ordinary.dart',
        '/// Scratch.\nfinal x = BuildContext;\n',
      );

      final result = await runGate();

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });
  });

  group('accessibility is correctness, not polish', () {
    /// Every new needle, with a line that trips it.
    const offenders = <String, String>{
      'withClampedTextScaling':
          'final w = MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3);',
      'FittedBox': 'final w = FittedBox(child: Text("10mg"));',
      'ellipsis': 'final s = TextStyle(overflow: TextOverflow.ellipsis);',
      'setPreferredOrientations':
          'final f = SystemChrome.setPreferredOrientations(<int>[]);',
    };

    for (final MapEntry<String, String>(key: needle, value: line)
        in offenders.entries) {
      test('$needle in lib turns the build red', () async {
        write(
          'lib/features/today/presentation/offender.dart',
          '/// Scratch.\n$line\n',
        );

        final result = await runGate();

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(result.stdout, contains('offender.dart'));
      });
    }

    test('takeException in a tearDown turns the build red', () async {
      // A swallowed overflow is the one failure mode this whole epic exists to
      // catch, and a `tearDown` that eats it makes every later cell green.
      write(
        'test/features/swallowing_test.dart',
        '/// Scratch.\n'
            'void main() {\n'
            '  tearDown(() {\n'
            '    tester.takeException();\n'
            '  });\n'
            '}\n',
      );

      final result = await runGate();

      expect(result.exitCode, 1, reason: '${result.stdout}');
    });

    test(
      'takeException inside a TEST is how an assertion is written',
      () async {
        // `expect(tester.takeException(), isNull)` is the assertion the matrix
        // is built on. A blunt rule would ban the thing it exists to require.
        write(
          'test/features/asserting_test.dart',
          '/// Scratch.\n'
              'void main() {\n'
              '  testWidgets("x", (tester) async {\n'
              '    expect(tester.takeException(), isNull);\n'
              '  });\n'
              '}\n',
        );

        final result = await runGate();

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      },
    );

    test(
      'textScaleFactor is legal ONLY where the override is declared',
      () async {
        // `TextScaler.textScaleFactor` is an abstract deprecated getter, so
        // EPIC-11's `UserTextScaler` must implement it and cannot be
        // restructured out of it. The rule bans the READS, by path.
        write(
          'lib/theme/composed_text_scaler.dart',
          '/// Scratch.\n'
              '// Required and deprecated: TextScaler declares it abstract.\n'
              'double get textScaleFactor => 1;\n',
        );

        final legal = await runGate();
        expect(legal.exitCode, 0, reason: '${legal.stdout}${legal.stderr}');

        write(
          'lib/features/today/presentation/elsewhere.dart',
          '/// Scratch.\ndouble get textScaleFactor => 1;\n',
        );

        final illegal = await runGate();
        expect(illegal.exitCode, 1, reason: '${illegal.stdout}');
        expect(illegal.stdout, contains('elsewhere.dart'));
        expect(
          illegal.stdout,
          isNot(contains('composed_text_scaler.dart')),
          reason: 'the declaration site was reported as a hit',
        );
      },
    );

    test('MediaQuery.of(context).copyWith is legal; .size is not', () async {
      // Same file, so this distinguishes the misuse from the one call EPIC-11
      // task 8 cannot be written without.
      write(
        'lib/app/legal.dart',
        '/// Scratch.\n'
            'final data = MediaQuery.of(context).copyWith(boldText: true);\n',
      );

      final legal = await runGate();
      expect(legal.exitCode, 0, reason: '${legal.stdout}${legal.stderr}');

      write(
        'lib/app/legal.dart',
        '/// Scratch.\n'
            'final data = MediaQuery.of(context).copyWith(boldText: true);\n'
            'final s = MediaQuery.of(context).size;\n',
      );

      final illegal = await runGate();
      expect(illegal.exitCode, 1, reason: '${illegal.stdout}');
    });

    test('no allowlist file exists anywhere in the tree', () {
      // Asserted directly, so the narrow rules above cannot quietly become a
      // side-car list of files that opt out of a rule that still applies.
      final offenders = Directory('${Directory.current.path}/tool')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.contains('allowlist') ||
                f.path.contains('allow_list') ||
                f.path.contains('ignore_list') ||
                f.path.contains('exempt'),
          )
          .map((f) => f.path)
          .toList();

      expect(offenders, isEmpty);
    });

    test('three violations print three hits and exit 1 ONCE', () async {
      // Accumulate, not fail-fast. A gate that stops at the first hit makes
      // fixing a tree an N-round game.
      write(
        'lib/features/today/presentation/three.dart',
        '/// Scratch.\n'
            'final a = FittedBox(child: Text("x"));\n'
            'final b = TextOverflow.ellipsis;\n'
            'final c = MediaQuery.withClampedTextScaling(maxScaleFactor: 2);\n',
      );

      final result = await runGate();

      expect(result.exitCode, 1, reason: '${result.stdout}');
      final hits = '${result.stdout}'
          .split('\n')
          .where((line) => line.contains('three.dart'))
          .length;
      expect(hits, 3, reason: '${result.stdout}');
    });
  });

  group('one version, in one file', () {
    // `pubspec.yaml` is the only source. A literal in a platform file is a
    // version that disagrees with the one the store was told, and it
    // disagrees silently — the build succeeds and the number is wrong.
    const offenders = <String, (String, String)>{
      'a literal Android versionName': (
        'android/app/build.gradle.kts',
        'versionName = "1.0.0"',
      ),
      'a literal Android versionCode': (
        'android/app/build.gradle.kts',
        'versionCode = 1',
      ),
      'a literal CFBundleShortVersionString': (
        'ios/Runner/Info.plist',
        '<key>CFBundleShortVersionString</key><string>1.0.0</string>',
      ),
      'a literal CFBundleVersion': (
        'ios/Runner/Info.plist',
        '<key>CFBundleVersion</key><string>1</string>',
      ),
    };

    for (final MapEntry<String, (String, String)>(key: what, value: pair)
        in offenders.entries) {
      test('$what turns the build red', () async {
        write(pair.$1, pair.$2);

        final result = await runGate();

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(result.stdout, contains(pair.$1));
      });
    }

    test('the Flutter-resolved forms stay green', () async {
      // These are what the templates actually ship, and the rule must not
      // ban the thing it exists to require.
      write(
        'android/app/build.gradle.kts',
        'versionCode = flutter.versionCode\n'
            'versionName = flutter.versionName\n',
      );
      write(
        'ios/Runner/Info.plist',
        '<key>CFBundleShortVersionString</key>\n'
            '<string>\$(FLUTTER_BUILD_NAME)</string>\n'
            '<key>CFBundleVersion</key>\n'
            '<string>\$(FLUTTER_BUILD_NUMBER)</string>\n',
      );

      final result = await runGate();

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });
  });

  group('zero network calls, the whole rule group', () {
    // The product's central claim, and the store listing depends on it. The
    // import ban and the socket ban already exist from EPIC-01; this asserts
    // every needle in the group can actually fail, because a rule that has
    // never matched anything is indistinguishable from one with a typo.
    const offenders = <String, String>{
      'package:http': "import 'package:http/http.dart' as http;",
      'package:dio': "import 'package:dio/dio.dart';",
      'google_fonts': "import 'package:google_fonts/google_fonts.dart';",
      'HttpClient': 'final c = HttpClient();',
      'WebSocket': 'final s = WebSocket.connect("wss://x");',
      'Socket': 'final s = Socket.connect("host", 80);',
    };

    for (final MapEntry<String, String>(key: needle, value: line)
        in offenders.entries) {
      test('$needle in lib turns the build red', () async {
        write(
          'lib/features/today/presentation/networked.dart',
          '/// Scratch.\n$line\n',
        );

        final result = await runGate();

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(result.stdout, contains('networked.dart'));
      });
    }

    test('dart:io itself stays legal — EPIC-13 writes a backup file', () async {
      // The ban is on the SOCKET half. A blunt `dart:io` rule would ban the
      // file writing the whole export feature is built on.
      write(
        'lib/features/backup/data/writes_a_file.dart',
        "/// Scratch.\nimport 'dart:io';\nfinal f = File('/tmp/x');\n",
      );

      final result = await runGate();

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });
  });

  test('a clean tree passes with nothing to say', () async {
    write('lib/features/schedule/presentation/fine.dart', '/// Scratch.\n');

    final result = await runGate();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });
}
