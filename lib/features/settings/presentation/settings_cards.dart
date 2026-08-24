/// The four Settings cards and the footnote.
///
/// **Not under `widgets/`.** These are screen SECTIONS: they watch providers
/// and write settings, which is exactly what the layering gate keeps out of
/// the component directory. The dumb recipes they are built from —
/// `SettingsCard`, `SettingsRow`, `SettingsDivider` — live there instead.
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/app/app_version.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/backup/presentation/backup_actions.dart';
import 'package:nearlystop/features/backup/presentation/export_guard.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/application/settings_view_state.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/settings/presentation/widgets/settings_rows.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_card.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/glyph_tile.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:nearlystop/services/files/file_picker_gateway.dart';
import 'package:nearlystop/services/notifications/notification_permissions.dart';
import 'package:nearlystop/services/notifications/reconcile_triggers.dart';
import 'package:nearlystop/services/notifications/sync_notifications.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// A write through EPIC-06's controller, with the message to show if it fails.
typedef SettingsWrite =
    Future<void> Function(
      Future<Result<void, Failure>> Function() action,
      String failureMessage,
    );

/// Reminder, text size and high contrast.
class AccessibilityCard extends ConsumerWidget {
  /// Creates the card.
  const AccessibilityCard({
    required this.settings,
    required this.onWrite,
    super.key,
  });

  /// The current row.
  final AppSettings settings;

  /// How to write, and what to say when the write fails.
  final SettingsWrite onWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(resolvedLocaleProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final minute = settings.reminderMinuteOfDay;
    final blocked = ref.watch(notificationsBlockedProvider);

    return DaybreakCard(
      overline: l10n.settingsAccessibility,
      overlineCaps: l10n.settingsAccessibilityCaps,
      padding: EdgeInsets.zero,
      children: <Widget>[
        SettingsRow(
          glyph: Icons.notifications_none,
          title: l10n.settingsReminder,
          sublabel: blocked
              // The OS is refusing to post, though the setting is on. Saying
              // "On · 8:00 am" here would be the app lying to somebody who is
              // relying on it every morning.
              ? l10n.reminderBlocked
              : settings.reminderEnabled && minute != null
              ? l10n.settingsReminderAt(_formatTime(context, minute, locale))
              : l10n.settingsOff,
          onTap: settings.reminderEnabled
              ? () => _pickTime(context, ref, minute)
              : null,
          trailing: Switch(
            value: settings.reminderEnabled,
            onChanged: (value) => onWrite(
              () => ref.read(setReminderEnabledProvider)(enabled: value),
              l10n.errorTitle,
            ),
          ),
        ),
        if (blocked) ...<Widget>[
          const SettingsDivider(),
          // INLINE, never a SnackBar: information the reader has to act on
          // does not time out. Spelled out in words per platform because
          // nothing available here can open the OS notification settings, and
          // this app is not taking a dependency for one string.
          SettingsInlineError(
            message: defaultTargetPlatform == TargetPlatform.iOS
                ? l10n.reminderBlockedIos
                : l10n.reminderBlockedAndroid,
          ),
        ],
        const SettingsDivider(),
        TextSizeRow(settings: settings, onWrite: onWrite),
        const SettingsDivider(),
        SettingsRow(
          glyph: Icons.contrast,
          title: l10n.settingsHighContrast,
          sublabel: settings.highContrast ? l10n.settingsOn : l10n.settingsOff,
          trailing: Switch(
            value: settings.highContrast,
            onChanged: (value) => onWrite(
              () => controller.setHighContrast(enabled: value),
              l10n.errorTitle,
            ),
          ),
        ),
      ],
    );
  }

  /// The reminder time in the app's locale, never the phone's.
  ///
  /// The reader may have overridden the language in the row below; a 12-hour
  /// clock rendered in a locale they did not choose is the same bug as an
  /// English label they cannot read.
  String _formatTime(BuildContext context, int minute, Locale locale) {
    final time = minutesToTimeOfDay(minute);
    return formatTimeOfDay(time.hour, time.minute, locale);
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: minutesToTimeOfDay(current ?? 8 * 60),
    );
    // A dismissed picker writes NOTHING. The row is the reader's alarm, and a
    // cancelled dialog that still moved it is worse than no picker at all.
    if (picked == null) return;
    await onWrite(
      () => ref
          .read(settingsControllerProvider.notifier)
          .setReminderMinuteOfDay(timeOfDayToMinutes(picked)),
      l10n.errorTitle,
    );
  }
}

/// The A—slider—A control.
class TextSizeRow extends ConsumerWidget {
  /// Creates the row.
  const TextSizeRow({required this.settings, required this.onWrite, super.key});

