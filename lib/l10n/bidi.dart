/// Bidi isolation for the mixed-direction runs this app produces.
///
/// Pure Dart on purpose — no `dart:ui`, no Flutter `TextDirection` — so it
/// stays at the cheapest test tier and EPIC-13's export can call it without
/// pulling in a widget layer.
///
/// **The problem, concretely.** The tablet breakdown is
/// `1 × 5mg · 2 × 1mg · ½ × 1mg`: a run of digits and a Latin unit inside a
/// Perso-Arabic sentence. Unisolated, the bidi algorithm reorders it — the
/// counts and the strengths swap places, and the patient reads the wrong
/// number of the wrong tablet. The same applies to the context line
/// `10mg → 9mg` and to the drug name, which is free text the user typed and may
/// be Latin inside a Kurdish UI.
///
/// **Known-direction isolates, never FSI.** First-strong (`U+2068`) guesses
/// from the first strongly-directional character, and the breakdown begins with
/// a digit or a `½` — neither of which is strong, so FSI guesses from whatever
/// comes next and gets it wrong exactly when it matters. The caller knows the
/// direction; it should say so.
///
/// **Never the legacy embeddings** (`U+202A`–`U+202E`). They do not nest, and
/// an unterminated one leaks past the end of the value into the rest of the
/// sentence.
///
/// **The isolated value is always an ARB placeholder**, never a hard-spliced
/// substring: `l10n.tabletBreakdown(isolateLtr(parts))`, not
/// `'${l10n.prefix}${isolateLtr(parts)}'`. And isolate characters must never
/// reach the database, an export or a search — [stripIsolates] at that
/// boundary, which is why EPIC-13 consumes this file.
library;

/// U+2066 LEFT-TO-RIGHT ISOLATE.
const String lri = '\u2066';

/// U+2067 RIGHT-TO-LEFT ISOLATE.
const String rli = '\u2067';

/// U+2068 FIRST STRONG ISOLATE. Declared so it can be asserted ABSENT.
const String fsi = '\u2068';

/// U+2069 POP DIRECTIONAL ISOLATE.
const String pdi = '\u2069';

/// Wraps [value] as a left-to-right run.
///
/// Idempotent: a value that is already isolated is returned unchanged, because
/// the realistic misuse is a view layer isolating what a helper isolated
/// already, and doubling up is invisible until it reaches an export.
String isolateLtr(String value) => _isolate(value, lri);

/// Wraps [value] as a right-to-left run.
String isolateRtl(String value) => _isolate(value, rli);

String _isolate(String value, String opening) =>
    _isAlreadyOneIsolate(value, opening) ? value : '$opening$value$pdi';

/// True when [value] is a SINGLE isolate opened by [opening].
///
/// `startsWith(opening) && endsWith(pdi)` is not enough: it is also true of two
/// isolated runs joined together, and the tablet breakdown is built by joining
/// per-tablet parts. Skipping the outer isolate there lets the whole run
/// reorder inside a Perso-Arabic sentence — the wrong count against the wrong
/// strength. Depth-counting is what tells the two cases apart.
bool _isAlreadyOneIsolate(String value, String opening) {
  if (!value.startsWith(opening) || !value.endsWith(pdi)) return false;
  var depth = 0;
  var index = 0;
  for (final rune in value.runes) {
    if (rune >= 0x2066 && rune <= 0x2068) {
      depth++;
    } else if (rune == 0x2069) {
      depth--;
      // Closed before the end: this is a concatenation, not one isolate.
      if (depth == 0 && index != value.runes.length - 1) return false;
    }
    index++;
  }
  return depth == 0;
}

/// Removes every invisible bidi control from [value], leaving all else
/// identical.
///
/// The boundary call. A control character in a CSV field, a database write or a
/// search query is invisible in review and silently corrupts the value —
/// two names that look identical stop comparing equal.
///
/// It strips more than the isolates this file writes, on purpose. A medicine
/// name is free text the user typed or pasted, and text pasted from a web page
/// or a PDF commonly carries LRM/RLM (U+200E–200F) or a stray legacy embedding
/// (U+202A–202E) — the very characters this file's header calls dangerous.
/// Stripping only what we ourselves added would leave exactly those in place.
String stripIsolates(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final isMark = rune >= 0x200E && rune <= 0x200F;
    final isLegacyEmbedding = rune >= 0x202A && rune <= 0x202E;
    final isIsolate = rune >= 0x2066 && rune <= 0x2069;
    if (isMark || isLegacyEmbedding || isIsolate) continue;
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}
