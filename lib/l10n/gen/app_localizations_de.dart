// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'NearlyStop';

  @override
  String get welcomeTitle => 'Willkommen bei NearlyStop';

  @override
  String get welcomeDisclaimer =>
      'NearlyStop ordnet den Plan, den Sie und Ihre Ärztin oder Ihr Arzt vereinbart haben. Es gibt keine medizinischen Ratschläge. Befolgen Sie immer die Anweisungen Ihrer Ärztin oder Ihres Arztes.';

  @override
  String get welcomeAccept => 'Verstanden';

  @override
  String get welcomeOffline =>
      'Alles bleibt auf diesem Telefon. Kein Konto, kein Internet.';

  @override
  String get tabToday => 'Heute';

  @override
  String get tabSchedule => 'Plan';

  @override
  String get tabProgress => 'Verlauf';

  @override
  String get tabPlan => 'Therapie';

  @override
  String get tabSettings => 'Optionen';

  @override
  String doseWithUnit(String dose) {
    return '$dose mg';
  }

  @override
  String get milligramUnit => 'mg';

  @override
  String get stateNewDoseDay => 'Neuer Dosistag';

  @override
  String get stateToday => 'Heute';

  @override
  String get stateTaken => 'Eingenommen';

  @override
  String get stateNotTicked => 'Nicht erfasst';

  @override
  String get stateUpcoming => 'Bevorstehend';

  @override
  String get actionTaken => 'Eingenommen';

  @override
  String get actionAddNote => 'Notiz';

  @override
  String get actionHold => 'Pausieren';

  @override
  String get actionFlare => 'Schub';

  @override
  String get actionNextStep => 'Nächster Schritt';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionUndo => 'Rückgängig';

  @override
  String get stateUnavailable => 'Nicht verfügbar';

  @override
  String stepOfTotal(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String dayOfStep(int day, int length) {
    return 'Tag $day von $length';
  }

  @override
  String blockOfTotal(int current, int total) {
    return 'Block $current von $total';
  }

  @override
  String get blockCompleted => 'Abgeschlossen';

  @override
  String blockPattern(String newDose, int oldDays, String oldDose) {
    String _temp0 = intl.Intl.pluralLogic(
      oldDays,
      locale: localeName,
      other: '$oldDays Tage',
      one: '1 Tag',
    );
    return 'einen Tag $newDose, dann $_temp0 $oldDose';
  }

  @override
  String doseTransition(String from, String to) {
    return '$from auf $to';
  }

  @override
  String tabletBreakdown(String parts) {
    return '$parts';
  }

  @override
  String get yesterdayNotTicked => 'Gestern nicht erfasst — jetzt eintragen?';

  @override
  String takenDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage erfasst',
      one: '1 Tag erfasst',
    );
    return '$_temp0';
  }

  @override
  String daysOnMedicine(int count, String medicine) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage mit $medicine',
      one: '1 Tag mit $medicine',
    );
    return '$_temp0';
  }

  @override
  String get adherenceReassurance =>
      'Tage bisher erfasst — ein paar Lücken ändern nichts';

  @override
  String get totalTaken => 'insgesamt eingenommen';

  @override
  String lowerThanStart(String amount) {
    return 'Sie liegen $amount unter dem Startwert.';
  }

  @override
  String flaresRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schübe erfasst',
      one: '1 Schub erfasst',
    );
    return '$_temp0';
  }

  @override
  String get doseOverTime => 'Ihre Dosis im Verlauf';

  @override
  String startedAt(String date, String dose) {
    return 'Begonnen $date mit $dose';
  }

  @override
  String adherenceRatio(String taken, String total) {
    return '$taken von $total';
  }

  @override
  String get planMedicine => 'Medikament';

  @override
  String get planCurrentDose => 'Aktuelle Dosis';

  @override
  String get planTarget => 'Zieldosis';

  @override
  String get planStrengths => 'Vorhandene Stärken';

  @override
  String get planAllowHalves => 'Ich kann teilen';

  @override
  String get planMethod => 'Methode';

  @override
  String get methodDsns => 'Dead Slow and Nearly Stop';

  @override
  String get methodPercentage => 'Prozentual';

  @override
  String get methodFixed => 'Feste mg';

  @override
  String suggestedStep(String amount) {
    return 'Vorschlag: $amount';
  }

  @override
  String percentageExplainer(String percent, String dose, String result) {
    return '$percent % von $dose sind $result — die Anweisung Ihrer Ärztin oder Ihres Arztes gilt';
  }

  @override
  String get settingsReminder => 'Tägliche Erinnerung';

  @override
  String get settingsTextSize => 'Textgröße';

  @override
  String get settingsHighContrast => 'Hoher Kontrast';

  @override
  String get settingsBackup => 'Sicherung';

  @override
  String get settingsExport => 'Daten sichern';

  @override
  String get settingsExportForDoctor => 'Ausdruck für Praxis';

  @override
  String get settingsImport => 'Daten laden';

  @override
  String get settingsReadDisclaimer => 'Hinweis erneut lesen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsTheme => 'Design';

  @override
  String get toggleOn => 'Ein';

  @override
  String get toggleOff => 'Aus';

  @override
  String get textSizeLarge => 'Groß';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String todaySemantics(String dose, String breakdown) {
    return 'Heute, $dose Milligramm: $breakdown. Noch nicht eingenommen.';
  }

  @override
  String todaySemanticsTaken(String dose, String breakdown) {
    return 'Heute, $dose Milligramm: $breakdown. Eingenommen.';
  }

  @override
  String get ckbWeekdayNames =>
      'Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag';

  @override
  String get ckbMonthNames =>
      'Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember';

  @override
  String get unknownRouteTitle => 'Diese Seite gibt es nicht';

  @override
  String get unknownRouteAction => 'Zu Heute';

  @override
  String get shellStorageError =>
      'Ihre Einstellungen konnten nicht geladen werden; die App verwendet ihre Standardwerte.';

  @override
  String doseNotAchievable(Object dose) {
    return 'Aus Ihren Tabletten nicht herstellbar: $dose mg';
  }

  @override
  String holdingAtDose(Object dose) {
    return 'Bleibt bei $dose';
  }

  @override
  String nDaysNotTicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die letzten $count Tage sind nicht abgehakt',
      one: 'Gestern wurde nicht abgehakt',
    );
    return '$_temp0';
  }

  @override
  String get stepFinishedExplainer =>
      'Die Tage dieses Schritts sind vorbei. Ihre Dosis bleibt hier, bis Sie den nächsten beginnen.';

  @override
  String get startNextStep => 'Nächsten Schritt beginnen';

  @override
  String get holdNeedsActiveStep =>
      'Es läuft kein Schritt, der pausiert werden könnte';

  @override
  String get markTaken => 'Als eingenommen markieren';

  @override
  String takenAt(Object time) {
    return 'Eingenommen um $time';
  }

  @override
  String get markedAsTaken => 'Als eingenommen markiert';

  @override
  String contextLineSemantics(
    Object step,
    Object total,
    Object from,
    Object to,
    Object day,
    Object length,
  ) {
    return 'Schritt $step von $total, Reduzierung von $from auf $to, Tag $day von $length';
  }

  @override
  String todaySemanticsNewDose(Object dose, Object breakdown) {
    return 'Heute, $dose Milligramm: $breakdown. Neuer Dosistag. Noch nicht eingenommen.';
  }

  @override
  String get flareTitle => 'Schub erfassen';

  @override
  String get flarePickDose => 'Zurück zu einer Dosis, die gewirkt hat';

  @override
  String get flareHistoryKept =>
      'Ihr Verlauf und Ihre bisherige Gesamtmenge bleiben erhalten. Die Tage ab heute werden aus dieser Dosis neu berechnet.';

  @override
  String get flareConfirm => 'Schub erfassen';

  @override
  String flareDateRange(Object dose, Object from, Object to) {
    return '$dose — von $from bis $to';
  }

  @override
  String get flareNoHistory =>
      'Sie haben noch keinen Schritt abgeschlossen, daher gibt es keine frühere Dosis.';

  @override
  String get holdTitle => 'Bei dieser Dosis bleiben';

  @override
  String get holdExtraDays => 'Zusätzliche Tage';

  @override
  String holdConsequence(Object dose, Object days) {
    return 'Sie bleiben $days weitere Tage bei $dose. Der Schritt wird nicht abgebrochen und nichts geht verloren.';
  }

  @override
  String get holdConfirm => 'Pausieren';

  @override
  String get noteTitle => 'Notiz für heute';

  @override
  String get noteHint => 'Wie war der Tag?';

  @override
  String get noteSave => 'Notiz speichern';

  @override
  String get taperCompleteTitle => 'Sie haben Ihr Ziel erreicht';

  @override
  String get taperCompleteBody =>
      'Ihre Ausschleichphase ist abgeschlossen. Folgen Sie weiterhin den Anweisungen Ihrer Ärztin oder Ihres Arztes.';

  @override
  String get noPlanHeading => 'Ihr Plan beginnt hier';

  @override
  String get noPlanBody =>
      'Tragen Sie den mit Ihrer Ärztin oder Ihrem Arzt vereinbarten Plan ein, dann zeigt dieser Bildschirm jeden Morgen, was einzunehmen ist.';

  @override
  String get noPlanAction => 'Plan einrichten';

  @override
  String get errorTitle => 'Beim Lesen Ihres Plans ist etwas schiefgelaufen';

  @override
  String get errorRetry => 'Erneut versuchen';

  @override
  String get actionNotNow => 'Jetzt nicht';

  @override
  String get backfillAction => 'Jetzt abhaken';

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
      other: '$leadCount Tage mit $leadDose',
      one: 'ein Tag mit $leadDose',
    );
    String _temp1 = intl.Intl.pluralLogic(
      restCount,
      locale: localeName,
      other: '$restCount Tage mit $restDose',
      one: '1 Tag mit $restDose',
    );
    return '$_temp0, dann $_temp1';
  }

  @override
  String steadyStateTitle(Object dose) {
    return 'Bleibt bei $dose';
  }

  @override
  String get held => 'Pausiert';

  @override
  String heldAtBlock(int block) {
    return 'Pausiert bei Block $block';
  }

  @override
  String get pastStepReadOnly =>
      'Dieser Schritt ist abgeschlossen und kann nicht geändert werden';

  @override
  String get jumpToToday => 'Zu heute springen';

  @override
  String get futureDayNotYet =>
      'Ein Tag in der Zukunft kann nicht abgehakt werden';

  @override
  String get stepSwitcherTitle => 'Schritt auswählen';

  @override
  String stepRangeLabel(int index, int total, Object from, Object to) {
    return 'Schritt $index von $total — $from auf $to';
  }

  @override
  String scheduleDaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return '$day, $dose Milligramm: $breakdown.$notes';
  }

  @override
  String get scheduleNoteNewDose => ' Tag der neuen Dosis.';

  @override
  String scheduleNoteHeld(int block) {
    return ' Gehalten, ein zusätzlicher Tag in Block $block.';
  }

  @override
  String get scheduleNoteHeldNoBlock => ' Gehalten, ein zusätzlicher Tag.';

  @override
  String scheduleNoteState(Object state) {
    return ' $state.';
  }

  @override
  String get scheduleNoteUnachievable =>
      ' Diese Dosis lässt sich aus Ihren Tabletten nicht zusammenstellen.';

  @override
  String scheduleTodaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return 'Heute. $day, $dose Milligramm: $breakdown.$notes';
  }

  @override
  String get tabletSeparator => ', ';

  @override
  String get stateTakenCaps => 'EINGENOMMEN';

  @override
  String get stateNotTickedCaps => 'NICHT ABGEHAKT';

  @override
  String get stateTodayCaps => 'HEUTE';

  @override
  String get stateUpcomingCaps => 'BEVORSTEHEND';

  @override
  String get chartOverline => 'Ihre Dosis im Zeitverlauf';

  @override
  String daysOnDrugLabel(Object medicine) {
    return 'Tage mit $medicine';
  }

  @override
  String holdsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pausen erfasst',
      one: '1 Pause erfasst',
    );
    return '$_temp0';
  }

  @override
  String flaresAndHoldsRecorded(int flares, int holds) {
    String _temp0 = intl.Intl.pluralLogic(
      flares,
      locale: localeName,
      other: '$flares Schübe',
      one: '1 Schub',
    );
    String _temp1 = intl.Intl.pluralLogic(
      holds,
      locale: localeName,
      other: '$holds Pausen',
      one: '1 Pause',
    );
    return '$_temp0 und $_temp1 erfasst';
  }

  @override
  String get noEventsRecorded => 'Keine Schübe oder Pausen erfasst';

  @override
  String get sameAsStart => 'Sie bleiben stabil bei Ihrer Anfangsdosis.';

  @override
  String chartSummary(
    Object from,
    Object fromMonth,
    Object to,
    Object toMonth,
    Object events,
  ) {
    return 'Diagramm: Ihre Dosis sank von $from Milligramm im $fromMonth auf $to Milligramm im $toMonth$events.';
  }

  @override
  String chartSummaryEvents(Object events) {
    return ', mit $events';
  }

  @override
  String get doseHistoryTitle => 'Dosisverlauf als Liste';

  @override
  String historySegmentRow(Object dose, Object date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$dose Milligramm ab $date für $_temp0';
  }

  @override
  String historyFlareRow(Object date, Object dose) {
    return 'Schub am $date, zurück auf $dose Milligramm';
  }

  @override
  String historyHoldRow(Object dose, int days, Object date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return 'Gehalten bei $dose Milligramm für $_temp0 ab $date';
  }

  @override
  String get exportComingSoon => 'Export kommt als Nächstes';

  @override
  String get exportComingSoonBody =>
      'Ein PDF und eine Tabelle für Ihren Termin. Noch nicht gebaut.';
}
