/// The six surfaces, built the one way every whole-app sweep builds them.
///
/// **One list, three consumers.** The overflow matrix, the grayscale pass and
/// the end-of-build screenshot sweep all walk this. Three private copies is
/// three fixtures that drift, and the whole point of pinning one plan is that
/// a matrix cell and a parity sheet show the same taper.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:nearlystop/features/progress/presentation/progress_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;

import '../fixtures/seeded_plan.dart';
import '../support/harness.dart';

/// One surface under sweep.
typedef AppScreen = ({
  /// The name a failing cell prints.
  String name,

  /// Builds the widget under the harness's `MaterialApp`.
  Widget Function(AppLocalizations l10n) build,

  /// What it needs overridden, for the locale being swept.
  List<Override> Function(Locale locale) overrides,
});

/// The six, in the order the reference sheets number them.
///
/// Every one of them renders the SEEDED plan through the real notifiers —
/// snapshot in, screen out — rather than a hand-built view state. A matrix
/// over hand-built states proves the widgets lay out; this one proves the app
/// does.
List<AppScreen> appScreens() => <AppScreen>[
  (
    name: 'Welcome',
    build: (l10n) => Scaffold(
      body: SafeArea(
        child: DisclaimerSheet(
          title: l10n.welcomeTitle,
          body: '${l10n.welcomeDisclaimer}\n\n${l10n.welcomeOffline}',
          actionLabel: l10n.welcomeAccept,
          isGate: true,
          onAccept: () {},
          onClose: () {},
        ),
      ),
    ),
    overrides: (_) => const <Override>[],
  ),
  (
    name: 'Today',
    build: (_) => const TodayScreen(),
    overrides: (locale) => seededScreenOverrides(
      l10n: lookupAppLocalizations(locale),
      locale: locale,
    ),
  ),
  (
    name: 'Schedule',
    build: (_) => const ScheduleScreen(),
    overrides: (locale) => seededScreenOverrides(
      l10n: lookupAppLocalizations(locale),
      locale: locale,
    ),
  ),
  (
    name: 'Progress',
    build: (_) => const ProgressScreen(),
    overrides: (locale) => seededScreenOverrides(
      l10n: lookupAppLocalizations(locale),
      locale: locale,
    ),
  ),
  (
    name: 'Plan',
    build: (_) => const PlanScreen(),
    overrides: (locale) => seededPlanOverrides(locale: locale),
  ),
  (
    name: 'Settings',
    build: (_) => const SettingsScreen(),
    overrides: (locale) => <Override>[
      ...seededPlanOverrides(locale: locale),
      settingsControllerProvider.overrideWith(FixedSettingsController.seeded),
    ],
  ),
];
