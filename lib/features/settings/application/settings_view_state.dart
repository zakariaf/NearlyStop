/// The units the settings row is stored in, and the picker's options.
///
/// **Not a second settings notifier.** EPIC-06's `SettingsController` owns the
/// row and its write policy — the stream is the source of truth and nothing is
/// mutated optimistically, so a failed write simply never moves. What lives
/// here is the unit conversion and the projection, which EPIC-12 also reads.
library;

import 'package:flutter/material.dart';

/// The lowest in-app text scale the slider offers.
const double kMinTextScaleSetting = 1;

/// The highest.
const double kMaxTextScaleSetting = 2;

/// Minutes since LOCAL midnight, as a time of day.
///
/// Minutes, never a `DateTime` and never a UTC instant: EPIC-12 needs a wall
/// clock and a rule, and a stored instant drifts an hour across every DST
/// boundary — twice a year, at the hour somebody takes a steroid.
TimeOfDay minutesToTimeOfDay(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

/// A time of day, as minutes since local midnight.
int timeOfDayToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// Rounds a raw slider value onto the stored grid.
///
/// Tenths between 1.0 and 2.0. The column is a `double`, so a value from a
/// corrupt row or an older build is brought back onto the grid rather than
/// trusted.
double quantiseTextScale(double raw) {
  final bounded = raw.clamp(kMinTextScaleSetting, kMaxTextScaleSetting);
  return (bounded * 10).round() / 10;
}

/// The text size, as a word.
///
/// The reference frame says "Large", not "1.4". A multiplier is a number the
/// reader has to translate into an experience; the whole audience for this row
/// is people for whom that translation is the hard part.
enum TextSizeName {
  /// The OS size, unchanged.
  normal(kMinTextScaleSetting),

  /// A step up.
  large(1.2),

  /// Two steps up.
  larger(1.5),

  /// As large as the app goes on its own.
  largest(1.8);

  const TextSizeName(this.from);

  /// The smallest scale that carries this name.
  final double from;
}

/// The name for [scale].
///
/// Clamps at both ends rather than returning null: a slider cannot produce a
/// value outside its own range, but a stored setting written by an older
/// build can, and an unnamed size would render blank.
TextSizeName textSizeNameFor(double scale) {
  var result = TextSizeName.normal;
  for (final candidate in TextSizeName.values) {
    if (scale >= candidate.from) result = candidate;
  }
  return result;
}

/// What the language row can be set to.
///
/// Each option names itself **in its own script**. Never transliterated: the
/// person who needs this row is the one who cannot read the English label for
/// it, and until this epic the `localeTag` column had no control writing to it
/// at all (CONTRACTS §13).
enum LanguageSelection {
  /// Follow the phone. Stored as `null`.
  system(null, null),

  /// English.
  en('en', 'English'),

  /// German.
  de('de', 'Deutsch'),

  /// Persian.
  fa('fa', 'فارسی'),

  /// Kurdish Sorani.
  ckb('ckb', 'کوردیی ناوەندی');

  const LanguageSelection(this.tag, this.nativeName);

  /// The BCP-47 tag stored in the row, or null for [system].
  final String? tag;

  /// The language's own name, in its own script. Null for [system], whose
  /// label is a translated word rather than a language name.
  final String? nativeName;
}

/// The selection a stored tag projects to.
///
/// A tag this build does not ship falls back to [LanguageSelection.system]
/// rather than throwing: a settings row can outlive the build that wrote it.
LanguageSelection languageSelectionFor(String? tag) {
  if (tag == null) return LanguageSelection.system;
  for (final option in LanguageSelection.values) {
    if (option.tag == tag) return option;
  }
  return LanguageSelection.system;
}
