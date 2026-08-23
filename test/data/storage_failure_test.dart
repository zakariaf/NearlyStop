// The typed failure arms.
//
// Value equality is what lets a test say `expect(result, Err(NotFound('x')))`
// instead of matching on a type and hoping. `Failure`'s `==` is driven by each
// subtype's `props`, so a field added without being added to `props` makes two
// different failures compare equal — which is exactly how a test stops
// noticing that the wrong thing failed.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/storage_failure.dart';

void main() {
  const arms = <StorageFailure>[
    NotFound('markTaken'),
    ConstraintViolation('UNIQUE constraint failed'),
    Corrupt('unknown step status'),
    Io('disk full'),
    Invariant('v1 holds one plan'),
  ];

  test('each arm equals a same-valued twin and nothing else', () {
    const twins = <StorageFailure>[
      NotFound('markTaken'),
      ConstraintViolation('UNIQUE constraint failed'),
      Corrupt('unknown step status'),
      Io('disk full'),
      Invariant('v1 holds one plan'),
    ];

    for (var i = 0; i < arms.length; i++) {
      expect(arms[i], twins[i]);
      expect(arms[i].hashCode, twins[i].hashCode);
      for (var j = 0; j < arms.length; j++) {
        if (i == j) continue;
        expect(arms[i], isNot(twins[j]), reason: '${arms[i]} vs ${twins[j]}');
      }
    }
  });

  test('a differing payload is a differing failure', () {
    expect(const NotFound('markTaken'), isNot(const NotFound('setNote')));
    expect(const Corrupt('a'), isNot(const Corrupt('b')));
    expect(const Invariant('a'), isNot(const Invariant('b')));
    expect(const Io('a'), isNot(const Io('b')));
    expect(
      const ConstraintViolation('a'),
      isNot(const ConstraintViolation('b')),
    );
  });

  test('every arm carries its payload into toString', () {
    // The detail is what a bug report is made of; a failure that stringifies
    // to its type name alone tells nobody anything.
    expect(arms[0].toString(), contains('markTaken'));
    expect(arms[1].toString(), contains('UNIQUE'));
    expect(arms[2].toString(), contains('unknown step status'));
    expect(arms[3].toString(), contains('disk full'));
    expect(arms[4].toString(), contains('v1 holds one plan'));
  });

  test(
    'every arm is a Failure, so Result<void, StorageFailure> accepts it',
    () {
      for (final arm in arms) {
        expect(arm, isA<Failure>());
        expect(Err<void, StorageFailure>(arm).failure, arm);
      }
    },
  );
}
