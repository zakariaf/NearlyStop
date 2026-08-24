// Two properties of the CI configuration that nothing else can see.
//
// Both are one line away from being wrong, and both are silent when they are:
// a release workflow reachable from a push spends version codes nobody asked
// for, and an `--update-goldens` in a workflow turns every golden into a
// rubber stamp that records whatever the code did.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  List<File> workflows() => Directory('.github/workflows')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
      .toList();

  test('there are workflows to check', () {
    // The guard that stops both assertions below passing over an empty list.
    expect(workflows(), isNotEmpty);
  });

  test('the release workflow is manual dispatch ONLY', () {
    // A release build burns a version code the moment it is uploaded
    // anywhere — even to an internal track, even if processing fails. Nothing
    // that produces one may be reachable from a push.
    final release = File('.github/workflows/release.yml');
    expect(release.existsSync(), isTrue);

    final triggers =
        (loadYaml(release.readAsStringSync()) as YamlMap)[true] ??
        (loadYaml(release.readAsStringSync()) as YamlMap)['on'];
    final keys = (triggers! as YamlMap).keys.map((k) => '$k').toSet();

    expect(keys, <String>{'workflow_dispatch'});
  });

  test('no workflow ever passes --update-goldens', () {
    // A golden asserts nothing; it records what the code did. Blessing them
    // in CI means every future change blesses itself, and the suite stops
    // being able to fail.
    for (final file in workflows()) {
      expect(
        file.readAsStringSync(),
        isNot(contains('--update-goldens')),
        reason: '${file.path} blesses goldens automatically',
      );
    }
  });

  test('the runner image is pinned, never -latest', () {
    // `ubuntu-latest` moves the toolchain underneath the build with no diff to
    // review, which is the same class of problem as an unpinned dependency.
    //
    // Checked on the PARSED `runs-on` value, not on the file's text: both
    // workflows carry a comment saying "pinned, never -latest", and a text
    // match flags the comment that documents the rule while missing a job
    // that breaks it.
    for (final file in workflows()) {
      final jobs = (loadYaml(file.readAsStringSync()) as YamlMap)['jobs'];
      for (final job in (jobs as YamlMap).entries) {
        final image = '${(job.value as YamlMap)['runs-on']}';
        expect(
          image,
          isNot(endsWith('-latest')),
          reason: '${file.path}: job "${job.key}" runs on $image',
        );
      }
    }
  });
}
