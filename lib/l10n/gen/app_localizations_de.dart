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
}
