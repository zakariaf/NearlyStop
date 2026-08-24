/// Localized dates, projected from canonical `LocalDate`s.
///
/// **All taper arithmetic runs on `LocalDate`** (EPIC-04) — block boundaries,
/// the 52-day step, the alternating days, the 780-day horizon. Jalali is a
/// projection applied in the last function before the pixels, never a calendar
/// anything is computed in.
///
/// **The display bridge is UTC-only.** Every function here takes a `LocalDate`
/// and reaches `DateFormat`/`Jalali` through `LocalDate.toUtcMidnight()` — a
/// `DateTime` in UTC that exists *only* so those APIs can read the Y/M/D
/// fields. Constructing a *local* instant from a `LocalDate` is banned: it is
/// how a date label lands one day off for everyone east of UTC, on the screen
/// where the patient checks which day they are on.
///
/// **`ckb` has no `intl` date symbols**, so `DateFormat('ckb')` throws. The v1
/// decision, and the reasons:
/// * Borrowing `ar` symbols was rejected — `ar` emits U+066x digits, which
///   would put two different digit blocks in one date string.
/// * Borrowing `fa` symbols was rejected — most Sorani speakers are in Iraqi
///   Kurdistan and use the **Gregorian** calendar, so a Jalali date would be
///   wrong rather than merely unidiomatic.
/// So Kurdish dates are composed from the app's own ARB (`ckbWeekdayNames`,
/// `ckbMonthNames`) with digits from the `fa` number formatter. The cost is
/// real and stated: those two lists are maintained by hand.
library;

import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// The Jalali `(year, month, day)` for [date].
///
/// Exposed so the leap-year boundary can be pinned by test. The Jalali leap
/// cycle has irregular exceptions; `shamsi_date` is a dependency rather than an
/// exercise precisely because a hand-rolled converter is right for a year and
/// then quietly wrong somewhere inside a 780-day taper.
(int, int, int) jalaliParts(LocalDate date) {
  final jalali = Jalali.fromDateTime(date.toUtcMidnight());
  return (jalali.year, jalali.month, jalali.day);
}

/// A short weekday-and-day label, e.g. the Schedule screen's row heading.
String formatDayLabel(LocalDate date, Locale locale) =>
    switch (locale.languageCode) {
      'fa' => _jalaliLabel(date, locale),
      'ckb' => _kurdishLabel(date, locale),
      _ => DateFormat.MMMEd(locale.languageCode).format(date.toUtcMidnight()),
    };

/// The full weekday-and-date line, e.g. Today's "Wednesday 16 April".
///
/// Longer than [formatDayLabel] on purpose: a schedule ROW is scanned in a
/// column of fifty others and wants the short form, while the Today screen has
/// one date on it and is read at arm's length without glasses.
///
/// No year. The reader knows what year it is, and the one number that must not
/// have to compete for attention on this screen is the dose.
String formatFullDayLabel(LocalDate date, Locale locale) =>
    switch (locale.languageCode) {
      // Both already render weekday + day + month name in full.
      'fa' => _jalaliLabel(date, locale),
      'ckb' => _kurdishLabel(date, locale),
      _ => DateFormat(
        'EEEE d MMMM',
        locale.languageCode,
      ).format(date.toUtcMidnight()),
    };

/// A time of day, in the app's locale rather than the phone's.
///
/// **Not `DateFormat.jm(locale.toLanguageTag())`.** That was the shipped bug:
/// Sorani's tag is `ckb-Arab`, `intl` rejects it outright, and Settings died
/// red the moment somebody picked Kurdish. The same call would have thrown for
/// `fa` too — the launch loads symbol data for `en` and `de` only, on purpose,
/// and a locale without it raises rather than falling back.
///
/// So the two Perso-Arabic locales are composed here, on a 24-hour clock,
/// which is what both communities read.
String formatTimeOfDay(int hour, int minute, Locale locale) =>
    switch (locale.languageCode) {
      'fa' || 'ckb' => _clock24(hour, minute, locale),
      // `languageCode`, never the tag: the same trap one line up.
      _ => DateFormat.jm(
        locale.languageCode,
      ).format(DateTime.utc(2000, 1, 1, hour, minute)),
    };

