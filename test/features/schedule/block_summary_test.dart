// The block header's teaching sentence.
//
// This is the feature. "Block 3 of 11 — one day at 9mg, then 4 days at 10mg"
// answers the forum's most-asked question before it is asked, and it has to be
// read OFF THE BLOCK TABLE. Hardcoding is what these tests kill: blocks 7–11
// invert, so a summary that always names the new dose first is wrong for five
// of the eleven.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

void main() {
  const newDose = Milligrams.fromHundredths(900);
  const oldDose = Milligrams.fromHundredths(1000);
  const pattern = DsnsPattern.v1();

  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    de = await AppLocalizations.delegate.load(const Locale('de'));
  });

  String summary(int block, AppLocalizations l10n, Locale locale) =>
      ScheduleNotifier.blockSummary(
        number: block,
        newDose: newDose,
        oldDose: oldDose,
        l10n: l10n,
        locale: locale,
      );

  test('block 1: one day at the NEW dose, then six at the old', () {
    expect(
      summary(1, en, const Locale('en')),
      en.blockSummary(1, '9mg', 6, '10mg'),
    );
  });

  test('block 6: the single NEW-dose day still leads', () {
    // SPEC.md §3.1's v1 decision. A summary reading "one day at 10mg, then 1
    // day at 9mg" here is the "helpful" reordering this test exists to reject.
    expect(
      summary(6, en, const Locale('en')),
      en.blockSummary(1, '9mg', 1, '10mg'),
    );
  });

  test(
    'block 7: the halves have INVERTED — the old dose is the single day',
    () {
      expect(
        summary(7, en, const Locale('en')),
        en.blockSummary(1, '10mg', 2, '9mg'),
      );
    },
  );

  test('block 11: one day at the old dose, then six at the new', () {
    expect(
      summary(11, en, const Locale('en')),
      en.blockSummary(1, '10mg', 6, '9mg'),
    );
  });

  test('de renders the longest-string locale as TEXT, not as a layout', () {
    expect(
      summary(3, de, const Locale('de')),
      'ein Tag mit 9mg, dann 4 Tage mit 10mg',
    );
  });

  test('every block: the two counts sum to the block table’s own day count', () {
    // The independent oracle is the block table's `days` column, never the
    // summary builder. Swept over all eleven blocks and three step doses, so a
    // summary that is right for one pair and wrong for another cannot hide.
    for (final doses in <(Milligrams, Milligrams)>[
      (Milligrams.fromHundredths(900), Milligrams.fromHundredths(1000)),
      (Milligrams.fromHundredths(50), Milligrams.fromHundredths(100)),
      (Milligrams.fromHundredths(1750), Milligrams.fromHundredths(2000)),
    ]) {
      for (var block = 1; block <= pattern.blocks.length; block++) {
        final text = ScheduleNotifier.blockSummary(
          number: block,
          newDose: doses.$1,
          oldDose: doses.$2,
          l10n: en,
          locale: const Locale('en'),
        );
        final counts = RegExp(
          r'(\d+) days?',
        ).allMatches(text).map((match) => int.parse(match.group(1)!)).toList();
        // "one day at …" spells the leading 1 as a word, so a single match
        // means the lead was 1 and the rest carries the remainder.
        final total =
            counts.fold(0, (sum, value) => sum + value) +
            (counts.length == 1 ? 1 : 0);

        expect(
          total,
          pattern.blocks[block - 1].length,
          reason: 'block $block at ${doses.$1}/${doses.$2}: "$text"',
        );
      }
    }
  });

  test('the summary is never the same for blocks 1 and 11', () {
    // They are mirror images: six-then-one at the new dose versus
    // one-then-six at the old. A hardcoded string makes them identical.
    expect(
      summary(1, en, const Locale('en')),
      isNot(summary(11, en, const Locale('en'))),
    );
  });
}
