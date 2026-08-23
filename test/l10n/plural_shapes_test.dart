// The ICU shapes gen-l10n actually GENERATES, not the ones the ARB declares.
//
// `arb_messages_test` reads the raw JSON and `check_arb_parity.sh` compares the
// four files against each other. Neither notices if gen-l10n produces something
// different from what the ARB says — a plural whose `other` branch never fires,
// or a `=1` that swallows every count in a language with no singular.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

void main() {
  test('the plural branch actually selected changes with the count', () {
    // English distinguishes; the rendered strings must differ beyond the digit.
    final en = lookupAppLocalizations(const Locale('en'));

    expect(en.takenDays(1), isNot(en.takenDays(2).replaceAll('2', '1')));
    expect(en.flaresRecorded(1), isNot(contains('flares')));
    expect(en.flaresRecorded(2), contains('flares'));
  });

  test('German distinguishes too, and does not borrow English', () {
    final de = lookupAppLocalizations(const Locale('de'));

    expect(de.takenDays(1), isNot(equals(de.takenDays(2))));
    expect(de.takenDays(1), isNot(contains('day')));
    expect(de.flaresRecorded(2), isNot(contains('flare recorded')));
  });

  test('every locale renders every count from 0 to 3 and 11 to 21', () {
    // The boundaries where CLDR rules differ between languages. A branch that
    // does not exist throws at RENDER time, which no static check catches.
    for (final locale in kSupportedLocales) {
      final l10n = lookupAppLocalizations(locale);

      for (final count in <int>[0, 1, 2, 3, 11, 12, 21, 101, 341]) {
        for (final rendered in <String>[
          l10n.takenDays(count),
          l10n.flaresRecorded(count),
          l10n.daysOnMedicine(count, 'prednisolone'),
          l10n.blockPattern('9mg', count, '10mg'),
        ]) {
          expect(
            rendered,
            isNotEmpty,
            reason: '${locale.toLanguageTag()} count=$count',
          );
          expect(
            rendered,
            isNot(contains('{')),
            reason: '${locale.toLanguageTag()} count=$count',
          );
        }
      }
    }
  });

  test(
    'a Perso-Arabic plural never accidentally renders an English branch',
    () {
      for (final locale in <Locale>[const Locale('fa'), kurdishSorani]) {
        final l10n = lookupAppLocalizations(locale);

        for (final count in <int>[1, 2, 341]) {
          expect(l10n.takenDays(count), isNot(matches(RegExp('[A-Za-z]{3,}'))));
          expect(
            l10n.flaresRecorded(count),
            isNot(matches(RegExp('[A-Za-z]{3,}'))),
            reason: '${locale.toLanguageTag()} count=$count',
          );
        }
      }
    },
  );
}
