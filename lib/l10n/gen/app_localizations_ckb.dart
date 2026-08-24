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

  @override
  String get chartOverline => 'دۆزەکەت بە درێژایی کات';

  @override
  String daysOnDrugLabel(Object medicine) {
    return 'ڕۆژ لەگەڵ $medicine';
  }

  @override
  String holdsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ڕاگرتن تۆمارکراوە',
    );
    return '$_temp0';
  }

  @override
  String flaresAndHoldsRecorded(int flares, int holds) {
    String _temp0 = intl.Intl.pluralLogic(
      flares,
      locale: localeName,
      other: '$flares هەڵگیرسان',
    );
    String _temp1 = intl.Intl.pluralLogic(
      holds,
      locale: localeName,
      other: '$holds ڕاگرتن',
    );
    return '$_temp0 و $_temp1 تۆمارکراوە';
  }

  @override
  String get noEventsRecorded => 'هیچ هەڵگیرسان یان ڕاگرتنێک تۆمار نەکراوە';

  @override
  String get sameAsStart => 'لەسەر ئەو دۆزەی پێی دەستت پێکرد جێگیریت.';

  @override
  String chartSummary(
    Object from,
    Object fromMonth,
    Object to,
    Object toMonth,
    Object events,
  ) {
    return 'هێڵکاری: دۆزەکەت لە $from میلیگرام لە $fromMonth دابەزی بۆ $to میلیگرام لە $toMonth$events.';
  }

  @override
  String chartSummaryEvents(Object events) {
    return '، لەگەڵ $events';
  }

  @override
  String get doseHistoryTitle => 'مێژووی دۆز وەک لیست';

  @override
  String historySegmentRow(Object dose, Object date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ڕۆژ',
    );
    return '$dose میلیگرام لە $date بۆ ماوەی $_temp0';
  }

  @override
  String historyFlareRow(Object date, Object dose) {
    return 'هەڵگیرسان لە $date، گەڕانەوە بۆ $dose میلیگرام';
  }

  @override
  String historyHoldRow(Object dose, int days, Object date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ڕۆژ',
    );
    return 'ڕاگیراوە لە $dose میلیگرام بۆ ماوەی $_temp0 لە $date';
  }

  @override
  String get chartOverlineCaps => 'دۆزەکەت بە درێژایی کات';

  @override
  String get drugPrednisolone => 'پرێدنیزۆلۆن';

  @override
  String get settingsSystemLanguage => 'سیستەم';

  @override
  String get settingsAbout => 'دەربارە';

  @override
  String get settingsAppDescription =>
      'هاوڕێیەکی ئۆفلاین بۆ کەمکردنەوەی هێواشی دۆز.';

  @override
  String get settingsVersion => 'وەشان';

  @override
  String get settingsViewLicenses => 'بینینی مۆڵەتەکان';

  @override
  String get settingsLicensesTitle => 'مۆڵەتەکان';

  @override
  String get settingsVersionCopied => 'وەشان کۆپی کرا';

  @override
  String get settingsAccessibility => 'خوێندنەوە و بیرخەرەوەکان';

  @override
  String get settingsOn => 'کارا';

  @override
  String get settingsOff => 'ناکارا';

  @override
  String settingsReminderAt(Object time) {
    return 'کارا · $time';
  }

  @override
  String get settingsBackupNote =>
      'کۆپییەک کە خۆت دەیهێڵیتەوە. هیچ شتێک لەم مۆبایلە دەرناچێت مەگەر خۆت بینێریت.';

  @override
  String settingsTextSizeSemantics(Object value) {
    return 'قەبارەی نووسین، $value جار';
  }

  @override
  String get planNextStep => 'هەنگاوی داهاتوو';

  @override
  String get planSave => 'پاشەکەوتکردنی پلان';

  @override
  String get planSaved => 'پلان پاشەکەوت کرا';

  @override
  String get planDangerZone => 'ناوچەی مەترسی';

  @override
  String get planDelete => 'سڕینەوەی پلان';

  @override
  String get planDeleteTitle => 'ئەم پلانە بسڕدرێتەوە؟';

  @override
  String planDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ڕۆژی تۆمارکراو',
    );
    return 'پلانەکەت و $_temp0 لەم مۆبایلە دەسڕدرێنەوە. ئەمە ناگەڕێتەوە.';
  }

  @override
  String get planDeleteConfirm => 'سڕینەوەی هەموو شتێک';

  @override
  String get planExportFirst => 'سەرەتا هەناردە بکە';

  @override
  String planCaveat(Object percent, Object dose, Object tenPercent) {
    return '$percentی $dose دەکاتە $tenPercent — ڕێنمایی پزیشکەکەت باڵادەستە';
  }

  @override
  String get planStepOverride => 'گۆڕینی هەنگاو';

  @override
  String get planStrengthsNote =>
      'ئەو قورساییانەی بەڕاستی هەتن. بەپێی سندوقەکەت دەستکاری بکە.';

  @override
  String get planStartDate => 'بەرواری دەستپێک';

  @override
  String get planHoldPeriod => 'ڕۆژ بۆ هەر دۆزێک';

  @override
  String get planPercentPerStep => 'ڕێژە بۆ هەر هەنگاوێک';

  @override
  String get planFixedStep => 'قەبارەی هەنگاو';

  @override
  String get planTaperComplete => 'گەیشتوویت بە ئامانجەکەت';

  @override
  String get planReachesTarget => 'ئەم هەنگاوە دەگاتە ئامانجەکەت.';

  @override
  String get planStepNotDue => 'ئەم هەنگاوە هێشتا تەواو نەبووە';

  @override
  String get planErrorDoseRequired => 'دۆز بنووسە';

  @override
  String planErrorDoseUnreadable(Object example) {
    return 'تەنها یەک جیاکەرەوەی دەیی، وەک $example';
  }

  @override
  String get planErrorTargetTooHigh => 'ئامانج دەبێت لە دۆزی ئێستا کەمتر بێت';

  @override
  String get planErrorDoseTooHigh => 'ئەمە دۆزێکی زۆر بەرزە — بیپشکنە';

  @override
  String get planErrorNameRequired => 'ناوی دەرمانەکە بنووسە';

  @override
  String get planErrorNameTooLong => 'زۆرترین شەست پیت';

  @override
  String get planErrorLastStrength => 'لانیکەم یەک قورسایی بهێڵەرەوە';

  @override
  String get planErrorPercent => 'لە نێوان ١ و ٥٠';

  @override
  String get planErrorHoldPeriod => 'لانیکەم یەک ڕۆژ';

  @override
  String planErrorDoseTooPrecise(Object example) {
    return 'دۆز تا دوو ژمارەی دەیی، وەک $example';
  }

  @override
  String get planErrorFixedStep => 'زیاتر لە سفر و نەک زیاتر لە ئامانجەکەت';

  @override
  String get planAddStrength => 'زیادکردنی هێزی حەب';

  @override
  String get actionAdd => 'زیادکردن';

  @override
  String get planStrengthValue => 'هێزی حەب';

  @override
  String get settingsTextSizeNormal => 'ئاسایی';

  @override
  String get settingsTextSizeLarge => 'گەورە';

  @override
  String get settingsTextSizeLarger => 'گەورەتر';

  @override
  String get settingsTextSizeLargest => 'گەورەترین';

  @override
  String get planStrengthsCaps => 'هێزی حەبەکانی بەردەست';

  @override
  String get planMethodCaps => 'شێواز';

  @override
  String get planNextStepCaps => 'هەنگاوی داهاتوو';

  @override
  String get planDangerZoneCaps => 'ناوچەی مەترسی';

  @override
  String get settingsBackupCaps => 'پاڵپشت';

  @override
  String get settingsAboutCaps => 'دەربارە';

  @override
  String get settingsAccessibilityCaps => 'خوێندنەوە و بیرخەرەوەکان';

  @override
  String get reminderTitle => 'پلانی ئەمڕۆت';

  @override
  String get reminderBody => 'بۆ بینینی پلانی ئەمڕۆ، نیەرلیستۆپ بکەرەوە.';

  @override
  String get reminderChannelName => 'بیرخەرەوەی ڕۆژانە';

  @override
  String get reminderChannelDescription =>
      'هەموو بەیانییەک یەک بیرخەرەوەی نەرم.';

  @override
  String get reminderBlocked => 'لە ڕێکخستنەکانی سیستەم بلۆک کراوە';

  @override
  String get reminderBlockedIos =>
      'ئاگادارییەکان بۆ نیەرلیستۆپ لە ڕێکخستن › ئاگادارییەکان بکەرەوە.';

  @override
  String get reminderBlockedAndroid =>
      'ئاگادارییەکان بۆ نیەرلیستۆپ لە ڕێکخستن › ئەپەکان › نیەرلیستۆپ بکەرەوە.';

  @override
  String get settingsBackupPlainText =>
      'فایلەکە دەقی سادەیە و کۆدنەکراوە. هەرکەسێک بیکاتەوە دەتوانێت پلانەکەت بخوێنێتەوە.';

  @override
  String get settingsBackupFailed =>
      'پاڵپشتەکە هەڵنەگیرا. هیچ شتێک لەسەر ئەم مۆبایلە نەگۆڕاوە.';

  @override
  String get settingsRestoreFailed =>
      'ئەو فایلە نەگەڕێندرایەوە. هیچ شتێک لەسەر ئەم مۆبایلە نەگۆڕاوە.';

  @override
  String get settingsRestoreDone => 'لە پاڵپشتەکەت گەڕێندرایەوە.';

  @override
  String get settingsBackupSubject => 'پاڵپشتی نیەرلیستۆپ';

  @override
  String get settingsRestoreConfirmTitle =>
      'هەموو شتێک لەسەر ئەم مۆبایلە بگۆڕدرێت؟';

  @override
  String get settingsRestoreConfirmBody =>
      'پلانەکەت، مێژووی دۆزەکەت، تووشبوونەوەکان و وەستانەکانت هەموویان بەوانەی ناو ئەم فایلە دەگۆڕدرێن. ئەوەی ئێستا لەسەر ئەم مۆبایلەیە دەڕوات.';

  @override
  String get settingsRestoreConfirmAction => 'هەموویان بگۆڕە';

  @override
  String get settingsRestoreExportFirst => 'سەرەتا پاڵپشت بکە، پاشان بگۆڕە';

  @override
  String get stateWorking => 'لە کارکردندایە';

  @override
  String get exportSheetTitle => 'هەناردەکردن بۆ پزیشکەکەت';

  @override
  String get exportPdfLabel => 'PDF بۆ چاپکردن';

  @override
  String get exportPdfAudience =>
      'لاپەڕەیەک کە دەتوانیت چاپی بکەیت یان لە کاتی ژوانەکەت پیشانی بدەیت.';

  @override
  String get exportCsvLabel => 'خشتەی داتا';

  @override
  String get exportCsvAudience =>
      'هەموو ڕۆژێک وەک ڕیزێک، بۆ پزیشکێک کە خودی ژمارەکانی دەوێت.';

  @override
  String get exportNotEncrypted =>
      'فایلەکە کۆدنەکراوە. هەرکەسێک بۆی بنێریت دەتوانێت مێژووی دۆزەکەت بخوێنێتەوە.';

  @override
  String get exportFailed =>
      'فایلەکە دروست نەکرا. هیچ شتێک لەسەر ئەم مۆبایلە نەگۆڕاوە.';

  @override
  String get exportNothingYet =>
      'هێشتا هیچ شتێک نییە بۆ هەناردەکردن. مێژووەکەت لە یەکەم ڕۆژتەوە دەست پێدەکات.';

  @override
  String get exportSubject => 'مێژووی دۆزی نیەرلیستۆپ';

  @override
  String exportDateRange(String from, String to) {
    return '$from تا $to';
  }

  @override
  String exportFooterPrefix(String app, String date) {
    return '$app · هەناردەکرا $date';
  }

  @override
  String get exportDisclaimer =>
      'لەسەر ئامێری نەخۆشەکە لە پلانێکەوە کە خۆی داویەتی دروستکراوە. ڕاوێژی پزیشکی نییە.';

  @override
  String get exportColumnDate => 'بەروار';

  @override
  String get exportColumnPlanned => 'پلاندراو';

  @override
  String get exportColumnActual => 'ڕاستەقینە';

  @override
  String get exportColumnTablets => 'حەبەکان';

  @override
  String get exportColumnNote => 'تێبینی';

  @override
  String get exportEventFlare => 'تووشبوونەوە';

  @override
  String get exportEventHold => 'وەستان';

  @override
  String exportHandoutTitle(String drug) {
    return 'مێژووی دۆزی $drug';
  }
}
