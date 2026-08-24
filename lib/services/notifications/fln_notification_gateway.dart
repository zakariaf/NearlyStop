/// The ONE file in this app that imports `flutter_local_notifications`.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nearlystop/core/notifications/scheduled_notification.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';

/// The port, spoken to the plugin.
///
/// **A translation layer with no logic.** Everything that decides anything
/// lives in `ReminderScheduler` (pure) or `syncNotifications` (reconcile),
/// which is what lets every other test in the app run against
/// `FakeNotificationGateway` with no platform-channel mocking at all. There is
/// no off-device test for this file; `tool/check-single-fln-import.sh` keeps
/// it the only one that needs a device, and EPIC-14's manual matrix covers it.
///
/// Every API here was checked against the version resolved in `pubspec.lock`
/// (`flutter_local_notifications` 22.3.0) before it was written.
class FlnNotificationGateway implements NotificationGateway {
  /// Wraps [_plugin].
  FlnNotificationGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// The channel's user-visible name and description, already localized.
  ///
  /// Android shows both in the system settings list; a channel called
  /// "daily_reminder" there is the app talking to itself in front of a reader.
  static NotificationDetails details({
    required String channelName,
    required String channelDescription,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      kDailyReminderChannelId,
      channelName,
      channelDescription: channelDescription,
      // DEFAULT, never max: this is a gentle nudge, not an alarm. A taper is
      // a habit, and an app that shouts every morning for two years gets its
      // notifications turned off in week three.
      //
      // Stated even though it is currently the plugin's default. The analyzer
      // calls that redundant; it is not. A channel's importance is fixed on
      // Android at CREATION and cannot be raised afterwards, so if a plugin
      // upgrade ever changed the default, every NEW install would get a
      // heads-up banner every morning and no existing one would — a
      // difference nobody would find without two phones.
      // Stated deliberately; see the paragraph above.
      // ignore: avoid_redundant_argument_values
      importance: Importance.defaultImportance,
      // Stated deliberately; see the paragraph above.
      // ignore: avoid_redundant_argument_values
      priority: Priority.defaultPriority,
      // PRIVATE: a lock-screen preview reading "Prednisolone 9mg" tells
      // anyone holding the phone that its owner has a chronic illness. The
      // body carries no dose either — this is the second lock on the same
      // door (SPEC §11.4).
      visibility: NotificationVisibility.private,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      // No badge: a badge implies unread items, and this app has none. A red
      // dot that never clears is a small daily anxiety.
      presentBadge: false,
    ),
  );

  /// The details used for every reminder, with the channel's own words.
  late NotificationDetails _details = details(
    channelName: channelName,
    channelDescription: channelDescription,
  );

  /// The channel's name, as the OS settings list shows it.
  String channelName = 'Daily reminder';

  /// The channel's description, as the OS settings list shows it.
  String channelDescription = 'One gentle reminder each morning.';

  /// Re-reads the channel's words after a locale change.
  void relocalize({required String name, required String description}) {
    channelName = name;
    channelDescription = description;
    _details = details(
      channelName: channelName,
      channelDescription: channelDescription,
    );
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        scheduledDate: notification.fireAt,
        notificationDetails: _details,
        // INEXACT, unconditionally (CONTRACTS §12). It is permission-free and
        // still pierces Doze; a daily "your plan for today" does not need
        // alarm-clock precision, and on Android 14+ SCHEDULE_EXACT_ALARM is
        // denied by default — so an exact branch would be dead code that
        // costs a Play policy declaration.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        // What makes it REPEAT at the same wall clock, every day, without the
        // app being open to recompute anything — including across a DST
        // boundary, which is why the rule is a wall clock in the first place.
        matchDateTimeComponents: notification.repeatsDaily
            ? DateTimeComponents.time
            : null,
      );
    } on Object catch (error) {
      throw NotificationGatewayException('$error');
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return <int>{for (final request in pending) request.id};
  }

  @override
  Future<PermissionState> checkPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return _stateOf(await android.areNotificationsEnabled());
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final options = await ios.checkPermissions();
      if (options == null) return PermissionState.notDetermined;
      return options.isAlertEnabled
          ? PermissionState.granted
          : PermissionState.denied;
    }
    return PermissionState.notDetermined;
  }

  @override
  Future<PermissionState> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return _stateOf(await android.requestNotificationsPermission());
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return _stateOf(
        await ios.requestPermissions(alert: true, sound: true),
      );
    }
    return PermissionState.notDetermined;
  }

  /// The plugin answers `bool?`; `null` means it could not say.
  PermissionState _stateOf(bool? enabled) => switch (enabled) {
    true => PermissionState.granted,
    false => PermissionState.denied,
    null => PermissionState.notDetermined,
  };
}
