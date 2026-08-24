// Every direct dependency is actually used.
//
// `dependency-hygiene`: an unused package in `pubspec.yaml` is a package
// nobody audits, and this app's premise is that it opens no sockets. EPIC-10
// enforced this as "EPIC-13's packages have not arrived early", which was the
// right guard while EPIC-13 had not happened. Now that it has, the guard that
// still means something is the general one — and it keeps meaning something
// for every epic after this.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  /// Packages a Flutter app depends on without importing them by name.
  ///
  /// Each is here with a reason, because "it must be used somehow" is how an
  /// unaudited package stays in the file for a year.
  const indirectlyUsed = <String, String>{
    'flutter': 'the SDK',
    'flutter_localizations': 'gen-l10n resolves the Material delegates',
    'sqlite3_flutter_libs': 'ships the native SQLite drift opens',
    'file_selector': 'wired in the real file-picker adapter',
    'share_plus': 'wired in the real share adapter',
  };

  /// Every `dependencies:` entry, in declaration order.
  List<String> directDependencies() {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final start = lines.indexOf('dependencies:');
    expect(start, greaterThanOrEqualTo(0), reason: 'no dependencies: block');
    final names = <String>[];
    for (final line in lines.skip(start + 1)) {
      if (line.isNotEmpty && !line.startsWith(' ')) break;
      final match = RegExp('^  ([a-z0-9_]+):').firstMatch(line);
      if (match != null) names.add(match.group(1)!);
    }
    return names;
  }

  /// Every `package:` URI imported anywhere under `lib/`.
  Set<String> importedPackages() {
    final imported = <String>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      for (final match in RegExp(
        '(?:import|export)\\s+[\'"]package:([a-z0-9_]+)/',
      ).allMatches(file.readAsStringSync())) {
        imported.add(match.group(1)!);
      }
    }
    return imported;
  }

  test('every direct dependency is imported, or listed with a reason', () {
    final imported = importedPackages();
    final unexplained = <String>[
      for (final name in directDependencies())
        if (!imported.contains(name) && !indirectlyUsed.containsKey(name)) name,
    ];

    expect(
      unexplained,
      isEmpty,
      reason: 'unused, and therefore unaudited: $unexplained',
    );
  });

  test('the indirect list has no stale entries', () {
    // The other direction. An entry left here after its package became a
    // normal import is a permanent exemption nobody re-reads — which is how
    // the list stops being a list of reasons and becomes a list of names.
    final declared = directDependencies().toSet();
    final stale = <String>[
      for (final name in indirectlyUsed.keys)
        if (!declared.contains(name)) name,
    ];

    expect(stale, isEmpty, reason: 'no longer a dependency: $stale');
  });

  test('no network client is a direct dependency', () {
    // The audit script owns the transitive tree; this owns the file somebody
    // edits. `http` reaches the tree through `timezone` and is allowed there
    // with evidence — as a DIRECT dependency it would be a decision, not an
    // inheritance.
    for (final banned in <String>[
      'http',
      'dio',
      'grpc',
      'web_socket_channel',
    ]) {
      expect(
        directDependencies(),
        isNot(contains(banned)),
        reason: '$banned as a direct dependency',
      );
    }
  });
}
