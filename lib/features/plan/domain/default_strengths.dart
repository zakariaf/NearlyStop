/// What a clean install starts with. `SPEC.md` §11.2.
///
/// **Not a drug database.** This is a starting list the person edits into what
/// they actually hold — the app never claims to know what is in their cupboard,
/// and a one-line note under the chips says so.
library;

import 'package:nearlystop/core/units/milligrams.dart';

/// A region's default drug name and tablet strengths.
final class RegionalDefaults {
  /// Creates the entry.
  const RegionalDefaults({required this.drugName, required this.strengths});

  /// The name on the bottle in that region.
  final String drugName;

  /// The strengths that region dispenses, sorted ascending.
  final List<Milligrams> strengths;
}

Milligrams _mg(num value) => Milligrams.fromHundredths((value * 100).round());

/// The table, keyed by `language` or `language_REGION`.
///
/// The drug NAME differs between regions and not just the list: the United
/// States prescribes prednisone where the United Kingdom prescribes
/// prednisolone, and an American reading the wrong one has been told the app
/// is for somebody else.
final Map<String, RegionalDefaults> kDefaultStrengths =
    <String, RegionalDefaults>{
      'en_US': RegionalDefaults(
        drugName: 'Prednisone',
        strengths: <Milligrams>[_mg(1), _mg(2.5), _mg(5), _mg(10), _mg(20)],
      ),
      'en': RegionalDefaults(
        drugName: 'Prednisolone',
        strengths: <Milligrams>[_mg(1), _mg(2.5), _mg(5)],
      ),
      'de': RegionalDefaults(
        drugName: 'Prednisolon',
        strengths: <Milligrams>[
          _mg(1),
          _mg(2),
          _mg(5),
          _mg(10),
          _mg(20),
          _mg(50),
        ],
      ),
      'fa': RegionalDefaults(
        drugName: 'Prednisolone',
        strengths: <Milligrams>[_mg(1), _mg(5)],
      ),
      'ckb': RegionalDefaults(
        drugName: 'Prednisolone',
        strengths: <Milligrams>[_mg(1), _mg(5)],
      ),
    };

/// The defaults for a language and optional region.
///
/// Falls back to the widest-shipping list rather than to nothing: a locale the
/// table has never heard of is still a person with a real prescription, and an
/// empty strength list means the first thing the app can say about their dose
/// is that it cannot be made.
RegionalDefaults defaultsFor(String language, String? region) =>
    kDefaultStrengths['${language}_$region'] ??
    kDefaultStrengths[language] ??
    kDefaultStrengths['en']!;
