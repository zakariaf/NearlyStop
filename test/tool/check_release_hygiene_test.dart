// The credential gate, driven in both directions over a fixture tree.
//
// A working-tree check is not enough on its own and the script says so: a
// credential committed and later deleted is invisible to it and permanently
// present in the clone anybody fetches. So the script checks history too, and
// this drives both halves.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nearlystop_hygiene');
    // A real git repo, because half of what the script checks is history.
    await Process.run('git', <String>[
      'init',
      '-q',
    ], workingDirectory: root.path);
    await Process.run('git', <String>[
      'config',
      'user.email',
      'fixture@example.com',
    ], workingDirectory: root.path);
    await Process.run('git', <String>[
      'config',
      'user.name',
      'Fixture',
    ], workingDirectory: root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  void write(String relative, String contents) {
    File('${root.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  /// Commits everything, force-adding [force] so an ignored path can still be
  /// made tracked — which is exactly how a credential gets committed in real
  /// life: before the rule existed, or past it with `-f`.
  Future<void> commit(String message, {String? force}) async {
    await Process.run('git', <String>[
      'add',
      '-A',
    ], workingDirectory: root.path);
    if (force != null) {
      await Process.run('git', <String>[
        'add',
        '-f',
        force,
      ], workingDirectory: root.path);
    }
    await Process.run('git', <String>[
      'commit',
      '-q',
      '-m',
      message,
    ], workingDirectory: root.path);
  }

  Future<ProcessResult> runGate() => Process.run('bash', <String>[
    '${Directory.current.path}/tool/check_release_hygiene.sh',
    root.path,
  ]);

  /// The `.gitignore` rules the gate insists on, spelled out here so the
  /// fixture and the script cannot drift apart silently.
  const ignores =
      'key.properties\n*.jks\n*.keystore\n*.p12\n*.p8\n'
      'service-account*.json\n';

  test('a clean tree passes', () async {
    write('.gitignore', ignores);
    write('README.md', 'nothing to see');
    await commit('clean');

    final result = await runGate();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  for (final path in <String>[
    'android/key.properties',
    'android/app/upload.jks',
    'ci/AuthKey_ABC123.p8',
    'ci/service-account.json',
    'certs/dist.p12',
  ]) {
    test('a tracked $path turns it red', () async {
      write('.gitignore', ignores);
      write(path, 'secret');
      await commit('oops', force: path);

      final result = await runGate();

      expect(result.exitCode, 1, reason: '${result.stdout}');
      expect(result.stdout, contains(path));
    });
  }

  test(
    'a credential DELETED from the tree is still found in history',
    () async {
      // The case a working-tree check misses entirely, and the one that
      // matters: the file is gone from `main` and permanently present in every
      // clone anybody has ever fetched.
      write('.gitignore', 'nothing\n');
      write('android/key.properties', 'storePassword=hunter2');
      await commit('add the key', force: 'android/key.properties');
      File('${root.path}/android/key.properties').deleteSync();
      await commit('remove the key');

      final result = await runGate();

      expect(result.exitCode, 1, reason: '${result.stdout}');
      expect(result.stdout, contains('history'));
      expect(result.stdout, contains('key.properties'));
    },
  );

  test('the ignore rules themselves are asserted, not assumed', () async {
    // A clean tree with no `.gitignore` entry is one `git add -A` away from a
    // committed keystore. The gate wants the rule present, not just the file
    // absent.
    write('README.md', 'no gitignore at all');
    await commit('bare');

    final result = await runGate();

    expect(result.exitCode, 1, reason: '${result.stdout}');
    expect(result.stdout, contains('.gitignore'));
  });
}
