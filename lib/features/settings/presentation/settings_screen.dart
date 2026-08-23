/// Settings: where the app's promises are kept, and stated.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_cards.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The app's version and build, read once.
///
/// Backup, before EPIC-13 fills it in.
///
/// Wired to a stub that reports "not built yet" rather than left as a dead
/// button, so the plumbing is proven before the feature lands.
final Provider<Future<void> Function()?> backupActionProvider =
    Provider<Future<void> Function()?>((ref) => null);

/// The settings screen.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  /// Above this width the column stops stretching.
  ///
  /// A settings row 1200px wide puts its control a hand's width from its
  /// label. 640 is the reading measure the rest of the app uses.
  static const double maxContentWidth = 640;

  /// Finds the reading column, so its width is assertable.
  static const Key contentKey = Key('settings-content');

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _rowError;

  Future<void> _write(
    Future<Result<void, Failure>> Function() action,
    String failureMessage,
  ) async {
    final result = await action();
    if (!mounted) return;
    setState(() => _rowError = result is Ok ? null : failureMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          key: SettingsScreen.contentKey,
          constraints: const BoxConstraints(
            maxWidth: SettingsScreen.maxContentWidth,
          ),
          child: ListView(
            padding: EdgeInsetsDirectional.all(shapes.s5),
            children: <Widget>[
              if (_rowError case final message?)
                SettingsInlineError(message: message),
              AccessibilityCard(settings: settings, onWrite: _write),
              LanguageCard(settings: settings, onWrite: _write),
              const BackupCard(),
              const AboutCard(),
              SizedBox(height: shapes.s4),
              const PrivacyFootnote(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed write, said beside the rows rather than in a `SnackBar`.
///
/// A setting the reader has to act on does not time out.
class SettingsInlineError extends StatelessWidget {
  /// Creates the notice.
  const SettingsInlineError({required this.message, super.key});

  /// What failed, already localized.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: EdgeInsetsDirectional.only(bottom: shapes.s4),
        padding: EdgeInsetsDirectional.all(shapes.s3),
        decoration: BoxDecoration(
          color: colors.tintWarning,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          border: Border.all(
            color: colors.warning,
            width: shapes.hairlineWidth,
          ),
        ),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}
