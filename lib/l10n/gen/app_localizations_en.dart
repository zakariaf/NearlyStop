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
  String get stateToday => 'Today';

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
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionUndo => 'Undo';

  @override
  String get stateUnavailable => 'Unavailable';

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
  String get blockCompleted => 'Completed';

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

  @override
  String get unknownRouteTitle => 'That page does not exist';

  @override
  String get unknownRouteAction => 'Go to Today';

  @override
  String get shellStorageError =>
      'Your settings could not be loaded, so the app is using its defaults.';

  @override
  String doseNotAchievable(Object dose) {
    return 'Cannot be made from the tablets you hold: ${dose}mg';
  }

  @override
  String holdingAtDose(Object dose) {
    return 'Holding at $dose';
  }

  @override
  String nDaysNotTicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You haven’t marked the last $count days',
      one: 'Yesterday wasn’t ticked',
    );
    return '$_temp0';
  }

  @override
  String get stepFinishedExplainer =>
      'This step’s days are done. Your dose stays here until you start the next one.';

  @override
  String get startNextStep => 'Start next step';

  @override
  String get holdNeedsActiveStep => 'There is no step running to hold';

  @override
  String get markTaken => 'Mark as taken';

  @override
  String takenAt(Object time) {
    return 'Taken at $time';
  }

  @override
  String get markedAsTaken => 'Marked as taken';

  @override
  String contextLineSemantics(
    Object step,
    Object total,
    Object from,
    Object to,
    Object day,
    Object length,
  ) {
    return 'Step $step of $total, reducing from $from to $to, day $day of $length';
  }

  @override
  String todaySemanticsNewDose(Object dose, Object breakdown) {
    return 'Today, $dose milligrams: $breakdown. New dose day. Not yet taken.';
  }

  @override
  String get flareTitle => 'Record a flare';

  @override
  String get flarePickDose => 'Go back to a dose that worked';

  @override
  String get flareHistoryKept =>
      'Your history and your total so far are kept. Days from today are rebuilt from this dose.';

  @override
  String get flareConfirm => 'Record flare';

  @override
  String flareDateRange(Object dose, Object from, Object to) {
    return '$dose — from $from to $to';
  }

  @override
  String get flareNoHistory =>
      'You have not finished a step yet, so there is no earlier dose to go back to.';

  @override
  String get holdTitle => 'Hold at this dose';

  @override
  String get holdExtraDays => 'Extra days';

  @override
  String holdConsequence(Object dose, Object days) {
    return 'You stay at $dose for $days more days. The step is not abandoned and nothing is lost.';
  }

  @override
  String get holdConfirm => 'Hold';

  @override
  String get noteTitle => 'Note for today';

  @override
  String get noteHint => 'How did today go?';

  @override
  String get noteSave => 'Save note';

  @override
  String get taperCompleteTitle => 'You reached your target';

  @override
  String get taperCompleteBody =>
      'Your taper is finished. Keep following your doctor’s instructions.';

  @override
  String get noPlanHeading => 'Your plan starts here';

  @override
  String get noPlanBody =>
      'Add the plan you and your doctor agreed, and this screen will show what to take each morning.';

  @override
  String get noPlanAction => 'Set up my plan';

  @override
  String get errorTitle => 'Something went wrong reading your plan';

  @override
  String get errorRetry => 'Try again';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get backfillAction => 'Mark them now';

  @override
  String blockSummary(
    int leadCount,
    Object leadDose,
    int restCount,
    Object restDose,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      leadCount,
      locale: localeName,
      other: '$leadCount days at $leadDose',
      one: 'one day at $leadDose',
    );
    String _temp1 = intl.Intl.pluralLogic(
      restCount,
      locale: localeName,
      other: '$restCount days at $restDose',
      one: '1 day at $restDose',
    );
    return '$_temp0, then $_temp1';
  }

  @override
  String steadyStateTitle(Object dose) {
    return 'Holding at $dose';
  }

  @override
  String get held => 'Held';

  @override
  String heldAtBlock(int block) {
    return 'Held at block $block';
  }

  @override
  String get pastStepReadOnly => 'This step is finished and cannot be changed';

  @override
  String get jumpToToday => 'Jump to today';

  @override
  String get futureDayNotYet =>
      'You cannot mark a day that has not happened yet';

  @override
  String get stepSwitcherTitle => 'Choose a step';

  @override
  String stepRangeLabel(int index, int total, Object from, Object to) {
    return 'Step $index of $total — $from to $to';
  }

  @override
  String scheduleDaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return '$day, $dose milligrams: $breakdown.$notes';
  }

  @override
  String get scheduleNoteNewDose => ' New dose day.';

  @override
  String scheduleNoteHeld(int block) {
    return ' Held, an extra day in block $block.';
  }

  @override
  String get scheduleNoteHeldNoBlock => ' Held, an extra day.';

  @override
  String scheduleNoteState(Object state) {
    return ' $state.';
  }

  @override
  String get scheduleNoteUnachievable =>
      ' This dose cannot be made from the tablets you hold.';

  @override
  String scheduleTodaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return 'Today. $day, $dose milligrams: $breakdown.$notes';
  }

  @override
  String get tabletSeparator => ', ';
}
