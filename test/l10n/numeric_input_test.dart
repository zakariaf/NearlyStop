// What a dose field accepts, and what it silently drops.
//
// The invariant: the formatter and the normalizer agree about what a digit is.
// A field that accepts a character its parser then refuses is a field the
// person retypes without being able to see what is wrong.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/l10n/numeric_input.dart';

void main() {
  String filtered(String raw) => kDoseInputFormatter
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: raw,
          selection: TextSelection.collapsed(offset: raw.length),
        ),
      )
      .text;

  test('every digit the normalizer reads is a digit the field accepts', () {
    // The two walk the same three blocks. Swept rather than spot-checked,
    // because a block added to one and forgotten in the other is exactly the
    // drift this pins.
    for (final (low, high) in kDigitBlocks) {
      for (var rune = low; rune <= high; rune++) {
        final char = String.fromCharCode(rune);
        expect(filtered(char), char, reason: 'U+${rune.toRadixString(16)}');
        expect(
          normalizeToAscii(char),
          matches(RegExp(r'^[0-9]$')),
          reason: 'the normalizer cannot read U+${rune.toRadixString(16)}',
        );
      }
    }
  });

  test('the three decimal separators survive', () {
    for (final rune in kDecimalSeparators) {
      final char = String.fromCharCode(rune);
      expect(filtered('1${char}5'), '1${char}5', reason: char);
    }
  });

  test('letters and spaces are dropped as they are typed', () {
    expect(filtered('9.5mg'), '9.5');
    expect(filtered('abc'), '');
  });

  test('the accepted set is derived, not a literal in two places', () {
    // A character outside every declared block is refused, which is what makes
    // `kDigitBlocks` the definition rather than a comment about one.
    expect(isDoseCharacter(0x0663), isTrue);
    expect(isDoseCharacter(0x4E09), isFalse);
    expect(isDoseCharacter(0x2D), isFalse);
  });
}
