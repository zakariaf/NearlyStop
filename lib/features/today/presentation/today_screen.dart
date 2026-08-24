/// The Today screen — the product.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/features/shared/presentation/widgets/backfill_banner.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/error_panel.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_context_line.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/features/today/presentation/widgets/flare_sheet.dart';
import 'package:nearlystop/features/today/presentation/widgets/hold_sheet.dart';
import 'package:nearlystop/features/today/presentation/widgets/quiet_action_row.dart';
import 'package:nearlystop/features/today/presentation/widgets/today_date_header.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// What to swallow today, and one button.
///
/// A person aged 60–80 opens this on roughly 780 consecutive mornings and asks
/// one question. If the answer needs a scroll, a tap or a squint, the app has
/// failed regardless of how correct the arithmetic underneath is
/// (`SPEC.md` §4.1) — which is why at 1.0 scale on a 390×844 frame **nothing
/// scrolls**, and the scroll view exists only so 200% and landscape do not
/// clip.
class TodayScreen extends ConsumerWidget {
  /// Creates the screen.
  const TodayScreen({super.key});

  /// Above this width the hero and the context column sit side by side.
  ///
  /// `SPEC.md` §5.4: people prop tablets on kitchen tables, and a single column
  /// there wastes the short dimension.
  static const double sideBySideBreakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(todayViewProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (view) {
          AsyncError<TodayViewState>() => ErrorPanel(
            title: l10n.errorTitle,
            retryLabel: l10n.errorRetry,
            onRetry: () => ref.invalidate(todayViewProvider),
          ),
          // A skeleton that reserves the hero's height, never a spinner: a
          // spinner that becomes a card moves everything under it, and this
          // reader is already unsure whether they tapped.
          AsyncValue<TodayViewState>(hasValue: false) => const _Skeleton(),
          // `requireValue`, guarded by the `hasValue: false` arm above.
          AsyncValue<TodayViewState>() => _Loaded(state: view.requireValue),
        },
      ),
    );
  }
}

/// The four sealed variants, each with its own tree.
class _Loaded extends ConsumerWidget {
  const _Loaded({required this.state});

  final TodayViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);

    return switch (state) {
      TodayNoPlan() => TaperEmptyState(
        heading: l10n.noPlanHeading,
        message: l10n.noPlanBody,
        actionLabel: l10n.noPlanAction,
        onAction: () => context.go(Routes.plan),
      ),
      TodayTaperComplete() => _FinishCard(
        title: l10n.taperCompleteTitle,
        body: l10n.taperCompleteBody,
      ),
      // `s3` between sections, not `s4`: four gaps at 16 is 64 pixels of air
      // on a screen that has to fit a hero, a context line, a banner and three
      // tiles into the ~720 the shell leaves after its tab bar.
      TodayDose() => _TodayBody(
        state: state as TodayDose,
        padding: shapes.s3,
      ),
      TodayStepFinished() => _StepFinishedBody(
        state: state as TodayStepFinished,
        padding: shapes.s3,
      ),
    };
  }
}

/// The ordinary day.
class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.state, required this.padding});

  final TodayDose state;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(todayViewProvider.notifier);
    final wide =
        MediaQuery.sizeOf(context).width >= TodayScreen.sideBySideBreakpoint;

    final hero = _hero(
      l10n: l10n,
      notifier: notifier,
      doseAmount: state.doseAmount,
      doseUnit: state.doseUnit,
      tablets: state.tablets,
      unachievableMessage: state.unachievableMessage,
      isNewDose: state.isNewDoseDay,
      taken: state.taken,
    );

    final rest = <Widget>[
      DoseContextLine(
        // The WORDS. "3 / 15" and "14 / 52" are four unlabelled numbers on
        // the line whose whole job is orientation — see `DoseContextLine`.
        stepLabel: l10n.stepOfTotal(state.stepIndex, state.stepCount),
        fromDose: state.fromDose,
        toDose: state.toDose,
        dayLabel: state.dayInStep == null
            ? null
            : l10n.dayOfStep(state.dayInStep!, state.stepLength!),
        holdingLabel: state.holdingLabel,
        semanticsLabel: l10n.contextLineSemantics(
          state.stepIndex,
          state.stepCount,
          state.fromDose,
          state.toDose,
          state.dayInStep ?? '',
          state.stepLength ?? '',
        ),
      ),
      if (state.backfill case final prompt?) ...<Widget>[
        SizedBox(height: padding),
        BackfillBanner(
          message: prompt.label,
          primaryActionLabel: l10n.backfillAction,
          onPrimaryAction: () => _answerBackfill(context, ref, prompt),
          secondaryActionLabel: l10n.actionNotNow,
          // Dismissing is local: the days are still un-ticked and the prompt
          // returns tomorrow. Writing "dismissed" would be recording a fact
          // about the reader's attention, which is not this app's business.
          onSecondaryAction: () {},
        ),
      ],
      SizedBox(height: padding),
      QuietActionRow(
        noteLabel: l10n.actionAddNote,
        holdLabel: l10n.actionHold,
        flareLabel: l10n.actionFlare,
        holdDisabledReason: state.hold == null
            ? l10n.holdNeedsActiveStep
            : null,
        onAddNote: () => _openNote(context, ref, state.noteText),
        onHold: () => _openHold(context, ref, state),
        onFlare: () => _openFlare(context, ref, state.flare),
      ),
    ];

    return _Scroller(
      children: <Widget>[
        TodayDateHeader(
          dateLine: state.dateLine,
          title: l10n.tabToday,
          noteHint: l10n.noteTitle,
          onOpenNote: () => _openNote(context, ref, state.noteText),
        ),
        SizedBox(height: padding),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: hero),
              SizedBox(width: padding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: rest,
                ),
              ),
            ],
          )
        else ...<Widget>[
          hero,
          SizedBox(height: padding),
          ...rest,
        ],
      ],
    );
  }
}