  /// The current row.
  final AppSettings settings;

  /// How to write.
  final SettingsWrite onWrite;

  /// The current size, in the reader's own words.
  String _sizeName(AppLocalizations l10n, double value) =>
      switch (textSizeNameFor(value)) {
        TextSizeName.normal => l10n.settingsTextSizeNormal,
        TextSizeName.large => l10n.settingsTextSizeLarge,
        TextSizeName.larger => l10n.settingsTextSizeLarger,
        TextSizeName.largest => l10n.settingsTextSizeLargest,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final locale = ref.watch(resolvedLocaleProvider);
    final value = quantiseTextScale(settings.textScale);
    final numbers = numberFormatFor(locale);

    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: shapes.s4,
        vertical: shapes.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const GlyphTile(glyph: Icons.format_size),
              SizedBox(width: shapes.s3),
              Expanded(
                child: Text(
                  l10n.settingsTextSize,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              Text(
                _sizeName(l10n, value),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              // The two As are the control's scale, not decoration — they say
              // which end is which without reading a number.
              ExcludeSemantics(
                child: Text(
                  'A',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  min: kMinTextScaleSetting,
                  max: kMaxTextScaleSetting,
                  divisions: 10,
                  label: numbers.format(value),
                  semanticFormatterCallback: (raw) =>
                      l10n.settingsTextSizeSemantics(numbers.format(raw)),
                  onChanged: (raw) => onWrite(
                    () => ref
                        .read(settingsControllerProvider.notifier)
                        .setTextScale(quantiseTextScale(raw)),
                    l10n.errorTitle,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  'A',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The language row — the control that makes `localeTag` a live column.
class LanguageCard extends ConsumerWidget {
  /// Creates the card.
  const LanguageCard({
    required this.settings,
    required this.onWrite,
    super.key,
  });

  /// Finds the row, for tests that tap it.
  static const Key rowKey = Key('settings-language-row');

  /// The current row.
  final AppSettings settings;

  /// How to write.
  final SettingsWrite onWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = languageSelectionFor(settings.localeTag);

    return DaybreakCard(
      padding: EdgeInsets.zero,
      children: <Widget>[
        SettingsRow(
          key: rowKey,
          glyph: Icons.language,
          title: l10n.settingsLanguage,
          sublabel: selection.nativeName ?? l10n.settingsSystemLanguage,
          trailing: Icon(
            // Mirrors itself in RTL. EPIC-01's ban gate rejects the
            // non-adaptive name for exactly this reason.
            Icons.adaptive.arrow_forward,
            size: 20,
            color: DaybreakColors.of(context).inkMuted,
          ),
          onTap: () => _pick(context, ref, selection),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    LanguageSelection current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showDaybreakSheet<LanguageSelection>(
      context: context,
      builder: (context) => DaybreakSheetShell(
        routeLabel: l10n.settingsLanguage,
        child: LanguagePickerSheet(
          current: current,
          systemLabel: l10n.settingsSystemLanguage,
          title: l10n.settingsLanguage,
        ),
      ),
    );
    if (chosen == null) return;
    await onWrite(
      () => ref
          .read(settingsControllerProvider.notifier)
          .setLocaleTag(chosen.tag),
      l10n.errorTitle,
    );
  }
}

/// Five options, each in its own script.
class LanguagePickerSheet extends StatelessWidget {
  /// Creates the sheet.
  const LanguagePickerSheet({
    required this.current,
    required this.systemLabel,
    required this.title,
    super.key,
  });

  /// What is selected now.
  final LanguageSelection current;

  /// "System", in the app's current language.
  final String systemLabel;

  /// The sheet's heading.
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.ink,
          ),
        ),
        SizedBox(height: shapes.s3),
        for (final option in LanguageSelection.values)
          LanguageOptionTile(
            option: option,
            label: option.nativeName ?? systemLabel,
            isCurrent: option == current,
          ),
      ],
    );
  }
}

/// One language, rendered in its OWN script and its own face.
///
/// Never transliterated and never rendered in Nunito: the person who needs
/// this row is the one who cannot read the English label for it, and فارسی set
/// in a Latin face is a row they cannot read either.
class LanguageOptionTile extends StatelessWidget {
  /// Creates the tile.
  const LanguageOptionTile({
    required this.option,
    required this.label,
    required this.isCurrent,
    super.key,
  });

  /// Which language.
  final LanguageSelection option;

  /// Its own name, or the translated "System".
  final String label;

  /// Whether it is the current selection.
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final script = option.tag == null
        ? scriptFor(Localizations.localeOf(context))
        : scriptFor(Locale(option.tag!));
    final theme = buildDaybreakTheme(Theme.of(context).brightness, script);

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: shapes.s2),
      child: Material(
        color: isCurrent ? colors.tintPrimary : colors.surface,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(option),
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: shapes.s4,
              vertical: shapes.s3,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
              border: Border.all(
                color: isCurrent ? colors.primaryDeep : colors.border,
                width: shapes.hairlineWidth,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    // The option's OWN script's face, whatever the app is
                    // currently rendering in.
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                      color: colors.ink,
                    ),
                    textDirection: script == DaybreakScript.perso
                        ? ui.TextDirection.rtl
                        : ui.TextDirection.ltr,
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.check, size: 20, color: colors.primaryDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Export and import: the two ways a 780-day history leaves or arrives.
class BackupCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const BackupCard({super.key});

  /// Above this text scale the two buttons stop sharing a row.
  ///
  /// Two Persian button labels cannot fit side by side, and neither can two
  /// German ones.
  static const double stackAboveTextScale = 1.3;

  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

/// Which of the card's two operations is running.
enum _Running {
  /// Neither.
  none,

  /// Writing and sharing a backup.
  exporting,

  /// Choosing a file, confirming, and replacing everything.
  importing,
}

class _BackupCardState extends ConsumerState<BackupCard> {
  _Running _running = _Running.none;
  String? _notice;

  /// Each button's own bounds, for the iPad popover anchor.
  ///
  /// Two keys, not one: the guard's "back up first" is reached from Import, so
  /// anchoring its share sheet to the Export button puts the popover's arrow
  /// on a control the reader did not press.
  final GlobalKey _exportKey = GlobalKey();
  final GlobalKey _importKey = GlobalKey();

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    // Read BEFORE the await: by the time the file is written the button may
    // have been rebuilt, and `findRenderObject` on a dead element throws.
    final anchor = originRectOf(_exportKey.currentContext ?? context);
    setState(() {
      _running = _Running.exporting;
      _notice = null;
    });

    final result = await exportAndShareBackup(
      ref,
      subject: l10n.settingsBackupSubject,
      originRect: anchor,
    );

    if (!mounted) return;
    setState(() {
      _running = _Running.none;
      // The typed failure's own message, never `e.toString()`. Every branch
      // here names what did NOT happen, because "failed" on its own reads as
      // "your history is gone" to somebody two years into a taper.
      _notice = result is Ok ? null : l10n.settingsBackupFailed;
    });
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final anchor = originRectOf(_importKey.currentContext ?? context);
    setState(() {
      _running = _Running.importing;
      _notice = null;
    });

    final picked = await ref.read(filePickerGatewayProvider).pickBackupFile();
    if (!mounted) return;
    switch (picked) {
      // Changing your mind is not an error, and a message for a dismissal
      // teaches somebody that the app complains when they touch it.
      case Err<File, PickFailure>(failure: PickCancelled()):
        setState(() => _running = _Running.none);
        return;
      case Err<File, PickFailure>():
        setState(() {
          _running = _Running.none;
          _notice = l10n.settingsRestoreFailed;
        });
        return;
      case Ok<File, PickFailure>(:final value):
        // Idle again while the sheet is up. The sheet IS the progress signal,
        // and a spinner behind a modal is an animation nobody can see that
        // stops `pumpAndSettle` ever returning.
        setState(() => _running = _Running.none);
        await _confirmThenRestore(l10n, value, anchor);
    }
  }

  /// The confirmation, then the replacement — SPEC §5.3's guard around the one
  /// operation in this app that can lose two years.
  Future<void> _confirmThenRestore(
    AppLocalizations l10n,
    File file,
    Rect anchor,
  ) async {
    Result<void, Failure>? restored;
    final outcome = await showExportGuard(
      context: context,
      request: ConfirmRequest(
        title: l10n.settingsRestoreConfirmTitle,
        body: l10n.settingsRestoreConfirmBody,
        confirmLabel: l10n.settingsRestoreConfirmAction,
        cancelLabel: l10n.actionCancel,
      ),
      exportLabel: l10n.settingsRestoreExportFirst,
      onExport: () {
        setState(() => _running = _Running.exporting);
        return exportAndShareBackup(
          ref,
          subject: l10n.settingsBackupSubject,
          originRect: anchor,
        );
      },
      onConfirmed: () async {
        setState(() => _running = _Running.importing);
        restored = await ref.read(backupRestoreProvider)(file);
        if (restored is! Ok) return;
        // The OS is still holding notifications armed from the PRE-restore
        // plan, and the restored settings may have the reminder off or at a
        // different hour. Reconcile cancels before it schedules, so this is
        // the one call that makes both true again.
        await ref.read(reconcileNotificationsProvider)();
      },
    );

    if (!mounted) return;
    setState(() {
      _running = _Running.none;
      _notice = switch (outcome) {
        ExportGuardOutcome.cancelled => null,
        // Nothing was replaced. That is the guard working, and it is the more
        // important half of the sentence.
        ExportGuardOutcome.exportFailed => l10n.settingsBackupFailed,
        ExportGuardOutcome.exportedThenDestroyed ||
        ExportGuardOutcome.destroyedWithoutBackup =>
          restored is Ok
              ? l10n.settingsRestoreDone
              : l10n.settingsRestoreFailed,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >
        BackupCard.stackAboveTextScale;
    final idle = _running == _Running.none;

    final exportButton = SecondaryButton(
      key: _exportKey,
      label: l10n.settingsExport,
      expand: true,
      busy: _running == _Running.exporting,
      // Disabled while the OTHER one runs, and busy while this one does. Two
      // concurrent writes to the same working directory is a file racing
      // itself; a disabled button says so without a barrier over the app.
      onPressed: idle ? _export : null,
    );
    final importButton = SecondaryButton(
      key: _importKey,
      label: l10n.settingsImport,
      expand: true,
      busy: _running == _Running.importing,
      onPressed: idle ? _import : null,
    );

    return DaybreakCard(
      overline: l10n.settingsBackup,
      overlineCaps: l10n.settingsBackupCaps,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.all(shapes.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    exportButton,
                    SizedBox(height: shapes.s2),
                    importButton,
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      Expanded(child: exportButton),
                      SizedBox(width: shapes.s3),
                      Expanded(child: importButton),
                    ],
                  ),
                ),
              SizedBox(height: shapes.s3),
              Text(
                _notice ?? l10n.settingsBackupNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _notice == null ? colors.inkMuted : colors.warning,
                ),
              ),
              SizedBox(height: shapes.s2),
              // Said where the reader can see it, not only in a policy
              // document: SPEC §5.3's honesty rule, and the claim the store
              // privacy copy rests on.
              Text(
                l10n.settingsBackupPlainText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Name, version, the disclaimer again, and the licences.
class AboutCard extends ConsumerWidget {
  /// Creates the card.
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // A build-time constant, generated from `pubspec.yaml`. Reading it back
    // off the platform would cost `package_info_plus`, which pulls
    // `package:http` into the binary of an app whose whole premise is that it
    // has no network path.
    const version = kAppVersionLabel;

    return DaybreakCard(
      overline: l10n.settingsAbout,
      overlineCaps: l10n.settingsAboutCaps,
      padding: EdgeInsets.zero,
      children: <Widget>[
        SettingsRow(
          glyph: Icons.medication_outlined,
          title: l10n.appTitle,
          sublabel: l10n.settingsAppDescription,
        ),
        const SettingsDivider(),
        SettingsRow(
          glyph: Icons.info_outline,
          title: l10n.settingsVersion,
          sublabel: version,
          semanticsLabel: '${l10n.settingsVersion} $version',
          // Long-press to copy: it is the first thing somebody has to read out
          // when they report a lost plan, and reading a build number aloud
          // over the phone is how it gets written down wrong.
          onTap: () async {
            await Clipboard.setData(const ClipboardData(text: version));
            if (!context.mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(l10n.settingsVersionCopied)),
            );
          },
        ),
        const SettingsDivider(),
        SettingsRow(
          glyph: Icons.warning_amber_outlined,
          title: l10n.settingsReadDisclaimer,
          trailing: Icon(
            Icons.adaptive.arrow_forward,
            size: 20,
            color: DaybreakColors.of(context).inkMuted,
          ),
          onTap: () => context.push(Routes.disclaimerReread),
        ),
        const SettingsDivider(),
        SettingsRow(
          glyph: Icons.description_outlined,
          title: l10n.settingsViewLicenses,
          trailing: Icon(
            Icons.adaptive.arrow_forward,
            size: 20,
            color: DaybreakColors.of(context).inkMuted,
          ),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appTitle,
            applicationVersion: version,
            // Flutter's own page, under THIS app's theme and direction rather
            // than bare Material — EPIC-02's OFL registration for Nunito and
            // Vazirmatn is verified through it.
            useRootNavigator: true,
          ),
        ),
      ],
    );
  }
}

/// "Everything stays on this phone."
class PrivacyFootnote extends StatelessWidget {
  /// Creates the footnote.
  const PrivacyFootnote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Semantics(
      container: true,
      label: l10n.welcomeOffline,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: shapes.s2,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 18, color: colors.success),
            Text(
              l10n.welcomeOffline,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
