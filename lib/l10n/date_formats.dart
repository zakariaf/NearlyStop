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

String _jalaliLabel(LocalDate date, Locale locale) {
  final jalali = Jalali.fromDateTime(date.toUtcMidnight());
  final day = _localizedInt(jalali.day, locale);
  return '$day ${jalali.formatter.mN}';
}

String _kurdishLabel(LocalDate date, Locale locale) {
  final l10n = lookupAppLocalizations(locale);
  final bridged = date.toUtcMidnight();
  // `DateTime.weekday` is 1 for Monday, and the ARB list is Monday-first.
  final weekday = l10n.ckbWeekdayNames.split('|')[bridged.weekday - 1];
  final month = l10n.ckbMonthNames.split('|')[bridged.month - 1];
  return '$weekday، ${_localizedInt(bridged.day, locale)} $month';
}

/// An integer in the locale's own digits.
///
/// Routed through [numberFormatFor] rather than a hand-written digit map: the
/// map gets the separator wrong, and `ckb` silently falls back to Latin without
/// the pin that function carries.
String _localizedInt(int value, Locale locale) =>
    numberFormatFor(locale).format(value);
