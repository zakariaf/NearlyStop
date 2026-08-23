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

  test('a clean tree passes with nothing to say', () async {
    write('lib/features/schedule/presentation/fine.dart', '/// Scratch.\n');

    final result = await runGate();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });
}