/// Day 53: the step's days are used up and the next has not been started.
class _StepFinishedBody extends ConsumerWidget {
  const _StepFinishedBody({required this.state, required this.padding});

  final TodayStepFinished state;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final notifier = ref.read(todayViewProvider.notifier);

    return _Scroller(
      children: <Widget>[
        TodayDateHeader(
          dateLine: state.dateLine,
          title: l10n.tabToday,
          noteHint: l10n.noteTitle,
          onOpenNote: () => _openNote(context, ref, null),
        ),
        SizedBox(height: padding),
        // The hero STAYS. Day 53 carries a real dose at the step's `toDose`,
        // and a screen that showed only "start the next step" would leave the
        // reader with nothing to take today.
        _hero(
          l10n: l10n,
          notifier: notifier,
          doseAmount: state.doseAmount,
          doseUnit: state.doseUnit,
          tablets: state.tablets,
          unachievableMessage: state.unachievableMessage,
          // Never a new-dose day: the alternation is over.
          isNewDose: false,
          taken: state.taken,
        ),
        SizedBox(height: padding),
        Text(
          l10n.stepFinishedExplainer,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
        ),
        SizedBox(height: padding),
        Text(
          state.nextStepPreview,
          style: Theme.of(context).textTheme.titleMedium
              ?.atWeight(FontWeight.w800)
              .copyWith(color: colors.ink),
        ),
        SizedBox(height: padding),
        PrimaryPillButton(
          label: l10n.startNextStep,
          expand: true,
          onPressed: state.canStartNextStep ? notifier.startNextStep : null,
        ),
      ],
    );
  }
}

