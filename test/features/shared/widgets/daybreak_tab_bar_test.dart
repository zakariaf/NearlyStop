// The five destinations, and the three signals that say which one you are on.
//
// This bar is looked at every morning for roughly 780 days. "Which tab am I
// on" has to be answerable by someone who cannot distinguish coral from taupe,
// from a greyscale printout, and from a screen reader — so it is a pill, a
// filled icon variant, and a weight, never a tint alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tab_bar.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  /// The five destinations, with a long-string locale's labels where asked.
  List<DaybreakDestination> destinationsFor(String languageCode) {
    const german = <String>[
      'Heute',
      'Zeitplan',
      'Fortschritt',
      'Behandlungsplan',
      'Einstellungen',
    ];
    const persian = <String>[
      'امروز',
      'برنامه زمانی',
      'پیشرفت',
      'برنامه درمان',
      'تنظیمات',
    ];
    const english = <String>[
      'Today',
      'Schedule',
      'Progress',
      'Plan',
      'Settings',
    ];
    final labels = switch (languageCode) {
      'de' => german,
      'fa' => persian,
      _ => english,
    };
    const outlined = <IconData>[
      Icons.wb_sunny_outlined,
      Icons.view_agenda_outlined,
      Icons.trending_down_outlined,
      Icons.medication_outlined,
      Icons.settings_outlined,
    ];
    const filled = <IconData>[
      Icons.wb_sunny,
      Icons.view_agenda,
      Icons.trending_down,
      Icons.medication,
      Icons.settings,
    ];
    return <DaybreakDestination>[
      for (var i = 0; i < labels.length; i++)
        DaybreakDestination(
          label: labels[i],
          icon: outlined[i],
          selectedIcon: filled[i],
        ),
    ];
  }

  Future<void> pumpBar(
    WidgetTester tester, {
    int selected = 0,
    void Function(int)? onSelected,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size surfaceSize = const Size(390, 844),
    EdgeInsets padding = const EdgeInsets.only(bottom: 26),
    bool rail = false,
  }) => pumpApp(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: Material(
          child: rail
              ? Row(
                  children: <Widget>[
                    DaybreakNavigationRail(
                      destinations: destinationsFor(locale.languageCode),
                      selectedIndex: selected,
                      onDestinationSelected: onSelected ?? (_) {},
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                )
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: DaybreakTabBar(
                    destinations: destinationsFor(locale.languageCode),
                    selectedIndex: selected,
                    onDestinationSelected: onSelected ?? (_) {},
                  ),
                ),
        ),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    surfaceSize: surfaceSize,
  );

  testWidgets('tapping destination i reports i, exactly once, for all five', (
    tester,
  ) async {
    for (var index = 0; index < 5; index++) {
      final reported = <int>[];
      await pumpBar(tester, onSelected: reported.add);

      await tester.tap(find.text(destinationsFor('en')[index].label));
      await tester.pumpAndSettle();

      expect(reported, <int>[index]);
    }
  });

  testWidgets('the active destination carries all THREE signals', (
    tester,
  ) async {
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return Material(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: DaybreakTabBar(
                destinations: destinationsFor('en'),
                selectedIndex: 2,
                onDestinationSelected: (_) {},
              ),
            ),
          );
        },
      ),
      surfaceSize: const Size(390, 844),
    );

    for (var index = 0; index < 5; index++) {
      final destination = destinationsFor('en')[index];
      final active = index == 2;
      final label = tester.widget<Text>(find.text(destination.label));

      // 1: the weight, 2: the colour, 3: the filled icon variant.
      expect(
        label.style!.fontWeight,
        active ? FontWeight.w800 : FontWeight.w600,
        reason: destination.label,
      );
      expect(
        label.style!.color,
        active ? colors.primaryDeep : colors.inkMuted,
        reason: destination.label,
      );
      expect(
        find.byIcon(active ? destination.selectedIcon : destination.icon),
        findsOneWidget,
        reason: destination.label,
      );
    }

    // And the pill BEHIND the active icon, measured.
    expect(
      tester.getSize(find.byKey(DaybreakTabBar.activePillKey)),
      const Size(52, 30),
    );
  });

  testWidgets('there is NO indicator bar', (tester) async {
    // This epic invented a 3px indicator that the reference does not have —
    // `.tab[aria-current]` tints the icon capsule instead. Asserted as an
    // absence so it cannot come back.
    await pumpBar(tester, selected: 1);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(
      find.byKey(DaybreakTabBar.activePillKey),
      findsOneWidget,
      reason: 'the pill IS the indicator',
    );
  });

  testWidgets('all five labels stay visible in de at 360dp and 2.0', (
    tester,
  ) async {
    for (final scale in <double>[1, 2]) {
      await pumpBar(
        tester,
        locale: const Locale('de'),
        textScaler: TextScaler.linear(scale),
        surfaceSize: const Size(360, 900),
      );

      for (final destination in destinationsFor('de')) {
        expect(
          find.text(destination.label),
          findsOneWidget,
          reason: '${destination.label} at $scale',
        );
        expect(
          tester.widget<Text>(find.text(destination.label)).overflow,
          isNot(TextOverflow.ellipsis),
          reason: destination.label,
        );

        // VISIBLE, not merely present. `find.text` succeeds on a label that
        // has been clipped to a quarter of itself, and `Flexible` around a
        // `Text` clips SILENTLY — no overflow stripe, no exception. Measured
        // at 2.0 before this assertion existed: "Behandlungsplan" wanted 164pt
        // of height inside a bar that gave it 36.
        //
        // The oracle is an independent `TextPainter` at the destination's own
        // width, so it does not agree with whatever the bar decided.
        final rendered = tester.getSize(find.text(destination.label));
        final wanted = (TextPainter(
          text: TextSpan(
            text: destination.label,
            style: tester.widget<Text>(find.text(destination.label)).style,
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout(maxWidth: rendered.width)).size;
        expect(
          rendered.height,
          greaterThanOrEqualTo(wanted.height),
          reason: '${destination.label} at $scale was clipped',
        );
      }
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });

  testWidgets('96 tall over a 26pt inset, and every target clears 44x52', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(tester.getSize(find.byType(DaybreakTabBar)).height, 96);
    for (final destination in destinationsFor('en')) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(destination.label),
          matching: find.byType(DaybreakTabDestination),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(44), reason: destination.label);
      expect(size.height, greaterThanOrEqualTo(52), reason: destination.label);
    }
  });

  testWidgets('it clears the tap-target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('in fa the first destination is on the RIGHT', (tester) async {
    // Measured, not eyeballed.
    await pumpBar(tester, locale: const Locale('fa'));

    final first = tester.getCenter(
      find.text(destinationsFor('fa').first.label),
    );
    expect(first.dx, greaterThan(390 / 2));
  });

  testWidgets('the rail carries the SAME three signals', (tester) async {
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return Material(
            child: Row(
              children: <Widget>[
                DaybreakNavigationRail(
                  destinations: destinationsFor('en'),
                  selectedIndex: 3,
                  onDestinationSelected: (_) {},
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          );
        },
      ),
      surfaceSize: const Size(800, 600),
    );

    for (var index = 0; index < 5; index++) {
      final destination = destinationsFor('en')[index];
      final active = index == 3;
      final label = tester.widget<Text>(find.text(destination.label));
      expect(
        label.style!.fontWeight,
        active ? FontWeight.w800 : FontWeight.w600,
      );
      expect(label.style!.color, active ? colors.primaryDeep : colors.inkMuted);
      expect(
        find.byIcon(active ? destination.selectedIcon : destination.icon),
        findsOneWidget,
      );
    }
    expect(find.byKey(DaybreakTabBar.activePillKey), findsOneWidget);
  });

  testWidgets('the rail reports the tapped index too', (tester) async {
    final reported = <int>[];
    await pumpBar(
      tester,
      rail: true,
      onSelected: reported.add,
      surfaceSize: const Size(800, 600),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(reported, <int>[4]);
  });
}
