/// The fields behind the plan cards.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:nearlystop/features/plan/presentation/widgets/dose_field.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The longest a drug name may be.
const int kMaxDrugNameLength = 60;

/// A dose this app treats as a mistake worth mentioning.
///
/// **Warn, never block.** 120mg is unusual and it is also what somebody with
/// giant cell arteritis is genuinely started on. Refusing it would tell a
/// person with a real prescription that their own dose is impossible.
const Milligrams kDoseSanityCeiling = Milligrams.fromHundredths(10000);

/// Every field that can refuse what was typed into it.
///
/// Named rather than counted, so the Save button can say *which* field is
/// wrong instead of holding a bare `bool` that nothing can explain.
enum PlanField {
  /// The medicine's name.
  drugName,

  /// The dose they are on now.
  currentDose,

  /// The dose they are heading for.
  targetDose,

  /// Percent per step, for [TaperMethod.percentage].
  percentage,

  /// A fixed step, for [TaperMethod.fixedMg].
  fixedStep,

  /// Days a non-DSNS step holds the new dose.
  holdPeriod,
}

/// Reports [field]'s localized error, or null now that it reads back.
///
/// **Reported rather than read back off a `FormState`.** `validate()` calls
/// `setState` on every field, so it cannot be called during a build — which is
/// exactly when the Save button needs the answer.
typedef PlanFieldErrorCallback = void Function(PlanField field, String? error);

/// Drug, current dose, target dose and start date.
///
/// Every controller and focus node is created and disposed here. Parsing goes
/// through EPIC-03's `parseDose` in the APP's locale — never `double.parse`,
/// because `U+066B` is a decimal separator and the reader may have overridden
/// the language in Settings.
class PlanEditForm extends StatefulWidget {
  /// Creates the form.
  const PlanEditForm({
    required this.draft,
    required this.locale,
    required this.l10n,
    required this.onChanged,
    required this.onFieldError,
    super.key,
  });

  /// Finds the drug-name field.
  static const Key drugNameKey = Key('plan-drug-name');

  /// Finds the current-dose field.
  static const Key currentDoseKey = Key('plan-current-dose');

  /// Finds the target-dose field.
  static const Key targetDoseKey = Key('plan-target-dose');

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale — the one the UI formats with, not the phone's.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  /// Hands back the edited draft.
  final ValueChanged<PlanDraft> onChanged;

  /// Hands back each field's current verdict.
  final PlanFieldErrorCallback onFieldError;

  @override
  State<PlanEditForm> createState() => _PlanEditFormState();
}

