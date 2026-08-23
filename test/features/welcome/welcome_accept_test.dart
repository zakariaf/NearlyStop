// Accepting the disclaimer, and RE-READING it without accepting again.
//
// The two are one test file because the bug they guard against is the same
// one: a re-read path that shares the gate's widget and quietly re-writes
// `disclaimerAcceptedAt`. Nothing on screen would show it, and the stamp the
// app tells a clinician about would silently become "today".

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/routing/app_router.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/db_harness.dart';
import '../../support/harness.dart';

void main() {
  // Frozen, and that is what makes "the stamp is the moment they accepted"
  // assertable at all.
  final acceptedAt = DateTime.utc(2026, 4, 16, 8);

  /// The app, over a real in-memory database, with a counter on every write.
  ///
  /// Writes are counted through drift's own table-update stream rather than a
  /// hand-rolled fake repository: a fake that forgets to count one method is a
  /// fake that reports zero writes for the method it forgot.
  Future<(ProviderContainer, List<AppSettings>)> pumpAppUnderTest(
    WidgetTester tester, {
    required bool accepted,
  }) async {
    final database = openTestDatabase();
    final container = ProviderContainer(
      overrides: <Override>[
        ...launchOverrides(
          settings: accepted ? acceptedSettings() : AppSettings.defaults,
        ),
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(Clock.fixed(acceptedAt)),
      ],
    );
    addTearDown(container.dispose);

    final emissions = <AppSettings>[];
    await tester.runAsync(() async {
      await database.settingsDao.ensureRowExists('settings-0');
      if (accepted) {
        await container.read(settingsRepositoryProvider).acceptDisclaimer();
      }
    });
    final subscription = container
        .read(settingsRepositoryProvider)
        .watchSettings()
        .listen(emissions.add);
    addTearDown(subscription.cancel);
    // The subscription's own first emission is a READ, not a write. Drain it
    // before counting, or every case starts one write in the hole.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    emissions.clear();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (container, emissions);
  }

  String locationOf(ProviderContainer container) => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  testWidgets('accepting stamps the moment it happened, once', (tester) async {
    final (container, writes) = await pumpAppUnderTest(
      tester,
      accepted: false,
    );
    expect(locationOf(container), Routes.welcome);

    await tester.runAsync(() async {
      await tester.tap(find.byType(PrimaryPillButton));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(
      container.read(settingsControllerProvider).disclaimerAcceptedAt,
      acceptedAt,
      reason: 'the stamp is what the About card shows back to a clinician',
    );
    expect(writes, hasLength(1), reason: 'accepting is one write, not two');
    expect(locationOf(container), Routes.today);
  });

  testWidgets('re-reading it from Settings writes NOTHING', (tester) async {
    final (container, writes) = await pumpAppUnderTest(tester, accepted: true);
    final before = container.read(settingsControllerProvider);

    container.read(routerProvider).go(Routes.disclaimerReread);
    await tester.pumpAndSettle();

    // The same content, and NOT the gate: a re-read that reused the gate would
    // disable its own action until the reader scrolled, on a screen they
    // opened deliberately and can simply close.
    final sheet = tester.widget<DisclaimerSheet>(find.byType(DisclaimerSheet));
    expect(sheet.isGate, isFalse);
    expect(
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byType(PrimaryPillButton));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );

    expect(writes, isEmpty, reason: 're-reading is not re-accepting');
    expect(
      container.read(settingsControllerProvider).disclaimerAcceptedAt,
      before.disclaimerAcceptedAt,
    );
  });
}
