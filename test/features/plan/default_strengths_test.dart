// What a clean install starts with. `SPEC.md` §11.2.
//
// Pure `package:test`: a table lookup with no Flutter in it. Every region gets
// its own case, because the DRUG NAME differs between them and not just the
// list — an American reading "Prednisolone" on a bottle labelled "Prednisone"
// has been told the app is for somebody else.
import 'package:nearlystop/features/plan/domain/default_strengths.dart';
import 'package:test/test.dart';

void main() {
  test('each region gets its own drug name and its own strengths', () {
    expect(defaultsFor('en', 'GB').drugName, 'Prednisolone');
    expect(
      defaultsFor('en', 'GB').strengths.map((s) => s.hundredths),
      <int>[100, 250, 500],
    );

    // The United States prescribes PREDNISONE, and the name on the bottle is
    // the name the app has to use.
    expect(defaultsFor('en', 'US').drugName, 'Prednisone');
    expect(
      defaultsFor('en', 'US').strengths.map((s) => s.hundredths),
      <int>[100, 250, 500, 1000, 2000],
    );

    expect(defaultsFor('de', null).drugName, 'Prednisolon');
    expect(
      defaultsFor('de', null).strengths.map((s) => s.hundredths),
      <int>[100, 200, 500, 1000, 2000, 5000],
    );

    for (final language in <String>['fa', 'ckb']) {
      expect(
        defaultsFor(language, null).drugName,
        'Prednisolone',
        reason: language,
      );
      expect(
        defaultsFor(language, null).strengths.map((s) => s.hundredths),
        <int>[100, 500],
        reason: language,
      );
    }
  });

  test('every entry is non-empty, sorted and free of duplicates', () {
    // A clean install that lands on an EMPTY strength list cannot compose a
    // dose, so the first thing the app shows is "cannot be made from the
    // tablets you hold" — on a screen the person has not filled in yet.
    for (final entry in kDefaultStrengths.entries) {
      final values = entry.value.strengths.map((s) => s.hundredths).toList();
      expect(values, isNotEmpty, reason: entry.key);
      expect(
        values,
        orderedEquals(<int>[...values]..sort()),
        reason: entry.key,
      );
      expect(values.toSet(), hasLength(values.length), reason: entry.key);
      expect(entry.value.drugName.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('an unknown region falls back rather than starting empty', () {
    // A locale the table has never heard of is a person with a real
    // prescription. They get the widest-shipping list, editable.
    final fallback = defaultsFor('sv', 'SE');

    expect(fallback.strengths, isNotEmpty);
    expect(fallback.drugName, 'Prednisolone');
  });
}