/// The body every variant scrolls in.
///
/// `ClampingScrollPhysics` and no bounce: at 1.0 on a 390×844 frame there is
/// nothing to scroll, and a screen that springs under a finger reads as broken
/// to someone who did not mean to drag it.
class _Scroller extends StatelessWidget {
  const _Scroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      // `.screenbody { padding: var(--s-2) var(--s-5) var(--s-6) }`.
      //
      // NOT `all(padding)`. `padding` is the s3 VERTICAL rhythm between
      // sections — chosen at 12 rather than 16 so a hero, a context line, a
      // banner and three tiles fit the ~720 the shell leaves — and spreading it
      // to all four sides took the horizontal frame down with it. The card came
      // out 366 wide against the reference's 350, which is most of what "the
      // cards are bigger" was.
      padding: EdgeInsetsDirectional.fromSTEB(
        shapes.s5,
        shapes.s2,
        shapes.s5,
        shapes.s6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// The loading state, sized like the thing it is standing in for.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  /// The hero's approximate height at 1.0, so nothing jumps when data lands.
  static const double heroHeight = 260;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.all(shapes.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: heroHeight,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A read failed. Says so, and offers one way forward.

/// The taper reached its target.
class _FinishCard extends StatelessWidget {
  const _FinishCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(shapes.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.wb_sunny_outlined, size: 56, color: colors.primaryDeep),
          SizedBox(height: shapes.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.atWeight(FontWeight.w800)
                .copyWith(color: colors.ink),
          ),
          SizedBox(height: shapes.s3),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// The hero, built the same way for both variants that carry a dose.
///
/// Day 53 is a real day with a real dose, so `TodayStepFinished` renders the
/// same card `TodayDose` does — and two near-copies of a nine-argument
/// constructor is two places for the semantics sentence to drift.
DoseHeroCard _hero({
  required AppLocalizations l10n,
  required TodayNotifier notifier,
  required String doseAmount,
  required String doseUnit,
  required String? tablets,
  required String? unachievableMessage,
  required bool isNewDose,
  required bool taken,
}) => DoseHeroCard(
  doseText: doseAmount,
  unitText: doseUnit,
  tabletsText: tablets,
  unachievableMessage: unachievableMessage,
  dayKindLabel: l10n.stateNewDoseDay,
  isNewDoseDay: isNewDose,
  semanticsLabel: _heroSentence(
    l10n,
    doseAmount,
    tablets ?? unachievableMessage ?? '',
    isNewDose: isNewDose,
    taken: taken,
  ),
  takenLabel: taken ? l10n.stateTaken : l10n.markTaken,
  isTaken: taken,
  onTaken: notifier.markTakenToday,
  onUndo: notifier.undoLast,
);

/// The hero as one sentence: new-dose day, ordinary day, or already taken.
String _heroSentence(
  AppLocalizations l10n,
  String dose,
  String breakdown, {
  required bool isNewDose,
  required bool taken,
}) {
  if (taken) return l10n.todaySemanticsTaken(dose, breakdown);
  return isNewDose
      ? l10n.todaySemanticsNewDose(dose, breakdown)
      : l10n.todaySemantics(dose, breakdown);
}

/// One day missed: tick it here. More than one: go where ticking many belongs.
Future<void> _answerBackfill(
  BuildContext context,
  WidgetRef ref,
  BackfillPrompt prompt,
) async {
  if (prompt.count == 1) {
    await ref.read(todayViewProvider.notifier).backfill(prompt.oldest);
    return;
  }
  // Four separate days belong on the screen built for ticking rows, focused on
  // the oldest so the reader starts where the run does.
  if (!context.mounted) return;
  context.go('${Routes.schedule}?focus=${_iso(prompt.oldest)}');
}

String _iso(LocalDate date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Future<void> _openFlare(
  BuildContext context,
  WidgetRef ref,
  FlarePrompt prompt,
) async {
  final chosen = await showFlareSheet(
    context,
    prompt,
    AppLocalizations.of(context),
  );
  if (chosen == null) return;
  await ref.read(todayViewProvider.notifier).recordFlare(chosen);
}

Future<void> _openHold(
  BuildContext context,
  WidgetRef ref,
  TodayDose state,
) async {
  final prompt = state.hold;
  if (prompt == null) return;
  final days = await showHoldSheet(
    context,
    prompt,
    AppLocalizations.of(context),
    doseLabel: '${state.doseAmount}${state.doseUnit}',
  );
  if (days == null) return;
  await ref.read(todayViewProvider.notifier).recordHold(days);
}

Future<void> _openNote(
  BuildContext context,
  WidgetRef ref,
  String? existing,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: existing);
  try {
    final saved = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: DaybreakColors.of(context).overlay,
      builder: (context) => _NoteSheet(controller: controller, l10n: l10n),
    );
    if (saved == null) return;
    await ref
        .read(todayViewProvider.notifier)
        .saveNote(
          saved.isEmpty ? null : saved,
        );
  } finally {
    controller.dispose();
  }
}

/// One free-text note per day (`SPEC.md` §8).
class _NoteSheet extends StatelessWidget {
  const _NoteSheet({required this.controller, required this.l10n});

  final TextEditingController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Padding(
      // The keyboard's inset, so the field is not under it. Directional even
      // though `bottom` has no direction: the raw-value gate bans bare
      // `EdgeInsets.` outright, and an exception here would be an exception
      // everywhere.
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(shapes.radiusXl),
            topEnd: Radius.circular(shapes.radiusXl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsetsDirectional.all(shapes.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SheetDragHandle(),
                SizedBox(height: shapes.s4),
                Text(
                  l10n.noteTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.atWeight(FontWeight.w800)
                      .copyWith(color: colors.ink),
                ),
                SizedBox(height: shapes.s3),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: l10n.noteHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(shapes.radiusMd),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: shapes.s4),
                PrimaryPillButton(
                  label: l10n.noteSave,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                ),
                SizedBox(height: shapes.s2),
                TertiaryButton(
                  label: l10n.actionCancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
