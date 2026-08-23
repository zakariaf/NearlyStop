@Tags(<String>['golden'])
library;

// Frame 5 — the Plan screen — as a GATE, not a driver.
//
// Eight captures: {light, dark} × {en, fa} × {1.0, 2.0}, over the one pinned
// fixture every UI epic renders. A golden of a screen showing a DIFFERENT plan
// than the parity sheets would make the two incomparable.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../fixtures/seeded_plan.dart';
import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpFrame(
    WidgetTester tester, {
    required String languageCode,
    required Brightness brightness,
    required double scale,
  }) async {
    await pumpApp(
      tester,
      const PlanScreen(),
      overrides: <Override>[
        // The snapshot, not a database: a golden must not depend on drift's
        // stream timing, and this screen reads nothing else from storage.
        taperSnapshotProvider.overrideWith(
          (ref) => Stream<Result<TaperSnapshot, StorageFailure>>.value(
            Ok<TaperSnapshot, StorageFailure>(seededSnapshot()),
          ),
        ),
        todayDateProvider.overrideWithValue(seededToday),
        clockProvider.overrideWithValue(Clock.fixed(seededNow)),
        resolvedLocaleProvider.overrideWithValue(Locale(languageCode)),
      ],
      locale: Locale(languageCode),
      brightness: brightness,
      textScaler: TextScaler.linear(scale),
      surfaceSize: Size(390, scale == 1 ? 1500 : 3200),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'plan_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpFrame(
            tester,
            languageCode: languageCode,
            brightness: brightness,
            scale: scale,
          );

          await expectLater(
            find.byType(PlanScreen),
            matchesGoldenFile('goldens/$name.png'),
          );

          // Unmounted INSIDE the body: the screen holds a stream subscription
          // whose cancellation schedules a zero-duration timer, and the
          // pending-timer assertion runs before `addTearDown`.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
