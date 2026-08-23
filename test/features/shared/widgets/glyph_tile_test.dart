// The rounded tinted square a row's glyph sits in.
//
// The reference frames put every list glyph in one: a 44pt `tintPrimary`
// square with the glyph in `primaryDeep`. A bare icon on a white card is the
// same information at a third of the target size, and this audience taps with
// a thumb.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/glyph_tile.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpApp(
      tester,
      const Material(
        child: Center(child: GlyphTile(glyph: Icons.alarm)),
      ),
      brightness: brightness,
      textScaler: TextScaler.linear(scale),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it is a tinted square with the glyph inside', (tester) async {
    await pumpTile(tester);

    final context = tester.element(find.byType(GlyphTile));
    final colors = DaybreakColors.of(context);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(GlyphTile),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;

    expect(decoration.color, colors.tintPrimary);
    // `primaryDeep`, never `primary`: a glyph that carries meaning is held to
    // 3:1, and #F97350 measures 2.76 on this ground.
    expect(tester.widget<Icon>(find.byType(Icon)).color, colors.primaryDeep);
    expect(tester.getSize(find.byType(GlyphTile)).width, GlyphTile.side);
  });

  testWidgets('it grows with the text, so it never becomes a dot', (
    tester,
  ) async {
    await pumpTile(tester, scale: 2);

    expect(
      tester.getSize(find.byType(GlyphTile)).width,
      greaterThan(GlyphTile.side),
      reason: 'a fixed tile beside doubled text reads as a bullet point',
    );
  });

  testWidgets('it is decoration, and says so', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTile(tester);

    expect(
      find.descendant(
        of: find.byType(GlyphTile),
        matching: find.byType(Semantics),
      ),
      findsWidgets,
    );
    // The row's own label names it. A tile that announced "alarm" would make
    // every settings row read its icon out loud before its name.
    expect(tester.getSemantics(find.byType(GlyphTile)).label, isEmpty);
    handle.dispose();
  });
}
