// The three smaller pieces of Today: the date header, the context line and
// the quiet action row.
//
// All three take pre-formatted strings and callbacks, so none of them needs a
// container. What they are tested for is geometry and semantics — the two
// things a screenshot cannot assert and a reader depends on.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_context_line.dart';
import 'package:nearlystop/features/today/presentation/widgets/quiet_action_row.dart';
import 'package:nearlystop/features/today/presentation/widgets/today_date_header.dart';

import '../../../support/harness.dart';

void main() {
  group('TodayDateHeader', () {
    Future<int> pumpHeader(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      TextScaler textScaler = TextScaler.noScaling,
      void Function(int)? count,
    }) async {
      var taps = 0;
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: Material(
            child: TodayDateHeader(
              dateLine: 'Wednesday 16 April',
              title: 'Today',
              noteHint: 'Note for today',
              onOpenNote: () => taps++,
            ),
          ),
        ),
        locale: locale,
        textScaler: textScaler,
        surfaceSize: const Size(390, 844),
      );
      return taps;
    }

    testWidgets('the note button fires once, and opens nothing itself', (
      tester,
    ) async {
      var taps = 0;
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: Material(
            child: TodayDateHeader(
              dateLine: 'Wednesday 16 April',
              title: 'Today',
              noteHint: 'Note for today',
              onOpenNote: () => taps++,
            ),
          ),
        ),
        surfaceSize: const Size(390, 844),
      );

      await tester.tap(find.byKey(TodayDateHeader.noteButtonKey));
      await tester.pumpAndSettle();

      expect(taps, 1);
      // The header opens nothing: routing is the screen's job.
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the note button is on the TRAILING edge, both directions', (
      tester,
    ) async {
      // Measured, and the comparison INVERTS in RTL. A `Positioned(left:)` or
      // an `EdgeInsets.only(left:)` passes the LTR half and fails here, which
      // is the whole reason both halves exist.
      await pumpHeader(tester);
      final ltrButton = tester
          .getCenter(find.byKey(TodayDateHeader.noteButtonKey))
          .dx;
      final ltrDate = tester.getCenter(find.text('Wednesday 16 April')).dx;
      expect(ltrButton, greaterThan(ltrDate));

      await pumpHeader(tester, locale: const Locale('fa'));
      final rtlButton = tester
          .getCenter(find.byKey(TodayDateHeader.noteButtonKey))
          .dx;
      final rtlDate = tester.getCenter(find.text('Wednesday 16 April')).dx;
      expect(rtlButton, lessThan(rtlDate));
    });

    testWidgets('the note button clears 44x44 at 1.0 and at 2.0', (
      tester,
    ) async {
      for (final scale in <double>[1, 2]) {
        await pumpHeader(tester, textScaler: TextScaler.linear(scale));

        final size = tester.getSize(find.byKey(TodayDateHeader.noteButtonKey));
        expect(size.width, greaterThanOrEqualTo(44), reason: 'scale $scale');
        expect(size.height, greaterThanOrEqualTo(44), reason: 'scale $scale');
      }
    });

    testWidgets('the title reads as a HEADING, the date as its own node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHeader(tester);

      expect(
        tester.getSemantics(find.text('Today')),
        isSemantics(isHeader: true, label: 'Today'),
      );
      expect(find.text('Wednesday 16 April'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DoseContextLine', () {
    Future<void> pumpLine(
      WidgetTester tester, {
      bool isSteadyState = false,
      TextScaler textScaler = TextScaler.noScaling,
      Locale locale = const Locale('en'),
    }) => pumpApp(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: Material(
          child: DoseContextLine(
            stepIndex: '3',
            stepCount: '15',
            fromDose: '10mg',
            toDose: '9mg',
            dayInStep: isSteadyState ? null : '14',
            stepLength: isSteadyState ? null : '52',
            holdingLabel: isSteadyState ? 'Holding at 9mg' : null,
            semanticsLabel:
                'Step 3 of 15, reducing from 10mg to 9mg, day 14 of 52',
          ),
        ),
      ),
      locale: locale,
      textScaler: textScaler,
      surfaceSize: const Size(390, 844),
    );

    testWidgets('three segments, and the step numbers are in them', (
      tester,
    ) async {
      await pumpLine(tester);

      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('10mg'), findsWidgets);
      expect(find.textContaining('14'), findsWidgets);
    });

    testWidgets('a steady-state day prints the holding label, never 0 or 52', (
      tester,
    ) async {
      await pumpLine(tester, isSteadyState: true);

      expect(find.text('Holding at 9mg'), findsOneWidget);
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .join(' ');
      expect(rendered, isNot(contains('52')));
      expect(rendered, isNot(contains(' 0 ')));
    });

    testWidgets('ONE semantics node, not six fragments', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLine(tester);

      final node = tester.getSemantics(find.byType(DoseContextLine));
      expect(
        node.label,
        'Step 3 of 15, reducing from 10mg to 9mg, day 14 of 52',
      );
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0, reason: 'the segments leaked into the tree');
      handle.dispose();
    });

    testWidgets('the arrow is the ADAPTIVE one, which mirrors itself', (
      tester,
    ) async {
      // The epic asks for `find.byIcon(Icons.arrow_forward)` to be empty. That
      // only holds on iOS: everywhere else `Icons.adaptive.arrow_forward`
      // RESOLVES TO `Icons.arrow_forward`, so the assertion would fail on a
      // correct implementation and pass on nothing.
      //
      // What is true on every platform is that the rendered glyph is whatever
      // the adaptive accessor resolves to here, and that the source reaches
      // for the accessor rather than the fixed icon — so both are asserted.
      await pumpLine(tester);

      expect(find.byIcon(Icons.adaptive.arrow_forward), findsOneWidget);
      expect(
        File(
          'lib/features/today/presentation/widgets/dose_context_line.dart',
        ).readAsStringSync(),
        contains('Icons.adaptive.arrow_forward'),
      );
    });

    testWidgets('at 2.0 it reflows instead of overflowing', (tester) async {
      // A `Row` here overflows, which is why it is a `Wrap`. TWO of them
      // since EPIC-14: the "10mg → 9mg" transition is three items and, at the
      // composed ceiling, wider than the line the outer Wrap gives it — so it
      // reflows inside itself rather than pushing past the card.
      await pumpLine(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
      expect(find.byType(Wrap), findsWidgets);
      expect(find.byType(Row), findsNothing, reason: 'a Row here overflows');
    });
  });

  group('QuietActionRow', () {
    Future<({int note, int hold, int flare})> pumpRow(
      WidgetTester tester, {
      bool canHold = true,
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      var note = 0;
      var hold = 0;
      var flare = 0;
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: Material(
            child: QuietActionRow(
              noteLabel: 'Add note',
              holdLabel: 'Hold',
              flareLabel: 'Flare',
              holdDisabledReason: canHold
                  ? null
                  : 'There is no step running to hold',
              onAddNote: () => note++,
              onHold: () => hold++,
              onFlare: () => flare++,
            ),
          ),
        ),
        textScaler: textScaler,
        surfaceSize: const Size(390, 844),
      );
      return (note: note, hold: hold, flare: flare);
    }

    testWidgets('three tiles of EQUAL width', (tester) async {
      await pumpRow(tester);

      final widths = tester
          .widgetList<QuietActionTile>(find.byType(QuietActionTile))
          .map((tile) => tester.getSize(find.byWidget(tile)).width)
          .toList();
      expect(widths, hasLength(3));
      expect(
        widths.every((width) => (width - widths.first).abs() < 0.5),
        isTrue,
        reason: 'the three are not equal: $widths',
      );
    });

    testWidgets('each fires its own callback, and only its own', (
      tester,
    ) async {
      for (final label in <String>['Add note', 'Hold', 'Flare']) {
        var note = 0;
        var hold = 0;
        var flare = 0;
        await pumpApp(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: QuietActionRow(
                noteLabel: 'Add note',
                holdLabel: 'Hold',
                flareLabel: 'Flare',
                holdDisabledReason: null,
                onAddNote: () => note++,
                onHold: () => hold++,
                onFlare: () => flare++,
              ),
            ),
          ),
          surfaceSize: const Size(390, 844),
        );

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(<int>[note, hold, flare].reduce((a, b) => a + b), 1);
        expect(
          switch (label) {
            'Add note' => note,
            'Hold' => hold,
            _ => flare,
          },
          1,
          reason: label,
        );
      }
    });

    testWidgets('a disabled Hold is PRESENT and says why', (tester) async {
      // Disabled-with-reason, never hidden. A test asserting the tile is
      // absent would be the wrong test: a control that vanishes teaches
      // nothing, and the reader is left wondering where Hold went.
      final handle = tester.ensureSemantics();
      final counts = await pumpRow(tester, canHold: false);

      expect(find.text('Hold'), findsOneWidget);
      await tester.tap(find.text('Hold'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(counts.hold, 0);

      final spoken = <String>[];
      void collect(SemanticsNode node) {
        if (node.label.isNotEmpty) spoken.add(node.label);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(find.byType(QuietActionRow)));
      expect(
        spoken.join(' '),
        contains('There is no step running to hold'),
        reason: 'the disabled tile did not say why',
      );
      handle.dispose();
    });

    testWidgets('every tile clears 44x44 at 1.0 and at 2.0', (tester) async {
      for (final scale in <double>[1, 2]) {
        await pumpRow(tester, textScaler: TextScaler.linear(scale));

        for (final tile in tester.widgetList<QuietActionTile>(
          find.byType(QuietActionTile),
        )) {
          final size = tester.getSize(find.byWidget(tile));
          expect(size.width, greaterThanOrEqualTo(44), reason: 'scale $scale');
          expect(size.height, greaterThanOrEqualTo(44), reason: 'scale $scale');
        }
      }
    });

    testWidgets('a Row at 1.5x and a Column at 1.6x — both sides', (
      tester,
    ) async {
      // A ladder tested only at 1.0 and 2.0 passes with the threshold off by
      // 0.3, so both sides of it are asserted.
      await pumpRow(tester, textScaler: const TextScaler.linear(1.5));
      final sideBySide = tester
          .widgetList<QuietActionTile>(find.byType(QuietActionTile))
          .map((tile) => tester.getTopLeft(find.byWidget(tile)).dy)
          .toSet();
      expect(sideBySide, hasLength(1), reason: 'not one row at 1.5');

      await pumpRow(tester, textScaler: const TextScaler.linear(1.6));

      final stacked = tester
          .widgetList<QuietActionTile>(find.byType(QuietActionTile))
          .map((tile) => tester.getTopLeft(find.byWidget(tile)).dy)
          .toSet();
      expect(stacked, hasLength(3), reason: 'not stacked at 1.6');
      expect(tester.takeException(), isNull);
    });
  });
}
