// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NearlyStop';

  @override
  String get welcomeTitle => 'Welcome to NearlyStop';

  @override
  String get welcomeDisclaimer =>
      'NearlyStop arranges the plan you and your doctor agreed. It does not give medical advice. Always follow your doctor\'s instructions.';

  @override
  String get welcomeAccept => 'I understand';

  @override
  String get welcomeOffline =>
      'Everything stays on this phone. No account, no internet.';

  @override
  String get tabToday => 'Today';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabSettings => 'Settings';

  @override
  String doseWithUnit(String dose) {
    return '${dose}mg';
  }

  @override
  String get milligramUnit => 'mg';

  @override
  String get stateNewDoseDay => 'New dose day';

  @override
  String get stateTaken => 'Taken';

  @override
  String get stateNotTicked => 'Not ticked';

  @override
  String get stateUpcoming => 'Upcoming';

  @override
  String get actionTaken => 'Taken';

  @override
  String get actionAddNote => 'Add note';

  @override
  String get actionHold => 'Hold';

  @override
  String get actionFlare => 'Flare';

  @override
  String get actionNextStep => 'Next step';

  @override
  String stepOfTotal(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String dayOfStep(int day, int length) {
    return 'Day $day of $length';
  }

  @override
  String blockOfTotal(int current, int total) {
    return 'Block $current of $total';
  }

  @override
  String blockPattern(String newDose, int oldDays, String oldDose) {
    String _temp0 = intl.Intl.pluralLogic(
      oldDays,
      locale: localeName,
      other: '$oldDays days',
      one: '1 day',
    );
    return 'one day at $newDose, then $_temp0 at $oldDose';
  }

  @override
  String doseTransition(String from, String to) {
    return '$from to $to';
  }

  @override
  String tabletBreakdown(String parts) {
    return '$parts';
  }

  @override
  String get yesterdayNotTicked => 'Yesterday wasn\'t ticked — mark it now?';

  @override
  String takenDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days taken',
      one: '1 day taken',
    );
    return '$_temp0';
  }

  @override
  String daysOnMedicine(int count, String medicine) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days on $medicine',
      one: '1 day on $medicine',
    );
    return '$_temp0';
  }

  @override
  String get adherenceReassurance =>
      'days ticked so far — a few gaps change nothing';

  @override
  String get totalTaken => 'taken in total';

  @override
  String lowerThanStart(String amount) {
    return 'You are $amount lower than when you started.';
  }

  @override
  String flaresRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flares recorded',
      one: '1 flare recorded',
    );
    return '$_temp0';
  }

  @override
  String get doseOverTime => 'Your dose over time';

  @override
  String startedAt(String date, String dose) {
    return 'Started $date at $dose';
  }

  @override
  String adherenceRatio(String taken, String total) {
    return '$taken of $total';
  }

  @override
  String get planMedicine => 'Medicine';

  @override
  String get planCurrentDose => 'Current dose';

  @override
  String get planTarget => 'Target';

  @override
  String get planStrengths => 'Tablet strengths held';

  @override
  String get planAllowHalves => 'I can split tablets';

  @override
  String get planMethod => 'Method';

  @override
  String get methodDsns => 'Dead Slow and Nearly Stop';

  @override
  String get methodPercentage => 'Percentage';

  @override
  String get methodFixed => 'Fixed mg';

  @override
  String suggestedStep(String amount) {
    return 'suggested step $amount';
  }

  @override
  String percentageExplainer(String percent, String dose, String result) {
    return '$percent% of $dose is $result — your doctor\'s instruction wins';
  }

  @override
  String get settingsReminder => 'Daily reminder';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsExport => 'Export data';

  @override
  String get settingsExportForDoctor => 'Export for my doctor';

  @override
  String get settingsImport => 'Import data';

  @override
  String get settingsReadDisclaimer => 'Read the disclaimer again';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get toggleOn => 'On';

  @override
  String get toggleOff => 'Off';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String todaySemantics(String dose, String breakdown) {
    return 'Today, $dose milligrams: $breakdown. Not yet taken.';
  }

  @override
  String todaySemanticsTaken(String dose, String breakdown) {
    return 'Today, $dose milligrams: $breakdown. Taken.';
  }

  @override
  String get ckbWeekdayNames =>
      'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday';

  @override
  String get ckbMonthNames =>
      'January|February|March|April|May|June|July|August|September|October|November|December';
}
