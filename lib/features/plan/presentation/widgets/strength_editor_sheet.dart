/// Adding a tablet strength to the list the reader actually holds.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/plan/presentation/widgets/dose_field.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Asks for one strength, and returns it — or null if the reader backed out.
///
/// The sheet is the whole editor: there is no list-management screen, because
/// the list is three or four numbers off the side of a box.
Future<Milligrams?> showStrengthEditor({
  required BuildContext context,
  required Locale locale,
  required AppLocalizations l10n,
}) => showDaybreakSheet<Milligrams>(
  context: context,
  builder: (context) => StrengthEditorSheet(locale: locale, l10n: l10n),
);

/// One dose field, and the two ways out of it.
class StrengthEditorSheet extends StatefulWidget {
  /// Creates the sheet.
  const StrengthEditorSheet({
    required this.locale,
    required this.l10n,
    super.key,
  });

  /// Finds the dose field.
  static const Key doseKey = Key('strength-editor-dose');

  /// The app's locale — the one the UI formats with, not the phone's.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  @override
  State<StrengthEditorSheet> createState() => _StrengthEditorSheetState();
}

class _StrengthEditorSheetState extends State<StrengthEditorSheet> {
  final TextEditingController _dose = TextEditingController();

  @override
  void dispose() {
    _dose.dispose();
    super.dispose();
  }

  void _add() {
    final value = readDose(_dose.text, widget.locale);
    // Zero is not a strength: a 0mg tablet composes nothing and would sit in
    // the chip row looking like something the reader owns.
    if (value == null || value.hundredths <= 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    final l10n = widget.l10n;

    return DaybreakSheetShell(
      routeLabel: l10n.planAddStrength,
      child: Padding(
        // The keyboard's inset, so the field is not under it on a small phone.
        // Directional even though `bottom` has no direction: the raw-value
        // gate bans bare `EdgeInsets.` outright, and an exception here would
        // be an exception everywhere.
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            NumericField(
              key: StrengthEditorSheet.doseKey,
              controller: _dose,
              label: l10n.planStrengthValue,
              suffix: l10n.milligramUnit,
              textInputAction: TextInputAction.done,
              validator: (raw) =>
                  doseFieldError(raw ?? '', widget.locale, l10n),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: shapes.s4),
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: l10n.actionCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: shapes.s3),
                Expanded(
                  child: PrimaryPillButton(
                    label: l10n.actionAdd,
                    // Derived from the field, never a stored flag: a stale
                    // `bool` is how a sheet stays enabled over text that no
                    // longer parses.
                    onPressed: readDose(_dose.text, widget.locale) == null
                        ? null
                        : _add,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