class _PlanEditFormState extends State<PlanEditForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _target = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = widget.draft.drugName;
    _current.text = formatDose(widget.draft.currentDose, widget.locale);
    _target.text = formatDose(widget.draft.targetDose, widget.locale);
  }

  @override
  void didUpdateWidget(PlanEditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seeded ONLY when the value arriving is different from the one that
    // arrived last time — never merely because the draft rebuilt.
    //
    // The difference is the whole field. Comparing against what is typed
    // instead makes an unreadable entry bounce straight back to the last good
    // value on the next frame: clear the field to retype it and `10` reappears
    // under your cursor, and a German `9.5` is silently un-rejected before the
    // reader can see the error it raised.
    final reformat = widget.locale != oldWidget.locale;
    if (reformat || widget.draft.drugName != oldWidget.draft.drugName) {
      _name.text = widget.draft.drugName;
    }
    if (reformat || widget.draft.currentDose != oldWidget.draft.currentDose) {
      _current.text = formatDose(widget.draft.currentDose, widget.locale);
    }
    if (reformat || widget.draft.targetDose != oldWidget.draft.targetDose) {
      _target.text = formatDose(widget.draft.targetDose, widget.locale);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _target.dispose();
    super.dispose();
  }

  String? _nameError(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return widget.l10n.planErrorNameRequired;
    if (value.length > kMaxDrugNameLength) {
      return widget.l10n.planErrorNameTooLong;
    }
    return null;
  }

  /// The current dose as the FIELD reads it, falling back to the draft.
  ///
  /// The target's rule depends on the current dose, and while the current-dose
  /// field is unreadable the draft still holds the last good value — which is
  /// the honest thing to compare against.
  Milligrams get _currentDose =>
      readDose(_current.text, widget.locale) ?? widget.draft.currentDose;

  String? _targetError(String raw) {
    final error = doseFieldError(raw, widget.locale, widget.l10n);
    if (error != null) return error;
    final value = readDose(raw, widget.locale)!;
    if (value >= _currentDose) return widget.l10n.planErrorTargetTooHigh;
    return null;
  }

  /// Re-reports every field, then hands back [next].
  ///
  /// All three together on every keystroke, because the target's verdict
  /// depends on the current dose: reporting only the field that changed leaves
  /// a stale "target too high" behind after the current dose is raised.
  void _emit(PlanDraft next) {
    widget.onFieldError(PlanField.drugName, _nameError(_name.text));
    widget.onFieldError(
      PlanField.currentDose,
      doseFieldError(_current.text, widget.locale, widget.l10n),
    );
    widget.onFieldError(PlanField.targetDose, _targetError(_target.text));
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    final l10n = widget.l10n;
    final draft = widget.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextFormField(
          key: PlanEditForm.drugNameKey,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: l10n.planMedicine,
            errorMaxLines: 3,
          ),
          validator: (raw) => _nameError(raw ?? ''),
          onChanged: (raw) => _emit(draft.copyWith(drugName: raw.trim())),
        ),
        SizedBox(height: shapes.s3),
        NumericField(
          key: PlanEditForm.currentDoseKey,
          controller: _current,
          label: l10n.planCurrentDose,
          suffix: l10n.milligramUnit,
          // Warn, never block: a very high dose is unusual and also real.
          helperText: draft.currentDose > kDoseSanityCeiling
              ? l10n.planErrorDoseTooHigh
              : null,
          validator: (raw) => doseFieldError(raw ?? '', widget.locale, l10n),
          onChanged: (raw) {
            final value = readDose(raw, widget.locale);
            _emit(
              value == null
                  ? draft
                  : draft.copyWith(currentDose: value, clearOverride: true),
            );
          },
        ),
        SizedBox(height: shapes.s3),
        NumericField(
          key: PlanEditForm.targetDoseKey,
          controller: _target,
          label: l10n.planTarget,
          suffix: l10n.milligramUnit,
          validator: (raw) => _targetError(raw ?? ''),
          onChanged: (raw) {
            final value = readDose(raw, widget.locale);
            _emit(
              value == null
                  ? draft
                  : draft.copyWith(targetDose: value, clearOverride: true),
            );
          },
        ),
        SizedBox(height: shapes.s3),
        PlanStartDateField(
          date: draft.startDate,
          locale: widget.locale,
          label: l10n.planStartDate,
          onChanged: (date) => _emit(draft.copyWith(startDate: date)),
        ),
      ],
    );
  }
}

/// The arithmetic a non-DSNS method needs, and nothing when it is DSNS.
///
/// DSNS has no percentage and no step size to ask for: the eleven-block
/// calendar IS the answer, and a hold-period field beside it would invite
/// somebody to change a number the method does not have.
class PlanMethodFields extends StatefulWidget {
  /// Creates the fields.
  const PlanMethodFields({
    required this.draft,
    required this.locale,
    required this.l10n,
    required this.onChanged,
    required this.onFieldError,
    super.key,
  });

  /// Finds the percent field.
  static const Key percentageKey = Key('plan-percentage');

  /// Finds the fixed-step field.
  static const Key fixedStepKey = Key('plan-fixed-step');

  /// Finds the hold-period field.
  static const Key holdPeriodKey = Key('plan-hold-period');

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  /// Hands back the edited draft.
  final ValueChanged<PlanDraft> onChanged;

  /// Hands back each field's current verdict.
  final PlanFieldErrorCallback onFieldError;

  @override
  State<PlanMethodFields> createState() => _PlanMethodFieldsState();
}

