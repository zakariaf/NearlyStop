import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ckb.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ckb'),
    Locale('de'),
    Locale('fa'),
  ];

  /// The application name. A product name — never translated, in any locale.
  ///
  /// In en, this message translates to:
  /// **'NearlyStop'**
  String get appTitle;

  /// Heading of the first screen a new user sees.
  ///
  /// In en, this message translates to:
  /// **'Welcome to NearlyStop'**
  String get welcomeTitle;

  /// The medical disclaimer, shown once before the app can be used and again from Settings. It must be unambiguous that the app never recommends a dose.
  ///
  /// In en, this message translates to:
  /// **'NearlyStop arranges the plan you and your doctor agreed. It does not give medical advice. Always follow your doctor\'s instructions.'**
  String get welcomeDisclaimer;

  /// The single button that dismisses the disclaimer.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get welcomeAccept;

  /// Reassurance under the disclaimer. The app makes no network calls at all.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone. No account, no internet.'**
  String get welcomeOffline;

  /// Bottom navigation label for the home screen. Slot: .tab in design/daybreak-screens.html — 390px frame, 8px tabbar padding each side, five flex:1 tabs, so ~74.8px, and the label renders at --fs-caption 14px.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// Bottom navigation label for the block list. Same .tab slot as tabToday.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// Bottom navigation label for the statistics screen. Same .tab slot as tabToday.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tabProgress;

  /// Bottom navigation label for the taper plan form. Same .tab slot as tabToday.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// Bottom navigation label for app settings. Same .tab slot as tabToday.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// A dose with its unit. The number arrives already formatted for the locale, so this string must not reformat it.
  ///
  /// In en, this message translates to:
  /// **'{dose}mg'**
  String doseWithUnit(String dose);

  /// The milligram unit on its own, beside the large dose numeral.
  ///
  /// In en, this message translates to:
  /// **'mg'**
  String get milligramUnit;

  /// Badge on a day that takes the reduced dose.
  ///
  /// In en, this message translates to:
  /// **'New dose day'**
  String get stateNewDoseDay;

  /// The day-state word on a schedule row for today. Separate from `tabToday` even though English spells them the same: one names a tab, the other is one of four state words read as a sentence by a screen reader, and a locale is free to want different words.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get stateToday;

  /// A day whose dose was recorded as taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get stateTaken;

  /// A past day with no dose recorded. Deliberately not 'missed' — the app does not accuse.
  ///
  /// In en, this message translates to:
  /// **'Not ticked'**
  String get stateNotTicked;

  /// Section heading for days that have not happened yet.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get stateUpcoming;

  /// The primary button on Today. Records the planned dose as taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get actionTaken;

  /// Opens the note field for the day.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get actionAddNote;

  /// Stay on the current block for a few more days.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get actionHold;

  /// Record a flare and go back to the last dose that worked.
  ///
  /// In en, this message translates to:
  /// **'Flare'**
  String get actionFlare;

  /// Begin the next reduction. Enabled only when the current step is complete.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get actionNextStep;

  /// Which reduction the patient is on, out of the plan's total.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOfTotal(int current, int total);

  /// Position within the current 52-day step. Deliberately not a week number — the pattern ignores that a week has seven days.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {length}'**
  String dayOfStep(int day, int length);

  /// Which of the eleven blocks of the pattern this is.
  ///
  /// In en, this message translates to:
  /// **'Block {current} of {total}'**
  String blockOfTotal(int current, int total);

  /// The word on a finished block header. Said as a WORD, not only as a green tint: a reader who cannot see the tint still has to know the block is behind them.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get blockCompleted;

  /// The teaching sentence under a block header: the new dose is taken on one day, the old dose on the days between. Word order differs per language, so the counts are ICU branches rather than spliced numbers.
  ///
  /// In en, this message translates to:
  /// **'one day at {newDose}, then {oldDays, plural, =1{1 day} other{{oldDays} days}} at {oldDose}'**
  String blockPattern(String newDose, int oldDays, String oldDose);

  /// The step's reduction, read aloud and shown in the context line.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String doseTransition(String from, String to);

  /// The tablets that make up a dose, e.g. '1 x 5mg . 4 x 1mg'. The value is a Latin-script run inside a possibly right-to-left sentence and arrives already bidi-isolated; this message must not add punctuation around it.
  ///
  /// In en, this message translates to:
  /// **'{parts}'**
  String tabletBreakdown(String parts);

  /// Offered on Today when the previous day has no record. A question, never a reprimand.
  ///
  /// In en, this message translates to:
  /// **'Yesterday wasn\'t ticked — mark it now?'**
  String get yesterdayNotTicked;

  /// How many days have been recorded as taken.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day taken} other{{count} days taken}}'**
  String takenDays(int count);

  /// Total days since the plan started, with the medicine's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day on {medicine}} other{{count} days on {medicine}}}'**
  String daysOnMedicine(int count, String medicine);

  /// Sits under the adherence figure. The taper's outcome does not turn on a handful of missed ticks, and the audience needs to be told so.
  ///
  /// In en, this message translates to:
  /// **'days ticked so far — a few gaps change nothing'**
  String get adherenceReassurance;

  /// Caption under the cumulative milligram total.
  ///
  /// In en, this message translates to:
  /// **'taken in total'**
  String get totalTaken;

  /// The headline on Progress: how far the dose has come down.
  ///
  /// In en, this message translates to:
  /// **'You are {amount} lower than when you started.'**
  String lowerThanStart(String amount);

  /// How many flares are marked on the dose chart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 flare recorded} other{{count} flares recorded}}'**
  String flaresRecorded(int count);

  /// Heading above the dose chart.
  ///
  /// In en, this message translates to:
  /// **'Your dose over time'**
  String get doseOverTime;

  /// When the plan began and at what dose.
  ///
  /// In en, this message translates to:
  /// **'Started {date} at {dose}'**
  String startedAt(String date, String dose);

  /// Days ticked out of days elapsed.
  ///
  /// In en, this message translates to:
  /// **'{taken} of {total}'**
  String adherenceRatio(String taken, String total);

  /// Field label for the drug name. Free text — never looked up in a drug database.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get planMedicine;

  /// Field label for the dose the patient is on now.
  ///
  /// In en, this message translates to:
  /// **'Current dose'**
  String get planCurrentDose;

  /// Field label for the dose the plan aims at, usually zero.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get planTarget;

  /// Field label for the tablet strengths the patient actually has.
  ///
  /// In en, this message translates to:
  /// **'Tablet strengths held'**
  String get planStrengths;

  /// Toggle: whether half tablets may appear in a dose.
  ///
  /// In en, this message translates to:
  /// **'I can split tablets'**
  String get planAllowHalves;

  /// Field label for which taper arithmetic the plan uses.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get planMethod;

  /// The community DSNS method. A proper name — keep the sense of 'very slowly, almost stopping'.
  ///
  /// In en, this message translates to:
  /// **'Dead Slow and Nearly Stop'**
  String get methodDsns;

  /// Reduce by a percentage of the current dose each step.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get methodPercentage;

  /// Reduce by a fixed number of milligrams each step.
  ///
  /// In en, this message translates to:
  /// **'Fixed mg'**
  String get methodFixed;

  /// The step size the app worked out. It is a suggestion the clinician overrides, never an instruction.
  ///
  /// In en, this message translates to:
  /// **'suggested step {amount}'**
  String suggestedStep(String amount);

  /// Shown under the percentage field. The final clause is the point: the app arranges, the clinician decides.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of {dose} is {result} — your doctor\'s instruction wins'**
  String percentageExplainer(String percent, String dose, String result);

  /// Row label for the morning notification.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get settingsReminder;

  /// Row label for the in-app text scale, on top of the OS setting.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// Row label for the high-contrast palette.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get settingsHighContrast;

  /// Section heading for export and import.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// Write a backup file the user keeps themselves.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get settingsExport;

  /// A printable summary to take to an appointment.
  ///
  /// In en, this message translates to:
  /// **'Export for my doctor'**
  String get settingsExportForDoctor;

  /// Restore from a backup file.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get settingsImport;

  /// Reopens the welcome disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Read the disclaimer again'**
  String get settingsReadDisclaimer;

  /// Accessible name for the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Accessible name for the light/dark picker.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// A setting that is enabled.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get toggleOn;

  /// A setting that is disabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get toggleOff;

  /// The larger of the text-size choices.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// The light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// The dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// SPEC 5.4. What a screen reader announces on the Today screen before the dose is recorded. A semantics label is a user-facing string like any other, so it is translated rather than composed in code.
  ///
  /// In en, this message translates to:
  /// **'Today, {dose} milligrams: {breakdown}. Not yet taken.'**
  String todaySemantics(String dose, String breakdown);

  /// The same announcement once the dose has been recorded.
  ///
  /// In en, this message translates to:
  /// **'Today, {dose} milligrams: {breakdown}. Taken.'**
  String todaySemanticsTaken(String dose, String breakdown);

  /// Weekday names, Monday first, pipe-separated. Only the ckb translation is ever read: `intl` ships no ckb date symbols, so Kurdish dates are composed from these lists rather than from DateFormat. The other locales carry it only to keep every ARB key-identical.
  ///
  /// In en, this message translates to:
  /// **'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday'**
  String get ckbWeekdayNames;

  /// Gregorian month names, January first, pipe-separated. See ckbWeekdayNames — read only for ckb.
  ///
  /// In en, this message translates to:
  /// **'January|February|March|April|May|June|July|August|September|October|November|December'**
  String get ckbMonthNames;

  /// Shown when a link or a restored location points nowhere. Warm and short — never the framework's red error screen.
  ///
  /// In en, this message translates to:
  /// **'That page does not exist'**
  String get unknownRouteTitle;

  /// The single way out of the unknown-route page.
  ///
  /// In en, this message translates to:
  /// **'Go to Today'**
  String get unknownRouteAction;

  /// A persistent banner in the shell when the LAUNCH could not read the settings row. Persistent, never a toast: this audience does not finish reading a message that times out. It must not claim anything about the taper plan — this state is specifically about settings, and an earlier wording said "your plan is safe" in the one case where that was not knowable.
  ///
  /// In en, this message translates to:
  /// **'Your settings could not be loaded, so the app is using its defaults.'**
  String get shellStorageError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ckb', 'de', 'en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ckb':
      return AppLocalizationsCkb();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
