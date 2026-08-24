/// The notification stack's shared test wiring.
///
/// Three suites were each spelling out the same four overrides and the same
/// "seed the plan once, however many containers this case builds" bookkeeping.
/// A fourth spelling is a fourth chance to pin a different zone than the
/// fixture's clock — which is the one mistake in this stack that produces a
/// green suite and a 03:30 notification.
library;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/providers.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The zone every notification test pins.
///
/// Berlin, because it is the one in the fixture's own DST tests: a suite that
/// pinned a zone with no daylight saving would pass every case in this stack
/// and still ship the bug the stack exists to prevent.
tz.Location get testZone => tz.getLocation('Europe/Berlin');

/// Loads the IANA database. Call from `setUpAll`.
void initializeTestTimeZones() => tzdata.initializeTimeZones();

/// The overrides the reminder engine needs, in one place.
List<Override> notificationOverrides({
  required NotificationGateway gateway,
  DateTime? now,
  Locale locale = const Locale('en'),
}) => <Override>[
  notificationGatewayProvider.overrideWithValue(gateway),
  notificationZoneProvider.overrideWithValue(testZone),
  clockProvider.overrideWithValue(
    Clock.fixed(now ?? DateTime.utc(2025, 4, 16, 5)),
  ),
  resolvedLocaleProvider.overrideWithValue(locale),
];
