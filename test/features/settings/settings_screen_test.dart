// The Settings screen: the promises, and the controls that keep them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/settings/presentation/widgets/settings_cards.dart';
import 'package:nearlystop/features/settings/presentation/widgets/settings_rows.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  /// The localizations the pumped screen is using.
  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SettingsScreen)));

  final info = PackageInfo(
    appName: 'NearlyStop',
    packageName: 'com.buzzjective.nearlystop',
    version: '1.0.0',
    buildNumber: '7',
  );

  Future<AppLocalizations> pumpSettings(
    WidgetTester tester, {
    AppSettings settings = AppSettings.defaults,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size size = const Size(390, 900),
  }) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        settingsControllerProvider.overrideWith(() => _Fixed(settings)),
        packageInfoProvider.overrideWith((ref) => info),
      ],
      locale: locale,
      textScaler: textScaler,
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('every row clears 44, and every switch reads as a sentence', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSettings(tester);

    for (final row in tester.widgetList<SettingsRow>(
      find.byType(SettingsRow),
    )) {
      expect(
        tester.getSize(find.byWidget(row)).height,
        greaterThanOrEqualTo(44),
        reason: row.title,
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the language picker names every option in its OWN script', (
    tester,
  ) async {
    // The person who needs this row is the one who cannot read the English
    // label for it. Transliterating "Persian" helps nobody.
    final l10n = await pumpSettings(tester);

    await tester.tap(find.byKey(LanguageCard.rowKey));
    await tester.pumpAndSettle();

    // Twice: the row's own sublabel says it too, which is the point of a
    // sublabel.
    expect(find.text(l10n.settingsSystemLanguage), findsNWidgets(2));
    for (final name in <String>[
      'English',
      'Deutsch',
      'فارسی',
      'کوردیی ناوەندی',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('فارسی is rendered in Vazirmatn, not in Nunito', (tester) async {
    // Persian set in a Latin face is a row a Persian reader cannot read.
    await pumpSettings(tester);
    await tester.tap(find.byKey(LanguageCard.rowKey));
    await tester.pumpAndSettle();

    final persian = tester.widget<Text>(find.text('فارسی'));
    final latin = tester.widget<Text>(find.text('English'));
    expect(persian.style?.fontFamily, isNot(latin.style?.fontFamily));
    expect(persian.style?.fontFamily, contains('Vazirmatn'));
  });

  testWidgets('choosing a language writes its tag, exactly once', (
    tester,
  ) async {
    await pumpSettings(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final controller =
        container.read(settingsControllerProvider.notifier) as _Fixed;

    await tester.tap(find.byKey(LanguageCard.rowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فارسی'));
    await tester.pumpAndSettle();

    expect(controller.localeWrites, <String?>['fa']);
  });

  testWidgets('dismissing the language sheet writes NOTHING', (tester) async {
    await pumpSettings(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final controller =
        container.read(settingsControllerProvider.notifier) as _Fixed;

    await tester.tap(find.byKey(LanguageCard.rowKey));
    await tester.pumpAndSettle();
    // Tap the scrim.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(controller.localeWrites, isEmpty);
  });

  testWidgets('the reminder row says OFF until it is on', (tester) async {
    final l10n = await pumpSettings(tester);
    expect(find.text(l10n.settingsOff), findsWidgets);

    // A fresh scope. `pumpWidget` REUSES a `ProviderScope` of the same type,
    // so re-pumping with a different override keeps the old controller and
    // this test would assert against the first settings row twice.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSettings(
      tester,
      settings: const AppSettings(
        themeMode: AppThemeMode.system,
        textScale: 1,
        highContrast: false,
        reminderEnabled: true,
        reminderMinuteOfDay: 480,
      ),
    );
    expect(find.textContaining('8:00'), findsOneWidget);
  });

  testWidgets('dismissing the TIME picker writes nothing either', (
    tester,
  ) async {
    // The row is the reader's alarm. A cancelled dialog that still moved it is
    // worse than no picker at all — they would find out at the wrong hour.
    await pumpSettings(
      tester,
      settings: const AppSettings(
        themeMode: AppThemeMode.system,
        textScale: 1,
        highContrast: false,
        reminderEnabled: true,
        reminderMinuteOfDay: 480,
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final controller =
        container.read(settingsControllerProvider.notifier) as _Fixed;

    await tester.tap(find.text(l10nOf(tester).settingsReminder));
    await tester.pumpAndSettle();
    // The picker's own Cancel, from Material's localizations rather than the
    // app's — it is Material's dialog.
    await tester.tap(
      find.text(
        MaterialLocalizations.of(
          tester.element(find.byType(SettingsScreen)),
        ).cancelButtonLabel,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.minuteWrites, isEmpty);
  });

  testWidgets('backup says what it is rather than sitting disabled', (
    tester,
  ) async {
    // EPIC-13 has not landed. A control that looks broken is worse than one
    // that explains itself.
    final l10n = await pumpSettings(tester);
    final export = find.widgetWithText(SecondaryButton, l10n.settingsExport);

    expect(tester.widget<SecondaryButton>(export).onPressed, isNotNull);
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsNotImplemented), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the two backup buttons stop sharing a row above 1.3', (
    tester,
  ) async {
    await pumpSettings(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    double topOf(String label) =>
        tester.getTopLeft(find.widgetWithText(SecondaryButton, label)).dy;
    expect(topOf(l10n.settingsExport), topOf(l10n.settingsImport));

    await pumpSettings(
      tester,
      textScaler: const TextScaler.linear(1.4),
      size: const Size(390, 1600),
    );
    expect(
      topOf(l10n.settingsExport),
      lessThan(topOf(l10n.settingsImport)),
      reason: 'two Persian button labels cannot share a row',
    );
  });

  testWidgets('About shows a real version, as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = await pumpSettings(tester);

    expect(find.text('1.0.0 (7)'), findsOneWidget);
    expect(
      find.bySemanticsLabel('${l10n.settingsVersion} 1.0.0 (7)'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the privacy footnote is the app’s whole positioning', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    // Scrolled to: it is the last thing on a long page, which is where a
    // sceptical reader goes looking for it.
    await tester.scrollUntilVisible(find.text(l10n.welcomeOffline), 200);

    expect(find.text(l10n.welcomeOffline), findsOneWidget);
  });
}

/// A controller that records what it was asked to write.
final class _Fixed extends SettingsController {
  _Fixed(this._settings);

  final AppSettings _settings;

  /// Every locale tag written, in order.
  final List<String?> localeWrites = <String?>[];

  /// Every reminder minute written, in order.
  final List<int?> minuteWrites = <int?>[];

  @override
  AppSettings build() => _settings;

  @override
  Future<Result<void, StorageFailure>> setLocaleTag(String? tag) async {
    localeWrites.add(tag);
    return const Ok(null);
  }

  @override
  Future<Result<void, StorageFailure>> setReminderMinuteOfDay(
    int? minute,
  ) async {
    minuteWrites.add(minute);
    return const Ok(null);
  }
}
