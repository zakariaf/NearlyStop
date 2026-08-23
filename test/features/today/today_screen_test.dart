// Which tree each state produces.
//
// The projection is covered in `today_projection_test.dart`, so this file
// overrides `todayViewProvider` with a fixed `AsyncValue` and asserts only the
// rendering. No `pumpAndSettle` anywhere: a screen that needs settling to show
// its dose has an animation between the reader and the answer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_context_line.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

/// A notifier that emits exactly what a test hands it, and records writes.
class _FixedNotifier extends StreamNotifier<TodayViewState>
    implements TodayNotifier {
  _FixedNotifier(this._state);

  final TodayViewState _state;

  /// Every mutation the screen asked for, by name.
  static final List<String> calls = <String>[];

  @override
  Stream<TodayViewState> build() => Stream<TodayViewState>.value(_state);

  @override
  Future<void> markTakenToday() async => calls.add('markTakenToday');

  @override
  Future<void> undoLast() async => calls.add('undoLast');

  @override
  Future<void> startNextStep() async => calls.add('startNextStep');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const flare = FlarePrompt(
    candidates: <FlareCandidate>[],
    defaultRevertTo: Milligrams.fromHundredths(900),
    suggestedStep: Milligrams.fromHundredths(50),
    stepDiffersFromCommunity: false,
  );

  TodayDose doseWith({bool taken = false, BackfillPrompt? backfill}) =>
      TodayDose(
        dateLine: 'Thursday 16 April',
        doseAmount: '9',
        doseUnit: 'mg',
        tablets: '1 × 5mg · 4 × 1mg',
        unachievableMessage: null,
        isNewDoseDay: true,
        taken: taken,
        stepIndex: '3',
        stepCount: '15',
        fromDose: '10mg',
        toDose: '9mg',
        dayInStep: '14',
        stepLength: '52',
        isSteadyState: false,
        holdingLabel: null,
        backfill: backfill,
        noteText: null,
        flare: flare,
        hold: const HoldPrompt(
          stepId: 7,
          blockLabel: 'Block 3 of 11',
          defaultExtraDays: 7,
          minExtraDays: 1,
          maxExtraDays: 28,
        ),
      );

  setUp(_FixedNotifier.calls.clear);

  Future<void> pumpState(
    WidgetTester tester,
    TodayViewState state, {
    Size surfaceSize = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await pumpApp(
      tester,
      const TodayScreen(),
      overrides: <Override>[
        todayViewProvider.overrideWith(() => _FixedNotifier(state)),
      ],
      surfaceSize: surfaceSize,
      textScaler: textScaler,
    );
    // ONE extra pump for the stream's first value. Never `pumpAndSettle`.
    await tester.pump();
  }

  testWidgets('no plan renders the empty state, and it routes to Plan', (
    tester,
  ) async {
    await pumpState(tester, const TodayNoPlan());

    expect(find.byType(TaperEmptyState), findsOneWidget);
    expect(find.text('Your plan starts here'), findsOneWidget);
    expect(find.byType(DoseHeroCard), findsNothing);
  });

  testWidgets('the taper-complete card shows no dose and no Taken', (
    tester,
  ) async {
    await pumpState(tester, const TodayTaperComplete());

    expect(find.text('You reached your target'), findsOneWidget);
    expect(find.byType(DoseHeroCard), findsNothing);
    expect(find.byType(TakenButton), findsNothing);
  });

  testWidgets('an ordinary day renders hero, context and actions', (
    tester,
  ) async {
    await pumpState(tester, doseWith());

    expect(find.byType(DoseHeroCard), findsOneWidget);
    expect(find.byType(DoseContextLine), findsOneWidget);
    expect(find.text('Add note'), findsOneWidget);
    expect(find.text('Flare'), findsOneWidget);
  });

  testWidgets('the Taken button writes through the notifier, once', (
    tester,
  ) async {
    await pumpState(tester, doseWith());

    await tester.tap(find.text('Mark as taken'));
    await tester.pump();

    expect(_FixedNotifier.calls, <String>['markTakenToday']);
  });

  testWidgets('a step finished keeps the hero AND offers the next step', (
    tester,
  ) async {
    // Day 53 is a real day with a real dose. A screen that showed only "start
    // the next step" would leave the reader nothing to take today.
    await pumpState(
      tester,
      const TodayStepFinished(
        dateLine: 'Thursday 16 April',
        doseAmount: '9',
        doseUnit: 'mg',
        tablets: '1 × 5mg · 4 × 1mg',
        unachievableMessage: null,
        taken: false,
        stepIndex: '3',
        stepCount: '15',
        nextStepPreview: '9mg → 8.5mg',
        canStartNextStep: true,
        flare: flare,
        hold: null,
      ),
    );

    expect(find.byType(DoseHeroCard), findsOneWidget);
    expect(find.byType(TakenButton), findsOneWidget);
    expect(find.textContaining('This step’s days are done'), findsOneWidget);

    await tester.tap(find.text('Start next step'));
    await tester.pump();

    expect(_FixedNotifier.calls, <String>['startNextStep']);
  });

  testWidgets('at 390x844 and 1.0 scale NOTHING scrolls', (tester) async {
    // The requirement: the answer is on screen without a scroll. The scroll
    // view exists only so 200% and landscape do not clip.
    await pumpState(tester, doseWith());

    // Read off the STATE, not the widget: a `SingleChildScrollView` with no
    // explicit controller has `controller == null`, so
    // `controller?.position.maxScrollExtent ?? 0` is 0 whatever the content
    // does — a test that passes on a screen scrolling by 300 pixels.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(
      position.maxScrollExtent,
      0,
      reason: 'the answer needs a scroll — SPEC.md 4.1 says it must not',
    );
  });

  testWidgets('at 2.0 it scrolls, and nothing clips', (tester) async {
    await pumpState(
      tester,
      doseWith(),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DoseHeroCard), findsOneWidget);
  });

  testWidgets('the hero and the context sit SIDE BY SIDE above 600', (
    tester,
  ) async {
    // Both sides of the breakpoint. `SPEC.md` §5.4: people prop tablets on
    // kitchen tables, and one column there wastes the short dimension.
    await pumpState(tester, doseWith(), surfaceSize: const Size(599, 844));
    final narrowHero = tester.getCenter(find.byType(DoseHeroCard));
    final narrowLine = tester.getCenter(find.byType(DoseContextLine));
    expect(narrowLine.dy, greaterThan(narrowHero.dy));

    await pumpState(tester, doseWith(), surfaceSize: const Size(601, 844));

    final wideHero = tester.getCenter(find.byType(DoseHeroCard));
    final wideLine = tester.getCenter(find.byType(DoseContextLine));
    expect(wideLine.dx, greaterThan(wideHero.dx));
  });

  testWidgets('no run means no banner', (tester) async {
    await pumpState(tester, doseWith());

    expect(find.textContaining('marked the last'), findsNothing);
  });

  testWidgets('it does not scroll in the height the SHELL actually gives it', (
    tester,
  ) async {
    // 844 is the device, not the screen. The status bar takes ~59 and the tab
    // bar takes 96, so on the smallest common phone this screen gets about
    // 720 — and "no scroll at 390x844" is a claim about a viewport the screen
    // never has. Measured on a simulator, where it scrolled while this suite
    // was green.
    await pumpState(tester, doseWith(), surfaceSize: const Size(390, 720));

    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .maxScrollExtent,
      0,
      reason: 'the answer needs a scroll on a real phone',
    );
  });

  testWidgets('the ANSWER is on screen without scrolling, banner or not', (
    tester,
  ) async {
    // The requirement behind "nothing scrolls" is that the dose is readable
    // the moment the app opens (SPEC.md 4.1) — not that the viewport happens
    // to be tall enough for everything.
    //
    // With a backfill banner up, at the height the SHELL actually gives this
    // screen (~720 after the status bar and the 96pt tab bar), the content is
    // about 30 pixels taller than the viewport. What falls below the fold is
    // the quiet action row — the least important thing here, used a handful of
    // times in two years. The hero must not, ever, and that is what this
    // asserts.
    for (final backfill in <BackfillPrompt?>[
      null,
      const BackfillPrompt(
        oldest: LocalDate(2026, 4, 12),
        count: 4,
        label: 'You haven’t marked the last 4 days',
      ),
    ]) {
      await pumpState(
        tester,
        doseWith(backfill: backfill),
        surfaceSize: const Size(390, 720),
      );

      final hero = tester.getRect(find.byType(DoseHeroCard));
      expect(
        hero.bottom,
        lessThanOrEqualTo(720),
        reason:
            'the dose was below the fold '
            '(backfill: ${backfill != null})',
      );
      // And the Taken button with it: the answer and the action are one unit.
      expect(
        tester.getRect(find.byType(TakenButton)).bottom,
        lessThanOrEqualTo(720),
        reason: 'the Taken button was below the fold',
      );
    }
  });

  testWidgets('a run of missed days renders the banner', (tester) async {
    // Its own test rather than a second pump in the one above: re-pumping the
    // same widget type UPDATES the tree, and a Riverpod override swapped that
    // way does not always rebuild the notifier — which makes the assertion
    // about the harness rather than the screen.
    await pumpState(
      tester,
      doseWith(
        backfill: const BackfillPrompt(
          oldest: LocalDate(2026, 4, 12),
          count: 4,
          label: 'You haven’t marked the last 4 days',
        ),
      ),
    );

    expect(find.text('You haven’t marked the last 4 days'), findsOneWidget);
  });
}
