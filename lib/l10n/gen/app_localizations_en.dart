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

  @override
  String get stateTakenCaps => 'TAKEN';

  @override
  String get stateNotTickedCaps => 'NOT TICKED';

  @override
  String get stateTodayCaps => 'TODAY';

  @override
  String get stateUpcomingCaps => 'UPCOMING';

  @override
  String get chartOverline => 'Your dose over time';

  @override
  String daysOnDrugLabel(Object medicine) {
    return 'days on $medicine';
  }

  @override
  String holdsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count holds recorded',
      one: '1 hold recorded',
    );
    return '$_temp0';
  }

  @override
  String flaresAndHoldsRecorded(int flares, int holds) {
    String _temp0 = intl.Intl.pluralLogic(
      flares,
      locale: localeName,
      other: '$flares flares',
      one: '1 flare',
    );
    String _temp1 = intl.Intl.pluralLogic(
      holds,
      locale: localeName,
      other: '$holds holds',
      one: '1 hold',
    );
    return '$_temp0 and $_temp1 recorded';
  }

  @override
  String get noEventsRecorded => 'No flares or holds recorded';

  @override
  String get sameAsStart => 'You are steady at the dose you started on.';

  @override
  String chartSummary(
    Object from,
    Object fromMonth,
    Object to,
    Object toMonth,
    Object events,
  ) {
    return 'Chart: your dose fell from $from milligrams in $fromMonth to $to milligrams in $toMonth$events.';
  }

  @override
  String chartSummaryEvents(Object events) {
    return ', with $events';
  }

  @override
  String get doseHistoryTitle => 'Dose history as a list';

  @override
  String historySegmentRow(Object dose, Object date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$dose milligrams from $date for $_temp0';
  }

  @override
  String historyFlareRow(Object date, Object dose) {
    return 'Flare on $date, back to $dose milligrams';
  }

  @override
  String historyHoldRow(Object dose, int days, Object date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Held at $dose milligrams for $_temp0 from $date';
  }

  @override
  String get exportComingSoon => 'Export is coming next';

  @override
  String get exportComingSoonBody =>
      'A PDF and a spreadsheet for your appointment. Not built yet.';

  @override
  String get chartOverlineCaps => 'YOUR DOSE OVER TIME';

  @override
  String get drugPrednisolone => 'prednisolone';

  @override
  String get settingsSystemLanguage => 'System';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAppDescription =>
      'An offline companion for a slow steroid taper.';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsViewLicenses => 'View licenses';

  @override
  String get settingsLicensesTitle => 'Licenses';

  @override
  String get settingsVersionCopied => 'Version copied';

  @override
  String get settingsAccessibility => 'Reading and reminders';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String settingsReminderAt(Object time) {
    return 'On · $time';
  }

  @override
  String get settingsBackupNote =>
      'A copy you keep. Nothing leaves this phone unless you send it.';

  @override
  String get settingsNotImplemented =>
      'Not built yet — this arrives with the export release.';

  @override
  String settingsTextSizeSemantics(Object value) {
    return 'Text size, $value times';
  }

  @override
  String get planNextStep => 'Next step';

  @override
  String get planSave => 'Save plan';

  @override
  String get planSaved => 'Plan saved';

  @override
  String get planDangerZone => 'Danger zone';

  @override
  String get planDelete => 'Delete plan';

  @override
  String get planDeleteTitle => 'Delete this plan?';

  @override
  String planDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recorded days',
      one: '1 recorded day',
    );
    return 'Your plan and $_temp0 are removed from this phone. This cannot be undone.';
  }

  @override
  String get planDeleteConfirm => 'Delete everything';

  @override
  String get planExportFirst => 'Export first';

  @override
  String planCaveat(Object percent, Object dose, Object tenPercent) {
    return '$percent of $dose is $tenPercent — your doctor’s instruction wins';
  }

  @override
  String get planStepOverride => 'Change the step';

  @override
  String get planStrengthsNote =>
      'The strengths you actually hold. Edit them to match your box.';

  @override
  String get planStartDate => 'Start date';

  @override
  String get planHoldPeriod => 'Days at each dose';

  @override
  String get planPercentPerStep => 'Percent per step';

  @override
  String get planFixedStep => 'Step size';

  @override
  String get planTaperComplete => 'You have reached your target';

  @override
  String get planReachesTarget => 'This step reaches your target.';

  @override
  String get planStepNotDue => 'This step is not finished yet';

  @override
  String get planErrorDoseRequired => 'Enter a dose';

  @override
  String planErrorDoseUnreadable(Object example) {
    return 'Use one decimal separator, like $example';
  }

  @override
  String get planErrorTargetTooHigh =>
      'The target must be below the current dose';

  @override
  String get planErrorDoseTooHigh =>
      'That is a very high dose — check it is right';

  @override
  String get planErrorNameRequired => 'Enter the medicine’s name';

  @override
  String get planErrorNameTooLong => 'Sixty characters at most';

  @override
  String get planErrorLastStrength => 'Keep at least one strength';

  @override
  String get planErrorPercent => 'Between 1 and 50';

  @override
  String get planErrorHoldPeriod => 'At least one day';

  @override
  String planErrorDoseTooPrecise(Object example) {
    return 'Doses go to two decimal places, like $example';
  }

  @override
  String get planErrorFixedStep =>
      'More than zero, and no further than your target';

  @override
  String get planAddStrength => 'Add strength';

  @override
  String get actionAdd => 'Add';

  @override
  String get planStrengthValue => 'Tablet strength';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsTextSizeLarger => 'Larger';

  @override
  String get settingsTextSizeLargest => 'Largest';

  @override
  String get planStrengthsCaps => 'TABLET STRENGTHS HELD';

  @override
  String get planMethodCaps => 'METHOD';

  @override
  String get planNextStepCaps => 'NEXT STEP';

  @override
  String get planDangerZoneCaps => 'DANGER ZONE';

  @override
  String get settingsBackupCaps => 'BACKUP';

  @override
  String get settingsAboutCaps => 'ABOUT';

  @override
  String get settingsAccessibilityCaps => 'READING AND REMINDERS';
}
