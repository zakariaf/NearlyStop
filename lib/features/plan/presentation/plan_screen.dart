/// The Plan screen.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

/// A placeholder until its own epic fills it in.
///
/// It exists so routing, goldens and accessibility wiring can be tested now,
/// and so that epic is a single-file replacement rather than a merge. `const`
/// on purpose: a screen that cannot be constructed `const` is one holding
/// state it should not.
class PlanScreen extends StatelessWidget {
  /// Creates the screen.
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabPlan)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          'The plan you and your doctor agreed, and the tablets you hold.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