class _PlanMethodFieldsState extends State<PlanMethodFields> {
  final TextEditingController _percentage = TextEditingController();
  final TextEditingController _fixedStep = TextEditingController();
  final TextEditingController _holdPeriod = TextEditingController();

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(PlanMethodFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != oldWidget.locale ||
        widget.draft.method != oldWidget.draft.method) {
      _seed();
    }
  }

  void _seed() {
    _percentage.text = formatWholeNumber(
      widget.draft.effectivePercentage,
      widget.locale,
    );
    final step = widget.draft.fixedStep;
    _fixedStep.text = step == null ? '' : formatDose(step, widget.locale);
    _holdPeriod.text = formatWholeNumber(
      widget.draft.holdPeriodDays,
      widget.locale,
    );
  }

  @override
  void dispose() {
    _percentage.dispose();
    _fixedStep.dispose();
    _holdPeriod.dispose();
    super.dispose();
  }

  String? _percentageError(String raw) {
    final value = parseWholeNumber(raw);
    if (value == null || value < 1 || value > kMaxPercentagePerStep) {
      return widget.l10n.planErrorPercent;
    }
    return null;
  }

  String? _holdPeriodError(String raw) {
    final value = parseWholeNumber(raw);
    if (value == null || value < 1) return widget.l10n.planErrorHoldPeriod;
    return null;
  }

  String? _fixedStepError(String raw) {
    final error = doseFieldError(raw, widget.locale, widget.l10n);
    if (error != null) return error;
    final value = readDose(raw, widget.locale)!;
    // The distance left to travel. A step past it overshoots the target, which
    // is a dose below the one the clinician agreed.
    final distance = widget.draft.currentDose - widget.draft.targetDose;
    if (value.hundredths <= 0 || value > distance) {
      return widget.l10n.planErrorFixedStep;
    }
    return null;
  }

  void _emit(PlanDraft next) {
    if (widget.draft.method == TaperMethod.percentage) {
      widget.onFieldError(
        PlanField.percentage,
        _percentageError(_percentage.text),
      );
    }
    if (widget.draft.method == TaperMethod.fixedMg) {
      widget.onFieldError(
        PlanField.fixedStep,
        _fixedStepError(_fixedStep.text),
      );
    }
    widget.onFieldError(
      PlanField.holdPeriod,
      _holdPeriodError(_holdPeriod.text),
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.draft.method == TaperMethod.dsns) return const SizedBox.shrink();

    final shapes = DaybreakShapes.of(context);
    final l10n = widget.l10n;
    final draft = widget.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: shapes.s3),
        if (draft.method == TaperMethod.percentage)
          NumericField(
            key: PlanMethodFields.percentageKey,
            controller: _percentage,
            label: l10n.planPercentPerStep,
            suffix: '%',
            decimal: false,
            validator: (raw) => _percentageError(raw ?? ''),
            onChanged: (raw) {
              final value = parseWholeNumber(raw);
              _emit(
                value == null ? draft : draft.copyWith(percentage: value),
              );
            },
          )
        else
          NumericField(
            key: PlanMethodFields.fixedStepKey,
            controller: _fixedStep,
            label: l10n.planFixedStep,
            suffix: l10n.milligramUnit,
            validator: (raw) => _fixedStepError(raw ?? ''),
            onChanged: (raw) {
              final value = readDose(raw, widget.locale);
              _emit(value == null ? draft : draft.copyWith(fixedStep: value));
            },
          ),
        SizedBox(height: shapes.s3),
        NumericField(
          key: PlanMethodFields.holdPeriodKey,
          controller: _holdPeriod,
          label: l10n.planHoldPeriod,
          decimal: false,
          textInputAction: TextInputAction.done,
          validator: (raw) => _holdPeriodError(raw ?? ''),
          onChanged: (raw) {
            final value = parseWholeNumber(raw);
            _emit(
              value == null || value < 1
                  ? draft
                  : draft.copyWith(holdPeriodDays: value),
            );
          },
        ),
      ],
    );
  }
}

/// The start date, entered through the platform picker.
///
/// Date ENTRY may use a platform picker; date BROWSING may not — that is the
/// Schedule screen's ban, and it is about rendering a taper as a month grid,
/// not about ever asking somebody for a date.
class PlanStartDateField extends StatelessWidget {
  /// Creates the field.
  const PlanStartDateField({
    required this.date,
    required this.locale,
    required this.label,
    required this.onChanged,
    super.key,
  });

  /// Finds the field.
  static const Key fieldKey = Key('plan-start-date');

  /// The date now on the draft.
  final LocalDate date;

  /// The app's locale.
  final Locale locale;

  /// The field's label, already localized.
  final String label;

  /// Hands back the chosen date.
  final ValueChanged<LocalDate> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Semantics(
        button: true,
        label: '$label ${formatFullDayLabel(date, locale)}',
        child: ExcludeSemantics(
          child: InkWell(
            key: fieldKey,
            onTap: () => _pick(context),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(formatFullDayLabel(date, locale))),
                Icon(Icons.event_outlined, size: 20, color: colors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date.toUtcMidnight(),
      // A PAST start is allowed and expected: somebody joining mid-taper is
      // entering reality, not planning a future.
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (picked == null) return;
    onChanged(LocalDate.fromDateTime(picked));
  }
}
