// The gate that keeps design values in lib/theme/.
//
// A pattern that matches nothing is a gate that passes forever, so every rule
// is driven over a fixture tree and asserted in BOTH directions.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('nearlystop_raw');
    Directory('${root.path}/lib/features').createSync(recursive: true);
    Directory('${root.path}/lib/theme').createSync(recursive: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  void write(String relative, String source) {
    final file = File('${root.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);
    expect(file.existsSync(), isTrue);
  }

  Future<ProcessResult> runGate() => Process.run('bash', <String>[
    '${Directory.current.path}/tool/check_raw_values.sh',
    root.path,
  ]);

  /// Every banned pattern, with a snippet that trips it.
  const banned = <String, String>{
    'a raw hex colour': "const value = Color(0xFFAABBCC);",
    'a Material colour': 'const value = Colors.red;',
    'a literal duration': 'const value = Duration(seconds: 1);',
    'a font size': 'const value = TextStyle(fontSize: 17);',
    'a literal radius': 'final value = BorderRadius.circular(8);',
    'a hand-built shadow': 'const value = BoxShadow(blurRadius: 4);',
    'a hand-built gradient': 'const value = LinearGradient(colors: <int>[]);',
    'a Material curve': 'const value = Curves.easeOutCubic;',
    'a non-directional inset': 'const value = EdgeInsets.all(8);',
  };

  group('every banned pattern is caught', () {
    banned.forEach((name, snippet) {
      test(name, () async {
        write('lib/features/planted.dart', '/// Scratch.\n$snippet\n');

        final result = await runGate();

        expect(result.exitCode, 1, reason: name);
        expect(
          '${result.stdout}${result.stderr}',
          contains('planted.dart'),
          reason: '$name must name the file',
        );
      });
    });
  });

  test('the DIRECTIONAL inset is the sanctioned one and passes', () async {
    // A regex that ate this would make every component uneditable — and
    // directional geometry is the whole RTL discipline.
    write(
      'lib/features/ok.dart',
      '/// Scratch.\n'
          'const value = EdgeInsetsDirectional.only(start: 8);\n',
    );

    expect((await runGate()).exitCode, 0);
  });

  test('the two zero allowances pass', () async {
    // `EdgeInsets.zero` and `Duration.zero` carry no design value to move into
    // a token, and banning them would only produce a token named "nothing".
    write(
      'lib/features/zeros.dart',
      '/// Scratch.\n'
          'const inset = EdgeInsets.zero;\n'
          'const gap = Duration.zero;\n',
    );

    expect((await runGate()).exitCode, 0);
  });

  test('lib/theme/ is where these values LIVE, so it is exempt', () async {
    write(
      'lib/theme/tokens.dart',
      '/// Scratch.\n'
          'const a = Color(0xFFAABBCC);\n'
          'const b = Duration(seconds: 1);\n'
          'const c = BoxShadow(blurRadius: 4);\n',
    );

    expect((await runGate()).exitCode, 0);
  });

  test('generated files are exempt', () async {
    write('lib/features/thing.g.dart', 'const a = Color(0xFFAABBCC);\n');

    expect((await runGate()).exitCode, 0);
  });

  test('it accumulates and fails ONCE, naming both files', () async {
    // Fail-fast would print the first and hide the second, so a developer
    // fixes one, re-runs, and finds another — twice the cycles for no reason.
    write('lib/features/one.dart', 'const a = Color(0xFFAABBCC);\n');
    write('lib/features/two.dart', 'const b = Curves.easeOutCubic;\n');

    final result = await runGate();
    final output = '${result.stdout}${result.stderr}';

    expect(result.exitCode, 1);
    expect(output, contains('one.dart'));
    expect(output, contains('two.dart'));
  });

  test('an ignore comment is NOT an escape hatch', () async {
    // A genuinely new aesthetic need is a new slot in lib/theme/, not a
    // suppression on the line that needed it.
    write(
      'lib/features/sneaky.dart',
      '// ignore: whatever\nconst a = Color(0xFFAABBCC);\n',
    );

    expect((await runGate()).exitCode, 1);
  });

  test('a clean tree passes with nothing to say', () async {
    // The gate has to be provably capable of passing, or a green run means
    // only that it never ran.
    write(
      'lib/features/clean.dart',
      "/// Scratch.\n"
          "import 'package:flutter/material.dart';\n\n"
          '/// Scratch.\n'
          'Widget build(BuildContext context) => const SizedBox.shrink();\n',
    );

    final result = await runGate();

    expect(result.exitCode, 0);
    // It says so out loud rather than saying nothing: a silent gate and a
    // skipped gate look identical in a CI log.
    expect(result.stdout, contains('OK'));
    expect(result.stdout, isNot(contains('FAIL')));
  });
}
