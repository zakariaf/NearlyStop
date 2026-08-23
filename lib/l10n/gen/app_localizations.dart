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

  /// The cancel action on a confirmation sheet. Cancelling a destructive action is deliberately the easy path.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// The action on the disclaimer sheet when it is opened to be re-read from Settings, rather than as the first-run gate.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// The action on the app’s one undo surface. Never a SnackBar: it times out before this reader finishes it.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// Appended to a disabled control’s SEMANTICS label. A disabled button that only dims is invisible to a screen reader and to anyone with low contrast vision, so the state is said in words as well.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get stateUnavailable;

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

  /// Shown INSTEAD of a tablet breakdown when the dose cannot be built from the strengths held. SPEC.md 3.3 and CLAUDE.md rule 5: flagged, never rounded. The number is the exact dose, unrounded.
  ///
  /// In en, this message translates to:
  /// **'Cannot be made from the tablets you hold: {dose}mg'**
  String doseNotAchievable(Object dose);

  /// The context line on a steady-state day, where there is no "day n of 52" to print because dayInStep is null upstream.
  ///
  /// In en, this message translates to:
  /// **'Holding at {dose}'**
  String holdingAtDose(Object dose);

  /// The backfill banner. The count is the TRAILING RUN of un-ticked past days, not the lifetime total — a ticked day terminates it. Warm, not scolding: a missed day is not a failure (SPEC.md 4.1).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yesterday wasn’t ticked} other{You haven’t marked the last {count} days}}'**
  String nDaysNotTicked(int count);

  /// Day 53. The step is used up and the next has not been started, so the dose holds. Says what is happening rather than showing nothing.
  ///
  /// In en, this message translates to:
  /// **'This step’s days are done. Your dose stays here until you start the next one.'**
  String get stepFinishedExplainer;

  /// The action on a finished step. The reader starts it, never the app.
  ///
  /// In en, this message translates to:
  /// **'Start next step'**
  String get startNextStep;

  /// The DISABLED Hold tile says why. Disabled-with-reason, never hidden: a control that vanishes teaches nothing.
  ///
  /// In en, this message translates to:
  /// **'There is no step running to hold'**
  String get holdNeedsActiveStep;

  /// The 88pt action. The whole daily interaction.
  ///
  /// In en, this message translates to:
  /// **'Mark as taken'**
  String get markTaken;

  /// The taken state. Says WHEN, because the question at 9am is "did I already?" and a tick alone does not answer it.
  ///
  /// In en, this message translates to:
  /// **'Taken at {time}'**
  String takenAt(Object time);

  /// The live-region announcement after a successful write.
  ///
  /// In en, this message translates to:
  /// **'Marked as taken'**
  String get markedAsTaken;

  /// The whole context line as ONE sentence for a screen reader. Six fragments read as six announcements.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}, reducing from {from} to {to}, day {day} of {length}'**
  String contextLineSemantics(
    Object step,
    Object total,
    Object from,
    Object to,
    Object day,
    Object length,
  );

  /// The hero as one sentence on a new-dose day.
  ///
  /// In en, this message translates to:
  /// **'Today, {dose} milligrams: {breakdown}. New dose day. Not yet taken.'**
  String todaySemanticsNewDose(Object dose, Object breakdown);

  /// SPEC.md 5.2. The reader chooses the dose; the app never picks one.
  ///
  /// In en, this message translates to:
  /// **'Record a flare'**
  String get flareTitle;

  /// The picker heading. A JUDGEMENT the person makes, which is why the sheet lists the doses they have actually been on.
  ///
  /// In en, this message translates to:
  /// **'Go back to a dose that worked'**
  String get flarePickDose;

  /// Names exactly what is kept. This reader has spent two years on a taper and needs to know which two years are at risk.
  ///
  /// In en, this message translates to:
  /// **'Your history and your total so far are kept. Days from today are rebuilt from this dose.'**
  String get flareHistoryKept;

  /// The confirm action in the flare sheet.
  ///
  /// In en, this message translates to:
  /// **'Record flare'**
  String get flareConfirm;

  /// One candidate row: the dose and when they were on it.
  ///
  /// In en, this message translates to:
  /// **'{dose} — from {from} to {to}'**
  String flareDateRange(Object dose, Object from, Object to);

  /// Shown when there are no candidates, instead of an empty picker.
  ///
  /// In en, this message translates to:
  /// **'You have not finished a step yet, so there is no earlier dose to go back to.'**
  String get flareNoHistory;

  /// SPEC.md 5.2.
  ///
  /// In en, this message translates to:
  /// **'Hold at this dose'**
  String get holdTitle;

  /// The stepper label, 1–28.
  ///
  /// In en, this message translates to:
  /// **'Extra days'**
  String get holdExtraDays;

  /// Plain language, with the numbers filled in — not "your schedule will be adjusted".
  ///
  /// In en, this message translates to:
  /// **'You stay at {dose} for {days} more days. The step is not abandoned and nothing is lost.'**
  String holdConsequence(Object dose, Object days);

  /// The confirm action in the hold sheet.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get holdConfirm;

  /// One free-text note per day (SPEC.md 8).
  ///
  /// In en, this message translates to:
  /// **'Note for today'**
  String get noteTitle;

  /// The note field placeholder. A question, not "Enter note".
  ///
  /// In en, this message translates to:
  /// **'How did today go?'**
  String get noteHint;

  /// The note sheet confirm.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get noteSave;

  /// SPEC.md 7: the taper ends cleanly. Never a negative dose.
  ///
  /// In en, this message translates to:
  /// **'You reached your target'**
  String get taperCompleteTitle;

  /// The finish card. Still defers to the clinician — the app never recommends a dose, including zero.
  ///
  /// In en, this message translates to:
  /// **'Your taper is finished. Keep following your doctor’s instructions.'**
  String get taperCompleteBody;

  /// Day zero. Warm, never "No data".
  ///
  /// In en, this message translates to:
  /// **'Your plan starts here'**
  String get noPlanHeading;

  /// The empty state sentence.
  ///
  /// In en, this message translates to:
  /// **'Add the plan you and your doctor agreed, and this screen will show what to take each morning.'**
  String get noPlanBody;

  /// The one primary action on the empty state.
  ///
  /// In en, this message translates to:
  /// **'Set up my plan'**
  String get noPlanAction;

  /// The error panel. Says what failed, not a code.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong reading your plan'**
  String get errorTitle;

  /// The retry control on the error panel.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errorRetry;

  /// Dismisses the backfill banner without marking anything.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// The backfill banner action: marks inline for one day, opens the Schedule focused on the oldest for more.
  ///
  /// In en, this message translates to:
  /// **'Mark them now'**
  String get backfillAction;

  /// The block header’s teaching sentence, generated FROM THE BLOCK TABLE and never hardcoded: blocks 7–11 invert, so the OLD dose becomes the single leading day and a summary that always named the new dose first would be wrong for five of the eleven.
  ///
  /// In en, this message translates to:
  /// **'{leadCount, plural, =1{one day at {leadDose}} other{{leadCount} days at {leadDose}}}, then {restCount, plural, =1{1 day at {restDose}} other{{restCount} days at {restDose}}}'**
  String blockSummary(
    int leadCount,
    Object leadDose,
    int restCount,
    Object restDose,
  );

  /// The trailing group for days with no block — after a step’s realised length and after the taper reaches target. Every date the generator emits has to land in some group.
  ///
  /// In en, this message translates to:
  /// **'Holding at {dose}'**
  String steadyStateTitle(Object dose);

  /// The trailing word on a hold day, where the state word sits.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get held;

  /// A hold day repeats its host day’s `dayInStep`, so five held days would otherwise read "day 14 of 52" five times — which looks like a bug on the one screen whose job is making the structure legible.
  ///
  /// In en, this message translates to:
  /// **'Held at block {block}'**
  String heldAtBlock(int block);

  /// A read-only row SAYS so rather than being a dead tap target.
  ///
  /// In en, this message translates to:
  /// **'This step is finished and cannot be changed'**
  String get pastStepReadOnly;

  /// Returns the list to today from anywhere in a 780-day history.
  ///
  /// In en, this message translates to:
  /// **'Jump to today'**
  String get jumpToToday;

  /// Refused with a reason, never a silent no-op.
  ///
  /// In en, this message translates to:
  /// **'You cannot mark a day that has not happened yet'**
  String get futureDayNotYet;

  /// Completed steps are reached through the switcher, not by scrolling a two-year history into them.
  ///
  /// In en, this message translates to:
  /// **'Choose a step'**
  String get stepSwitcherTitle;

  /// One row in the step switcher.
  ///
  /// In en, this message translates to:
  /// **'Step {index} of {total} — {from} to {to}'**
  String stepRangeLabel(int index, int total, Object from, Object to);

  /// One schedule row as one sentence, for the screen reader.
  ///
  /// In en, this message translates to:
  /// **'{day}, {dose} milligrams: {breakdown}.{notes}'**
  String scheduleDaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  );

  /// Clause marking a new-dose day.
  ///
  /// In en, this message translates to:
  /// **' New dose day.'**
  String get scheduleNoteNewDose;

  /// Clause explaining a hold day inside a block.
  ///
  /// In en, this message translates to:
  /// **' Held, an extra day in block {block}.'**
  String scheduleNoteHeld(int block);

  /// Clause explaining a hold day with no block.
  ///
  /// In en, this message translates to:
  /// **' Held, an extra day.'**
  String get scheduleNoteHeldNoBlock;

  /// Clause carrying the day state word.
  ///
  /// In en, this message translates to:
  /// **' {state}.'**
  String scheduleNoteState(Object state);

  /// Clause warning the dose cannot be made.
  ///
  /// In en, this message translates to:
  /// **' This dose cannot be made from the tablets you hold.'**
  String get scheduleNoteUnachievable;

  /// Today's schedule row as one sentence; it says so first.
  ///
  /// In en, this message translates to:
  /// **'Today. {day}, {dose} milligrams: {breakdown}.{notes}'**
  String scheduleTodaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  );

  /// Between tablet groups in the Schedule row's breakdown; U+060C in Perso-Arabic.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get tabletSeparator;
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