/// `۰۹:۰۵` — padded, in the locale's own digits.
String _clock24(int hour, int minute, Locale locale) {
  final numbers = numberFormatFor(locale)..minimumIntegerDigits = 2;
  return '${numbers.format(hour)}:${numbers.format(minute)}';
}

/// The day's NAME on its own — "Wednesday", "چهارشنبه".
///
/// The doctor's export carries `date` and `weekday` as two columns: one a
/// machine parses, one a person reads. A weekday cell that repeats the date is
/// a wasted column in the only file this feature exists to produce.
///
/// `ckb` comes from the app's own ARB for the reason the library note above
/// gives: `DateFormat('ckb')` throws, and this is called on the path whose
/// whole job is to hand a file to a doctor.
String formatWeekdayName(LocalDate date, Locale locale) =>
    switch (locale.languageCode) {
      'fa' => Jalali.fromDateTime(date.toUtcMidnight()).formatter.wN,
      // `DateTime.weekday` is 1 for Monday, and the ARB list is Monday-first.
      'ckb' => _kurdishNames(locale).weekdays[date.toUtcMidnight().weekday - 1],
      _ => DateFormat.EEEE(locale.languageCode).format(date.toUtcMidnight()),
    };

String _jalaliLabel(LocalDate date, Locale locale) {
  final jalali = Jalali.fromDateTime(date.toUtcMidnight());
  final day = _localizedInt(jalali.day, locale);
  // The WEEKDAY is not optional. This label answers "which day am I on" on a
  // screen whose whole subject is a 52-day pattern that ignores weeks, and
  // Persian was the one locale rendering it without one.
  return '${jalali.formatter.wN}، $day ${jalali.formatter.mN}';
}

String _kurdishLabel(LocalDate date, Locale locale) {
  final names = _kurdishNames(locale);
  final bridged = date.toUtcMidnight();
  // `DateTime.weekday` is 1 for Monday, and the ARB list is Monday-first.
  final weekday = names.weekdays[bridged.weekday - 1];
  final month = names.months[bridged.month - 1];
  return '$weekday، ${_localizedInt(bridged.day, locale)} $month';
}

/// The two pipe-separated ARB lists, split once instead of once per row.
///
/// A Schedule scrolling a 780-day taper calls [formatDayLabel] for every
/// visible row on every frame; splitting a 7-element and a 12-element list each
/// time, to read one entry out of each, is work the screen does not need to do.
({List<String> weekdays, List<String> months}) _kurdishNames(Locale locale) =>
    _kurdishNameCache.putIfAbsent(locale.toLanguageTag(), () {
      final l10n = lookupAppLocalizations(locale);
      return (
        weekdays: List<String>.unmodifiable(l10n.ckbWeekdayNames.split('|')),
        months: List<String>.unmodifiable(l10n.ckbMonthNames.split('|')),
      );
    });

final Map<String, ({List<String> weekdays, List<String> months})>
_kurdishNameCache = <String, ({List<String> weekdays, List<String> months})>{};

/// An integer in the locale's own digits.
///
/// Routed through [numberFormatFor] rather than a hand-written digit map: the
/// map gets the separator wrong, and `ckb` silently falls back to Latin without
/// the pin that function carries.
String _localizedInt(int value, Locale locale) =>
    numberFormatFor(locale).format(value);

/// A month and year, e.g. the chart's axis ends: "Sep 2024".
///
/// Jalali for `fa` and Gregorian for `ckb`, exactly as [formatDayLabel] is —
/// the calendar follows the script's community, not the script.
String formatMonthLabel(LocalDate date, Locale locale) =>
    switch (locale.languageCode) {
      'fa' => _jalaliMonthLabel(date, locale),
      'ckb' => _kurdishMonthLabel(date, locale),
      _ => DateFormat.yMMM(locale.languageCode).format(date.toUtcMidnight()),
    };

String _jalaliMonthLabel(LocalDate date, Locale locale) {
  final jalali = Jalali.fromDateTime(date.toUtcMidnight());
  return '${jalali.formatter.mN} ${_localizedInt(jalali.year, locale)}';
}

String _kurdishMonthLabel(LocalDate date, Locale locale) {
  final bridged = date.toUtcMidnight();
  final names = _kurdishNames(locale);
  return '${names.months[bridged.month - 1]} '
      '${_localizedInt(bridged.year, locale)}';
}
