// The transitive dependency ban, driven in both directions.
//
// A direct-dependency check passes on exactly the failure that matters:
// nobody adds `package:http` to `pubspec.yaml` — a plugin three hops down
// does, and the store declaration silently becomes a lie. So the audit walks
// the resolved tree, and this proves it actually catches a hit at depth.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_audit');
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  /// Runs the auditor over a hand-written `dart pub deps --json` document.
  ///
  /// Feeding the JSON directly rather than resolving a real package: the shape
  /// is the auditor's actual input, and a fixture package would take a network
  /// fetch to solve — in the suite that exists to prove nothing fetches.
  Future<ProcessResult> auditFixture(Map<String, Object?> deps) async {
    final file = File('${workspace.path}/deps.json')
      ..writeAsStringSync(jsonEncode(deps));
    return Process.run('python3', <String>[
      '${Directory.current.path}/tool/audit_deps.py',
      file.path,
    ]);
  }

  /// One node of a `pub deps --json` tree.
  ///
  /// `kind` matters and is easy to get wrong: the auditor walks from the
  /// packages the app DECLARES (`direct`), not from the root node, because
  /// what ships is what `dependencies:` drags in — `dev` packages never reach
  /// the binary. A fixture that marked everything `transitive` would leave the
  /// walk with no starting point and report clean over a banned tree, which is
  /// how the first version of this file passed.
  Map<String, Object?> node(
    String name, {
    List<String> deps = const <String>[],
    String kind = 'transitive',
  }) => <String, Object?>{
    'name': name,
    'version': '1.0.0',
    'kind': kind,
    'dependencies': deps,
  };

  test('a clean tree passes', () async {
    final result = await auditFixture(<String, Object?>{
      'root': 'nearlystop',
      'packages': <Map<String, Object?>>[
        node('nearlystop', deps: <String>['drift'], kind: 'root'),
        node('drift', deps: <String>['sqlite3'], kind: 'direct'),
        node('sqlite3'),
      ],
    });

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('a banned package THREE hops down fails', () async {
    // The whole point. `nearlystop → innocent → also_fine → sentry_flutter` is
    // invisible to any check that reads `pubspec.yaml`.
    //
    // **`sentry_flutter`, not `http`.** `http` is on the auditor's ALLOW list
    // with a written justification — `timezone` declares it, and the only file
    // that imports it is `timezone/lib/browser.dart`, which this app (no web
    // target) never reaches. Using it here would have tested the allow list
    // rather than the ban, which is how the first version of this test came to
    // report green over a banned tree.
    final result = await auditFixture(<String, Object?>{
      'root': 'nearlystop',
      'packages': <Map<String, Object?>>[
        node('nearlystop', deps: <String>['innocent'], kind: 'root'),
        node('innocent', deps: <String>['also_fine'], kind: 'direct'),
        node('also_fine', deps: <String>['sentry_flutter']),
        node('sentry_flutter'),
      ],
    });

    expect(result.exitCode, 1, reason: '${result.stdout}');
    expect(result.stdout, contains('sentry_flutter'));
  });

  test('a banned package as a DIRECT dependency fails too', () async {
    final result = await auditFixture(<String, Object?>{
      'root': 'nearlystop',
      'packages': <Map<String, Object?>>[
        node('nearlystop', deps: <String>['dio'], kind: 'root'),
        node('dio', kind: 'direct'),
      ],
    });

    expect(result.exitCode, 1, reason: '${result.stdout}');
    expect(result.stdout, contains('dio'));
  });

  test(
    'the real tree is clean, and that is the claim the store reads',
    () async {
      // Against the actual resolved tree, not a fixture. This is the line
      // `docs/release/privacy-declarations.md` cites.
      final result = await Process.run('bash', <String>[
        '${Directory.current.path}/tool/audit-deps.sh',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    },
  );
}
