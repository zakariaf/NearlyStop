// Pure `package:test` on purpose: this file importing neither `flutter_test`
// nor `package:flutter/` IS the purity claim tool/check_core_purity.sh gates.
import 'dart:io';

import 'package:nearlystop/core/result.dart';
import 'package:test/test.dart';

/// A minimal [Failure] used only by these tests.
final class StubFailure extends Failure {
  const StubFailure(this.message);

  /// Human-readable detail; test-only, never a shipped user-facing string.
  final String message;

  @override
  String get code => 'stub.failure';

  @override
  bool operator ==(Object other) =>
      other is StubFailure && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

void main() {
  group('Result', () {
    test('the Ok arm of an exhaustive switch yields the value', () {
      const Result<int, StubFailure> result = Ok<int, StubFailure>(7);

      final matched = switch (result) {
        Ok(:final value) => value,
        Err() => -1,
      };

      expect(matched, 7);
    });

    test('the Err arm carries the failure', () {
      const Result<int, StubFailure> result = Err<int, StubFailure>(
        StubFailure('boom'),
      );

      final matched = switch (result) {
        Ok(:final value) => 'ok:$value',
        Err(:final failure) => failure.message,
      };

      expect(matched, 'boom');
    });

    test('the void arm constructs and matches Ok', () {
      const Result<void, StubFailure> result = Ok<void, StubFailure>(null);

      var reachedOk = false;
      switch (result) {
        case Ok():
          reachedOk = true;
        case Err():
          reachedOk = false;
      }

      expect(reachedOk, isTrue);
    });

    test('there is no Unit type anywhere under lib/', () {
      // The void arm is spelled `Result<void, F>`. EPIC-12 and EPIC-13 drafts
      // say `Result<Unit, F>`; this stops that landing by accident. Comments
      // are stripped first so this rule's own explanation is not an offender.
      final blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
      final lineComment = RegExp('//[^\n]*');
      final unit = RegExp(r'\bUnit\b');

      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final code = entity
            .readAsStringSync()
            .replaceAll(blockComment, '')
            .replaceAll(lineComment, '');
        if (unit.hasMatch(code)) offenders.add(entity.path);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Result<void, F> is the void arm; there is no Unit type.\n'
            '${offenders.join('\n')}',
      );
    });

    test('equality is by value', () {
      expect(
        const Err<int, StubFailure>(StubFailure('boom')),
        const Err<int, StubFailure>(StubFailure('boom')),
      );
      expect(
        const Ok<int, StubFailure>(7),
        isNot(const Ok<int, StubFailure>(8)),
      );
      expect(
        const Ok<int, StubFailure>(7).hashCode,
        const Ok<int, StubFailure>(7).hashCode,
      );
    });
  });
}
