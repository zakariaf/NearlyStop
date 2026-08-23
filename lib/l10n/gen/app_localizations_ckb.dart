// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Central Kurdish (`ckb`).
class AppLocalizationsCkb extends AppLocalizations {
  AppLocalizationsCkb([String locale = 'ckb']) : super(locale);

  @override
  String get appTitle => 'NearlyStop';

  @override
  String get welcomeTitle => 'بەخێربێیت بۆ NearlyStop';

  @override
  String get welcomeDisclaimer =>
      'NearlyStop تەنها ئەو پلانە ڕێک دەخات کە تۆ و پزیشکەکەت لەسەری ڕێککەوتوون. ئامۆژگاری پزشکی نادات. هەمیشە ڕێنمایی پزیشکەکەت پەیڕەو بکە.';

  @override
  String get welcomeAccept => 'تێگەیشتم';

  @override
  String get welcomeOffline =>
      'هەموو شتێک لەسەر ئەم مۆبایلە دەمێنێتەوە. بێ هەژمار، بێ ئینتەرنێت.';

  @override
  String get tabToday => 'ئەمڕۆ';

  @override
  String get tabSchedule => 'خشتە';

  @override
  String get tabProgress => 'پێشکەوتن';

  @override
  String get tabPlan => 'پلان';

  @override
  String get tabSettings => 'ڕێکخستن';

  @override
  String doseWithUnit(String dose) {
    return '$dose میلیگرام';
  }

  @override
  String get milligramUnit => 'میلیگرام';

  @override
  String get stateNewDoseDay => 'ڕۆژی دۆزی نوێ';

  @override
  String get stateTaken => 'وەرگیرا';

  @override
  String get stateNotTicked => 'تۆمار نەکراوە';

  @override
  String get stateUpcoming => 'داهاتوو';

  @override
  String get actionTaken => 'وەرگیرا';

  @override
  String get actionAddNote => 'تێبینی';

  @override
  String get actionHold => 'ڕاگرتن';

  @override
  String get actionFlare => 'گەڕانەوە';

  @override
  String get actionNextStep => 'هەنگاوی داهاتوو';

  @override
  String stepOfTotal(int current, int total) {
    return 'هەنگاوی $current لە $total';
  }

  @override
  String dayOfStep(int day, int length) {
    return 'ڕۆژی $day لە $length';
  }

  @override
  String blockOfTotal(int current, int total) {
    return 'بەشی $current لە $total';
  }

  @override
  String blockPattern(String newDose, int oldDays, String oldDose) {
    String _temp0 = intl.Intl.pluralLogic(
      oldDays,
      locale: localeName,
      other: '$oldDays ڕۆژ',
    );
    return 'یەک ڕۆژ $newDose، پاشان $_temp0 $oldDose';
  }

  @override
  String doseTransition(String from, String to) {
    return '$from بۆ $to';
  }

  @override
  String tabletBreakdown(String parts) {
    return '$parts';
  }

  @override
  String get yesterdayNotTicked => 'دوێنێ تۆمار نەکرا — ئێستا نیشانەی بکە؟';

  @override
  String takenDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ڕۆژ تۆمار کراوە',
    );
    return '$_temp0';
  }

  @override
  String daysOnMedicine(int count, String medicine) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ڕۆژ بە $medicine',
    );
    return '$_temp0';
  }

  @override
  String get adherenceReassurance =>
      'ڕۆژ تا ئێستا تۆمار کراوە — چەند بۆشاییەک هیچ ناگۆڕێت';

  @override
  String get totalTaken => 'بە گشتی وەرگیراوە';

  @override
  String lowerThanStart(String amount) {
    return 'تۆ $amount نزمتریت لە کاتی دەستپێک.';
  }

  @override
  String flaresRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count گەڕانەوە تۆمار کراوە',
    );
    return '$_temp0';
  }

  @override
  String get doseOverTime => 'دۆزەکەت بە درێژایی کات';

  @override
  String startedAt(String date, String dose) {
    return 'دەستی پێکرد $date بە $dose';
  }

  @override
  String adherenceRatio(String taken, String total) {
    return '$taken لە $total';
  }

  @override
  String get planMedicine => 'دەرمان';

  @override
  String get planCurrentDose => 'دۆزی ئێستا';

  @override
  String get planTarget => 'ئامانج';

  @override
  String get planStrengths => 'هێزی حەبەکانی بەردەست';

  @override
  String get planAllowHalves => 'دەتوانم حەب بەش بکەم';

  @override
  String get planMethod => 'شێواز';

  @override
  String get methodDsns => 'هێواش و نزیک بە وەستان';

  @override
  String get methodPercentage => 'ڕێژەیی';

  @override
  String get methodFixed => 'میلیگرامی جێگیر';

  @override
  String suggestedStep(String amount) {
    return 'هەنگاوی پێشنیارکراو $amount';
  }

  @override
  String percentageExplainer(String percent, String dose, String result) {
    return '$percent٪ لە $dose دەکاتە $result — ڕێنمایی پزیشکەکەت پێشەنگە';
  }

  @override
  String get settingsReminder => 'بیرخەرەوەی ڕۆژانە';

  @override
  String get settingsTextSize => 'قەبارەی نووسین';

  @override
  String get settingsHighContrast => 'پێچەوانەیی بەرز';

  @override
  String get settingsBackup => 'پاڵپشت';

  @override
  String get settingsExport => 'دەرهێنانی داتا';

  @override
  String get settingsExportForDoctor => 'دەرهێنان بۆ پزیشک';

  @override
  String get settingsImport => 'هێنانی داتا';

  @override
  String get settingsReadDisclaimer => 'دووبارە خوێندنەوەی ئاگادارکردنەوە';

  @override
  String get settingsLanguage => 'زمان';

  @override
  String get settingsTheme => 'ڕووکار';

  @override
  String get toggleOn => 'کراوە';

  @override
  String get toggleOff => 'داخراو';

  @override
  String get textSizeLarge => 'گەورە';

  @override
  String get themeLight => 'ڕووناک';

  @override
  String get themeDark => 'تاریک';

  @override
  String todaySemantics(String dose, String breakdown) {
    return 'ئەمڕۆ، $dose میلیگرام: $breakdown. هێشتا وەرنەگیراوە.';
  }

  @override
  String todaySemanticsTaken(String dose, String breakdown) {
    return 'ئەمڕۆ، $dose میلیگرام: $breakdown. وەرگیرا.';
  }

  @override
  String get ckbWeekdayNames =>
      'دووشەممە|سێشەممە|چوارشەممە|پێنجشەممە|هەینی|شەممە|یەکشەممە';

  @override
  String get ckbMonthNames =>
      'کانوونی دووەم|شوبات|ئازار|نیسان|ئایار|حوزەیران|تەمووز|ئاب|ئەیلوول|تشرینی یەکەم|تشرینی دووەم|کانوونی یەکەم';
}
