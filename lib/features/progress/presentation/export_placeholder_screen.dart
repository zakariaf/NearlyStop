/// The export door, before EPIC-13 fills it.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Says, plainly, that export is coming next.
///
/// **Not a disabled button and not a dead tap.** Both of those read as a
/// broken app to somebody who has been tapping the same five tabs every
/// morning for a year; a screen that says what is happening does not.
class ExportPlaceholderScreen extends StatelessWidget {
  /// Creates the placeholder.
  const ExportPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsExportForDoctor)),
      body: Padding(
        padding: EdgeInsetsDirectional.all(shapes.s5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.ios_share_outlined,
              size: 44,
              color: colors.inkFaint,
            ),
            SizedBox(height: shapes.s4),
            Text(
              l10n.exportComingSoon,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            SizedBox(height: shapes.s3),
            Text(
              l10n.exportComingSoonBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
