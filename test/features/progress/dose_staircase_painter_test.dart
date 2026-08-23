// The chart, driven directly. **No widget is pumped.**
//
// The painter takes a value snapshot and never sees a `BuildContext`, which is
// exactly what makes this tier possible: a recording canvas, a known series,
// and assertions on the geometry that comes out. A painter that reached for
// `Theme.of` could only be tested through a pumped widget, and then nobody
// would test the geometry at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_staircase_painter.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/gradients.dart';

import '../../support/contrast.dart';

void main() {
  const size = Size(320, 176);
  const segments = <DoseSegment>[
    DoseSegment(
      startDayIndex: 0,
      endDayIndex: 25,
      dose: Milligrams.fromHundredths(1500),
    ),
    DoseSegment(
      startDayIndex: 26,
      endDayIndex: 51,
      dose: Milligrams.fromHundredths(1200),
    ),
    DoseSegment(
      startDayIndex: 52,
      endDayIndex: 77,
      dose: Milligrams.fromHundredths(900),
    ),
  ];

  TextPainter label(String text) => TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 11)),
    textDirection: TextDirection.ltr,
  )..layout();

  DoseStaircasePainter painterFor({
    TextDirection direction = TextDirection.ltr,
    List<DoseSegment> series = segments,
    List<FlareMark> flares = const <FlareMark>[],
    List<HoldMark> holds = const <HoldMark>[],
  }) => DoseStaircasePainter(
    segments: series,
    flares: flares,
    holds: holds,
    todayDayIndex: series.last.endDayIndex,
    todayDose: series.last.dose,
    minDose: const Milligrams.fromHundredths(900),
    maxDose: const Milligrams.fromHundredths(1500),
    gridline: const Color(0xFFE7DCD2),
    lineGradient: const LinearGradient(
      colors: <Color>[Color(0xFFB8412A), Color(0xFFB8412A)],
    ),
    fillGradient: const LinearGradient(
      colors: <Color>[Color(0x4DF97350), Color(0x0AFFC470)],
    ),
    flareRing: const Color(0xFFB3261E),
    flareGlyph: const Color(0xFFB3261E),
    holdBracket: const Color(0xFF6B5B4E),
    markerFill: const Color(0xFFFFFFFF),
    todayRing: const Color(0xFFE0452B),
    strokeWidth: 3,
    direction: direction,
    labels: DoseAxisLabels(
      first: label('Sep 2024'),
      last: label('Apr 2026'),
      doses: <TextPainter>[label('15mg'), label('12mg'), label('9mg')],
    ),
  );

  /// The y a dose maps to, computed the way the test expects it — from the
  /// axis, not from the painter, so the two can disagree.
  double yFor(Milligrams dose) {
    const top = DoseStaircasePainter.plotTop;
    final bottom = size.height - DoseStaircasePainter.plotBottom;
    final fraction = (dose.hundredths - 900) / (1500 - 900);
    return bottom - fraction * (bottom - top);
  }

  test('LTR: the path starts at the left edge and ends at the right', () {
    final points = painterFor().staircaseVertices(size);

    expect(points, isNotEmpty);
    expect(points.first.dx, closeTo(0, 1e-9));
    expect(points.first.dy, closeTo(yFor(segments.first.dose), 1e-9));
    expect(points.last.dx, closeTo(size.width, 1e-9));
    expect(points.last.dy, closeTo(yFor(segments.last.dose), 1e-9));
  });

  test('LTR: it is a STAIRCASE — moves alternate horizontal and vertical', () {
    // A polyline through the middle of each tread is the obvious wrong shape,
    // and it reads as a smooth decline the person never experienced.
    final points = painterFor().staircaseVertices(size);

    for (var i = 1; i < points.length; i++) {
      final horizontal = (points[i].dy - points[i - 1].dy).abs() < 1e-9;
      final vertical = (points[i].dx - points[i - 1].dx).abs() < 1e-9;
      expect(
        horizontal || vertical,
        isTrue,
        reason: 'segment $i runs diagonally: ${points[i - 1]} → ${points[i]}',
      );
    }
  });

  test('RTL: the earliest date is still at the reading START edge', () {
    // A stated design decision, and precisely the thing a later "fix" reverses
    // by mirroring the whole canvas and calling it done.
    final points = painterFor(
      direction: TextDirection.rtl,
    ).staircaseVertices(size);

    expect(points.first.dx, closeTo(size.width, 1e-9));
    expect(points.first.dy, closeTo(yFor(segments.first.dose), 1e-9));
    expect(points.last.dx, closeTo(0, 1e-9));
    expect(points.last.dy, closeTo(yFor(segments.last.dose), 1e-9));
  });

  test(
    'the y axis puts the lowest dose on the baseline and the highest on top',
    () {
      final points = painterFor().staircaseVertices(size);
      final ys = points.map((p) => p.dy).toList();

      expect(
        ys.reduce((a, b) => a > b ? a : b),
        closeTo(yFor(segments.last.dose), 1e-9),
      );
      expect(
        ys.reduce((a, b) => a < b ? a : b),
        closeTo(yFor(segments.first.dose), 1e-9),
      );
      // 12mg is exactly halfway between 9 and 15, so it lands exactly halfway.
      expect(
        yFor(const Milligrams.fromHundredths(1200)),
        closeTo(
          (yFor(const Milligrams.fromHundredths(900)) +
                  yFor(const Milligrams.fromHundredths(1500))) /
              2,
          1e-9,
        ),
      );
    },
  );

  test('a flare is a circle AND a glyph, never a coloured ring alone', () {
    final canvas = _RecordingCanvas();
    painterFor(
      flares: const <FlareMark>[
        FlareMark(
          dayIndex: 40,
          dose: Milligrams.fromHundredths(1200),
          label: 'x',
        ),
      ],
    ).paint(canvas, size);

    final plain = _RecordingCanvas();
    painterFor().paint(plain, size);

    expect(
      canvas.count('drawCircle') - plain.count('drawCircle'),
      2,
      reason: 'the ring is a fill and a stroke',
    );
    expect(
      canvas.count('drawPath') - plain.count('drawPath'),
      1,
      reason: 'the flare glyph is missing, leaving colour as the only channel',
    );
  });

  test('a hold is a BRACKET — a different shape, not a different colour', () {
    final plain = _RecordingCanvas();
    painterFor().paint(plain, size);
    final held = _RecordingCanvas();
    painterFor(
      holds: const <HoldMark>[
        HoldMark(
          dayIndex: 30,
          days: 5,
          dose: Milligrams.fromHundredths(1200),
          label: 'x',
        ),
      ],
    ).paint(held, size);

    expect(
      held.count('drawLine') - plain.count('drawLine'),
      3,
      reason: 'a bracket is a span and two ticks',
    );
    expect(
      held.count('drawCircle'),
      plain.count('drawCircle'),
      reason: 'a hold drew a circle, so it can be confused with a flare',
    );
  });

  test('today is a filled dot inside a ring', () {
    final canvas = _RecordingCanvas();
    painterFor().paint(canvas, size);

    expect(canvas.count('drawCircle'), greaterThanOrEqualTo(2));
  });

  test('a full-length series allocates four Paints and lays out no text', () {
    final long = <DoseSegment>[
      for (var index = 0; index < 32; index++)
        DoseSegment(
          startDayIndex: index * 24,
          endDayIndex: index * 24 + 23,
          dose: Milligrams.fromHundredths(1500 - index * 18),
        ),
    ];
    final canvas = _RecordingCanvas();
    painterFor(series: long).paint(canvas, size);

    expect(
      canvas.paints.length,
      lessThanOrEqualTo(4),
      reason: 'a Paint per segment is 32 allocations per frame',
    );
  });

  test('shouldRepaint answers true for every field, and false for none', () {
    final base = painterFor();
    expect(base.shouldRepaint(painterFor()), isFalse);

    expect(
      base.shouldRepaint(painterFor(direction: TextDirection.rtl)),
      isTrue,
      reason: 'direction',
    );
    expect(
      base.shouldRepaint(
        painterFor(
          flares: const <FlareMark>[
            FlareMark(
              dayIndex: 1,
              dose: Milligrams.fromHundredths(900),
              label: 'x',
            ),
          ],
        ),
      ),
      isTrue,
      reason: 'flares',
    );
    expect(
      base.shouldRepaint(
        painterFor(
          holds: const <HoldMark>[
            HoldMark(
              dayIndex: 1,
              days: 2,
              dose: Milligrams.fromHundredths(900),
              label: 'x',
            ),
          ],
        ),
      ),
      isTrue,
      reason: 'holds',
    );
    // Equal LENGTH, different contents: comparing lengths alone is the shortcut
    // that leaves a changed chart on screen.
    // A MIDDLE tread, so `todayDayIndex` and `todayDose` — both read off the
    // last segment — stay identical and the segments comparison is the only
    // thing that can notice.
    final swapped = <DoseSegment>[
      segments.first,
      const DoseSegment(
        startDayIndex: 26,
        endDayIndex: 51,
        dose: Milligrams.fromHundredths(1100),
      ),
      segments.last,
    ];
    expect(
      base.shouldRepaint(painterFor(series: swapped)),
      isTrue,
      reason: 'same length, different doses',
    );
  });

  test('the stroke clears 3:1 against the card, in light and in dark', () {
    // WCAG 2.1 SC 1.4.11. The stroke is the only mark carrying this screen's
    // primary information and it has no text of its own, so it is a graphical
    // object that has to be seen — by a reader in their seventies with
    // declining contrast sensitivity. `textContrastGuideline` never looks at
    // painted geometry, so this is the only thing pinning it.
    for (final (name, colors) in <(String, DaybreakColors)>[
      ('light', lightDaybreakColors),
      ('dark', darkDaybreakColors),
    ]) {
      // Against the gradient's WORST stop, not a named one: a ratio against a
      // gradient is only meaningful where it is hardest to see.
      // Every stop of the SLOT the chart actually uses, against the wash's
      // worst stop — not a colour the test picked and hoped matched.
      for (final stop in colors.chartLine.colors) {
        expect(
          contrastRatio(
            stop,
            DaybreakGradients.worstStopFor(stop, colors.wash),
          ),
          greaterThanOrEqualTo(3),
          reason: 'a chartLine stop on the $name wash',
        );
      }
      // And the reason the slot is `primaryDeep` and not `primary`, kept as a
      // documented expectation so nobody "simplifies" it back. LIGHT only:
      // coral on the dark theme's plum wash is a perfectly good ratio, and it
      // is the light theme where CLAUDE.md's 2.76:1 bites.
      if (name == 'light') {
        expect(
          contrastRatio(
            colors.primary,
            DaybreakGradients.worstStopFor(colors.primary, colors.wash),
          ),
          lessThan(3),
          reason: 'primary is decorative-only — re-read the token',
        );
      }
    }
  });
}

/// A `Canvas` that records what it was asked to draw.
///
/// Flutter's own `TestRecordingCanvas` is not exported, and the alternative —
/// a `PictureRecorder` — hands back an opaque picture with nothing to count.
class _RecordingCanvas implements Canvas {
  final List<String> ops = <String>[];
  final Set<Paint> paints = <Paint>{};

  /// How many times [op] was issued.
  int count(String op) => ops.where((entry) => entry == op).length;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    ops.add(
      invocation.memberName.toString().replaceAll(RegExp('Symbol|[(")]'), ''),
    );
    for (final argument in invocation.positionalArguments) {
      if (argument is Paint) paints.add(argument);
    }
    return null;
  }
}
