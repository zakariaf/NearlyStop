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
  String get stateToday => 'ئەمڕۆ';

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
  String get actionCancel => 'پاشگەزبوونەوە';

  @override
  String get actionClose => 'داخستن';

  @override
  String get actionUndo => 'گەڕاندنەوە';

  @override
  String get stateUnavailable => 'بەردەست نییە';

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
  String get blockCompleted => 'تەواوبوو';

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

  @override
  String get unknownRouteTitle => 'ئەم پەڕەیە بوونی نییە';

  @override
  String get unknownRouteAction => 'بۆ ئەمڕۆ';

  @override
  String get shellStorageError =>
      'ڕێکخستنەکانت بار نەکران، بۆیە ئەپەکە بنەڕەتەکانی خۆی بەکاردەهێنێت.';

  @override
  String doseNotAchievable(Object dose) {
    return 'لە حەبەکانی تۆ دروست نابێت: $dose میلیگرام';
  }

  @override
  String holdingAtDose(Object dose) {
    return 'جێگیر لەسەر $dose';
  }

  @override
  String nDaysNotTicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ڕۆژی ڕابردوو تۆمار نەکراون',
    );
    return '$_temp0';
  }

  @override
  String get stepFinishedExplainer =>
      'ڕۆژەکانی ئەم هەنگاوە تەواوبوون. دۆزەکەت لێرە دەمێنێتەوە تا هەنگاوی داهاتوو دەست پێبکەیت.';

  @override
  String get startNextStep => 'دەستپێکردنی هەنگاوی داهاتوو';

  @override
  String get holdNeedsActiveStep => 'هیچ هەنگاوێک نییە کە بوەستێنرێت';

  @override
  String get markTaken => 'وەک وەرگیراو تۆمار بکە';

  @override
  String takenAt(Object time) {
    return 'وەرگیرا لە $time';
  }

  @override
  String get markedAsTaken => 'وەک وەرگیراو تۆمار کرا';

  @override
  String contextLineSemantics(
    Object step,
    Object total,
    Object from,
    Object to,
    Object day,
    Object length,
  ) {
    return 'هەنگاوی $step لە $total، کەمکردنەوە لە $from بۆ $to، ڕۆژی $day لە $length';
  }

  @override
  String todaySemanticsNewDose(Object dose, Object breakdown) {
    return 'ئەمڕۆ، $dose میلیگرام: $breakdown. ڕۆژی دۆزی نوێ. هێشتا وەرنەگیراوە.';
  }

  @override
  String get flareTitle => 'تۆمارکردنی هەڵگیرسانەوە';

  @override
  String get flarePickDose => 'گەڕانەوە بۆ دۆزێک کە کاری کرد';

  @override
  String get flareHistoryKept =>
      'مێژوو و کۆی گشتیت دەپارێزرێن. ڕۆژەکانی لە ئەمڕۆوە لەم دۆزەوە دروست دەکرێنەوە.';

  @override
  String get flareConfirm => 'هەڵگیرسانەوە تۆمار بکە';

  @override
  String flareDateRange(Object dose, Object from, Object to) {
    return '$dose — لە $from بۆ $to';
  }

  @override
  String get flareNoHistory =>
      'هێشتا هیچ هەنگاوێکت تەواو نەکردووە، بۆیە دۆزێکی پێشووتر نییە.';

  @override
  String get holdTitle => 'مانەوە لەسەر ئەم دۆزە';

  @override
  String get holdExtraDays => 'ڕۆژی زیادە';

  @override
  String holdConsequence(Object dose, Object days) {
    return 'بۆ $days ڕۆژی تر لەسەر $dose دەمێنیتەوە. هەنگاوەکە وازی لێ ناهێنرێت و هیچ لەدەست ناچێت.';
  }

  @override
  String get holdConfirm => 'وەستان';

  @override
  String get noteTitle => 'تێبینی بۆ ئەمڕۆ';

  @override
  String get noteHint => 'ئەمڕۆ چۆن بوو؟';

  @override
  String get noteSave => 'پاشەکەوتکردنی تێبینی';

  @override
  String get taperCompleteTitle => 'گەیشتیتە ئامانجەکەت';

  @override
  String get taperCompleteBody =>
      'کەمکردنەوەکەت تەواوبوو. بەردەوام بە لەسەر ڕێنماییەکانی پزیشکەکەت.';

  @override
  String get noPlanHeading => 'پلانەکەت لێرەوە دەست پێدەکات';

  @override
  String get noPlanBody =>
      'ئەو پلانە زیاد بکە کە لەگەڵ پزیشکەکەت ڕێککەوتوویت، ئەم شاشەیە هەموو بەیانییەک پیشانت دەدات چی وەربگریت.';

  @override
  String get noPlanAction => 'پلانەکەم ڕێک بخە';

  @override
  String get errorTitle => 'لە خوێندنەوەی پلانەکەت هەڵەیەک ڕوویدا';

  @override
  String get errorRetry => 'دووبارە هەوڵ بدە';

  @override
  String get actionNotNow => 'ئێستا نا';

  @override
  String get backfillAction => 'ئێستا تۆماریان بکە';

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
      other: '$leadCount ڕۆژ بە $leadDose',
    );
    String _temp1 = intl.Intl.pluralLogic(
      restCount,
      locale: localeName,
      other: '$restCount ڕۆژ بە $restDose',
    );
    return '$_temp0، پاشان $_temp1';
  }

  @override
  String steadyStateTitle(Object dose) {
    return 'جێگیر لەسەر $dose';
  }

  @override
  String get held => 'وەستێنراو';

  @override
  String heldAtBlock(int block) {
    return 'وەستێنراو لە بلۆکی $block';
  }

  @override
  String get pastStepReadOnly => 'ئەم هەنگاوە تەواوبووە و ناگۆڕدرێت';

  @override
  String get jumpToToday => 'بازدان بۆ ئەمڕۆ';

  @override
  String get futureDayNotYet => 'ناتوانیت ڕۆژێک تۆمار بکەیت کە هێشتا نەهاتووە';

  @override
  String get stepSwitcherTitle => 'هەنگاوێک هەڵبژێرە';

  @override
  String stepRangeLabel(int index, int total, Object from, Object to) {
    return 'هەنگاوی $index لە $total — $from بۆ $to';
  }

  @override
  String scheduleDaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return '$day، $dose میلیگرام: $breakdown.$notes';
  }

  @override
  String get scheduleNoteNewDose => ' ڕۆژی دۆزی نوێ.';

  @override
  String scheduleNoteHeld(int block) {
    return ' ڕاگیراوە، ڕۆژێکی زیادە لە بەشی $block.';
  }

  @override
  String get scheduleNoteHeldNoBlock => ' ڕاگیراوە، ڕۆژێکی زیادە.';

  @override
  String scheduleNoteState(Object state) {
    return ' $state.';
  }

  @override
  String get scheduleNoteUnachievable =>
      ' ئەم دۆزە لە قورساییەکانی دەستت دروست نابێت.';

  @override
  String scheduleTodaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return 'ئەمڕۆ. $day، $dose میلیگرام: $breakdown.$notes';
  }

  @override
  String get tabletSeparator => '، ';

  @override
  String get stateTakenCaps => 'وەرگیرا';

  @override
  String get stateNotTickedCaps => 'تۆمار نەکراوە';

  @override
  String get stateTodayCaps => 'ئەمڕۆ';

  @override
  String get stateUpcomingCaps => 'داهاتوو';
}
