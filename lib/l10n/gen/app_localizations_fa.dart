// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'NearlyStop';

  @override
  String get welcomeTitle => 'به NearlyStop خوش آمدید';

  @override
  String get welcomeDisclaimer =>
      'NearlyStop فقط طرحی را که شما و پزشکتان توافق کرده‌اید مرتب می‌کند و توصیهٔ پزشکی نیست. همیشه از دستور پزشک خود پیروی کنید.';

  @override
  String get welcomeAccept => 'متوجه شدم';

  @override
  String get welcomeOffline =>
      'همه چیز روی همین گوشی می‌ماند. بدون حساب کاربری، بدون اینترنت.';

  @override
  String get tabToday => 'امروز';

  @override
  String get tabSchedule => 'برنامه';

  @override
  String get tabProgress => 'پیشرفت';

  @override
  String get tabPlan => 'طرح';

  @override
  String get tabSettings => 'تنظیمات';

  @override
  String doseWithUnit(String dose) {
    return '$dose میلی‌گرم';
  }

  @override
  String get milligramUnit => 'میلی‌گرم';

  @override
  String get stateNewDoseDay => 'روز دوز جدید';

  @override
  String get stateToday => 'امروز';

  @override
  String get stateTaken => 'مصرف شد';

  @override
  String get stateNotTicked => 'ثبت نشده';

  @override
  String get stateUpcoming => 'پیش‌رو';

  @override
  String get actionTaken => 'مصرف شد';

  @override
  String get actionAddNote => 'یادداشت';

  @override
  String get actionHold => 'توقف موقت';

  @override
  String get actionFlare => 'عود';

  @override
  String get actionNextStep => 'گام بعدی';

  @override
  String get actionCancel => 'انصراف';

  @override
  String get actionClose => 'بستن';

  @override
  String get actionUndo => 'واگرد';

  @override
  String get stateUnavailable => 'در دسترس نیست';

  @override
  String stepOfTotal(int current, int total) {
    return 'گام $current از $total';
  }

  @override
  String dayOfStep(int day, int length) {
    return 'روز $day از $length';
  }

  @override
  String blockOfTotal(int current, int total) {
    return 'مرحله $current از $total';
  }

  @override
  String get blockCompleted => 'تکمیل شد';

  @override
  String blockPattern(String newDose, int oldDays, String oldDose) {
    String _temp0 = intl.Intl.pluralLogic(
      oldDays,
      locale: localeName,
      other: '$oldDays روز',
    );
    return 'یک روز $newDose، سپس $_temp0 $oldDose';
  }

  @override
  String doseTransition(String from, String to) {
    return '$from به $to';
  }

  @override
  String tabletBreakdown(String parts) {
    return '$parts';
  }

  @override
  String get yesterdayNotTicked => 'دیروز ثبت نشده — الان علامت بزنید؟';

  @override
  String takenDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روز ثبت شده',
    );
    return '$_temp0';
  }

  @override
  String daysOnMedicine(int count, String medicine) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روز مصرف $medicine',
    );
    return '$_temp0';
  }

  @override
  String get adherenceReassurance =>
      'روز تا اینجا ثبت شده — چند روز جا افتاده اهمیتی ندارد';

  @override
  String get totalTaken => 'در مجموع مصرف شده';

  @override
  String lowerThanStart(String amount) {
    return 'شما $amount پایین‌تر از شروع هستید.';
  }

  @override
  String flaresRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عود ثبت شده',
    );
    return '$_temp0';
  }

  @override
  String get doseOverTime => 'دوز شما در طول زمان';

  @override
  String startedAt(String date, String dose) {
    return 'شروع: $date با $dose';
  }

  @override
  String adherenceRatio(String taken, String total) {
    return '$taken از $total';
  }

  @override
  String get planMedicine => 'دارو';

  @override
  String get planCurrentDose => 'دوز فعلی';

  @override
  String get planTarget => 'هدف';

  @override
  String get planStrengths => 'قرص‌های موجود';

  @override
  String get planAllowHalves => 'می‌توانم قرص را نصف کنم';

  @override
  String get planMethod => 'روش';

  @override
  String get methodDsns => 'آهسته و تقریباً متوقف';

  @override
  String get methodPercentage => 'درصدی';

  @override
  String get methodFixed => 'مقدار ثابت';

  @override
  String suggestedStep(String amount) {
    return 'گام پیشنهادی $amount';
  }

  @override
  String percentageExplainer(String percent, String dose, String result) {
    return '$percent٪ از $dose برابر $result است — دستور پزشک شما ارجح است';
  }

  @override
  String get settingsReminder => 'یادآور روزانه';

  @override
  String get settingsTextSize => 'اندازه متن';

  @override
  String get settingsHighContrast => 'کنتراست بالا';

  @override
  String get settingsBackup => 'پشتیبان';

  @override
  String get settingsExport => 'خروجی گرفتن';

  @override
  String get settingsExportForDoctor => 'خروجی برای پزشک';

  @override
  String get settingsImport => 'بازیابی';

  @override
  String get settingsReadDisclaimer => 'خواندن دوبارهٔ سلب مسئولیت';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsTheme => 'پوسته';

  @override
  String get toggleOn => 'روشن';

  @override
  String get toggleOff => 'خاموش';

  @override
  String get textSizeLarge => 'بزرگ';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تاریک';

  @override
  String todaySemantics(String dose, String breakdown) {
    return 'امروز، $dose میلی‌گرم: $breakdown. هنوز مصرف نشده.';
  }

  @override
  String todaySemanticsTaken(String dose, String breakdown) {
    return 'امروز، $dose میلی‌گرم: $breakdown. مصرف شد.';
  }

  @override
  String get ckbWeekdayNames =>
      'دوشنبه|سه‌شنبه|چهارشنبه|پنج‌شنبه|جمعه|شنبه|یکشنبه';

  @override
  String get ckbMonthNames =>
      'ژانویه|فوریه|مارس|آوریل|مه|ژوئن|ژوئیه|اوت|سپتامبر|اکتبر|نوامبر|دسامبر';

  @override
  String get unknownRouteTitle => 'چنین صفحه‌ای وجود ندارد';

  @override
  String get unknownRouteAction => 'رفتن به امروز';

  @override
  String get shellStorageError =>
      'تنظیمات شما بارگذاری نشد، بنابراین برنامه از مقادیر پیش‌فرض استفاده می‌کند.';

  @override
  String doseNotAchievable(Object dose) {
    return 'با قرص‌هایی که دارید ساخته نمی‌شود: $dose میلی‌گرم';
  }

  @override
  String holdingAtDose(Object dose) {
    return 'ثابت روی $dose';
  }

  @override
  String nDaysNotTicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روز گذشته ثبت نشده است',
    );
    return '$_temp0';
  }

  @override
  String get stepFinishedExplainer =>
      'روزهای این گام تمام شد. دوز شما تا شروع گام بعدی همین‌جا می‌ماند.';

  @override
  String get startNextStep => 'شروع گام بعدی';

  @override
  String get holdNeedsActiveStep => 'گامی در جریان نیست که متوقف شود';

  @override
  String get markTaken => 'ثبت مصرف امروز';

  @override
  String takenAt(Object time) {
    return 'مصرف شد ساعت $time';
  }

  @override
  String get markedAsTaken => 'به عنوان مصرف‌شده ثبت شد';

  @override
  String contextLineSemantics(
    Object step,
    Object total,
    Object from,
    Object to,
    Object day,
    Object length,
  ) {
    return 'گام $step از $total، کاهش از $from به $to، روز $day از $length';
  }

  @override
  String todaySemanticsNewDose(Object dose, Object breakdown) {
    return 'امروز، $dose میلی‌گرم: $breakdown. روز دوز جدید. هنوز مصرف نشده.';
  }

  @override
  String get flareTitle => 'ثبت عود';

  @override
  String get flarePickDose => 'بازگشت به دوزی که مؤثر بود';

  @override
  String get flareHistoryKept =>
      'تاریخچه و مجموع شما تا امروز نگه داشته می‌شود. روزهای از امروز به بعد از این دوز بازسازی می‌شوند.';

  @override
  String get flareConfirm => 'ثبت عود';

  @override
  String flareDateRange(Object dose, Object from, Object to) {
    return '$dose — از $from تا $to';
  }

  @override
  String get flareNoHistory =>
      'هنوز گامی را تمام نکرده‌اید، پس دوز قبلی برای بازگشت وجود ندارد.';

  @override
  String get holdTitle => 'ماندن روی این دوز';

  @override
  String get holdExtraDays => 'روزهای بیشتر';

  @override
  String holdConsequence(Object dose, Object days) {
    return 'شما $days روز دیگر روی $dose می‌مانید. گام رها نمی‌شود و چیزی از دست نمی‌رود.';
  }

  @override
  String get holdConfirm => 'ماندن';

  @override
  String get noteTitle => 'یادداشت امروز';

  @override
  String get noteHint => 'امروز چطور بود؟';

  @override
  String get noteSave => 'ذخیره یادداشت';

  @override
  String get taperCompleteTitle => 'به هدف خود رسیدید';

  @override
  String get taperCompleteBody =>
      'کاهش دوز شما به پایان رسید. همچنان دستورات پزشکتان را دنبال کنید.';

  @override
  String get noPlanHeading => 'برنامه شما از اینجا شروع می‌شود';

  @override
  String get noPlanBody =>
      'برنامه‌ای را که با پزشکتان توافق کرده‌اید اضافه کنید تا این صفحه هر صبح نشان دهد چه باید مصرف کنید.';

  @override
  String get noPlanAction => 'برنامه‌ام را تنظیم کن';

  @override
  String get errorTitle => 'در خواندن برنامه شما مشکلی پیش آمد';

  @override
  String get errorRetry => 'دوباره تلاش کنید';

  @override
  String get actionNotNow => 'حالا نه';

  @override
  String get backfillAction => 'اکنون ثبت کن';

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
      other: '$leadCount روز با $leadDose',
    );
    String _temp1 = intl.Intl.pluralLogic(
      restCount,
      locale: localeName,
      other: '$restCount روز با $restDose',
    );
    return '$_temp0، سپس $_temp1';
  }

  @override
  String steadyStateTitle(Object dose) {
    return 'ثابت روی $dose';
  }

  @override
  String get held => 'متوقف';

  @override
  String heldAtBlock(int block) {
    return 'متوقف در بلوک $block';
  }

  @override
  String get pastStepReadOnly => 'این گام تمام شده و قابل تغییر نیست';

  @override
  String get jumpToToday => 'پرش به امروز';

  @override
  String get futureDayNotYet => 'روزی که هنوز نرسیده را نمی‌توان ثبت کرد';

  @override
  String get stepSwitcherTitle => 'انتخاب گام';

  @override
  String stepRangeLabel(int index, int total, Object from, Object to) {
    return 'گام $index از $total — $from به $to';
  }

  @override
  String scheduleDaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return '$day، $dose میلی‌گرم: $breakdown.$notes';
  }

  @override
  String get scheduleNoteNewDose => ' روز دوز جدید.';

  @override
  String scheduleNoteHeld(int block) {
    return ' نگه‌داشته شده، یک روز اضافه در مرحله $block.';
  }

  @override
  String get scheduleNoteHeldNoBlock => ' نگه‌داشته شده، یک روز اضافه.';

  @override
  String scheduleNoteState(Object state) {
    return ' $state.';
  }

  @override
  String get scheduleNoteUnachievable =>
      ' این دوز با قرص‌هایی که دارید ساخته نمی‌شود.';

  @override
  String scheduleTodaySemantics(
    Object day,
    Object dose,
    Object breakdown,
    Object notes,
  ) {
    return 'امروز. $day، $dose میلی‌گرم: $breakdown.$notes';
  }
}
