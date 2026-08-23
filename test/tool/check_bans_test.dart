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

  test('a clean tree passes with nothing to say', () async {
    write('lib/features/schedule/presentation/fine.dart', '/// Scratch.\n');

    final result = await runGate();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });
}
