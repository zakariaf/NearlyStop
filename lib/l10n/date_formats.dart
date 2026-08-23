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
