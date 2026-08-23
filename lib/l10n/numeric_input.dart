/// The one character set a dose field accepts.
library;

import 'package:flutter/services.dart';
import 'package:nearlystop/l10n/number_formats.dart';

/// The digit blocks [normalizeToAscii] knows how to read, as code points.
///
/// **Derived, never typed out.** `tool/check_bans.sh` rejects a hand-written
/// digit table anywhere in `lib/`, and it is right to: a table gets the
/// SEPARATOR wrong, and a formatter whose idea of a digit differs from the
/// parser's produces a field that accepts a character it then refuses — with
/// the person retyping it unable to see any difference.
///
/// These are the same three ranges `normalizeToAscii` walks, named by their
/// code points so the two cannot drift apart silently.
const List<(int, int)> kDigitBlocks = <(int, int)>[
  (0x30, 0x39), // ASCII
  (0x0660, 0x0669), // Arabic-Indic
  (0x06F0, 0x06F9), // Extended Arabic-Indic, used by fa and ckb
];

/// The decimal separators the app reads: `.`, `,` and U+066B.
const List<int> kDecimalSeparators = <int>[0x2E, 0x2C, 0x066B];

/// Whether [rune] may appear in a dose field.
bool isDoseCharacter(int rune) =>
    _isDigit(rune) || kDecimalSeparators.contains(rune);

/// The input formatter every WHOLE-NUMBER field uses — days, a percentage.
///
/// The same digit blocks, without the separators: a count has no decimal point,
/// and a field that accepts one produces `52.` for the parser to refuse.
final TextInputFormatter kWholeNumberInputFormatter = _keepOnly(_isDigit);

/// The input formatter every dose field uses.
///
/// A predicate rather than a character-class literal, so the set is the one
/// [isDoseCharacter] defines and there is nowhere for a second answer to live.
final TextInputFormatter kDoseInputFormatter = _keepOnly(isDoseCharacter);

/// Whether [rune] is a digit in any block this app reads.
bool _isDigit(int rune) {
  for (final (low, high) in kDigitBlocks) {
    if (rune >= low && rune <= high) return true;
  }
  return false;
}

/// A formatter that drops every rune [allowed] refuses.
TextInputFormatter _keepOnly(bool Function(int rune) allowed) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final kept = StringBuffer();
      for (final rune in newValue.text.runes) {
        if (allowed(rune)) kept.writeCharCode(rune);
      }
      final text = kept.toString();
      if (text == newValue.text) return newValue;
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: text.length < newValue.selection.end
              ? text.length
              : newValue.selection.end,
        ),
      );
    });
