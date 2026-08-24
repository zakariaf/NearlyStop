/// The in-memory gateway every test in this app talks to.
library;

import 'package:nearlystop/core/notifications/scheduled_notification.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';

/// A `NotificationGateway` that remembers instead of arming.
///
/// **`implements`, with no `noSuchMethod`.** A sixth method on the port is a
/// compile error here rather than a silent pass, which is the only reason this
/// fake can be trusted by every other test in the epic.
class FakeNotificationGateway implements NotificationGateway {
  final Map<int, ScheduledNotification> _pending =
      <int, ScheduledNotification>{};

  /// Every method called, in order. Asserted on by the reconcile tests, which
  /// care that `checkPermission` runs BEFORE the first `getPending`.
  final List<String> calls = <String>[];

  /// What the OS currently says. Settable, so the revoked-after-grant path is
  /// reachable without a device.
  PermissionState permission = PermissionState.granted;

  /// Makes the next [schedule] throw, once.
  bool failNextSchedule = false;

  /// How many times [schedule] was called.
  int get scheduleCount => calls.where((call) => call == 'schedule').length;

  /// How many times [cancel] was called.
  int get cancelCount => calls.where((call) => call == 'cancel').length;

  /// Forgets the call log. **Keeps the pending set**: idempotence is asserted
  /// by counting writes across a second run, and a reset that also emptied the
  /// set would make every such assertion vacuous.
  void resetCalls() => calls.clear();

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    calls.add('schedule');
    if (failNextSchedule) {
      failNextSchedule = false;
      throw const NotificationGatewayException('the platform refused');
    }
    // Replaces, exactly as the plugin does.
    _pending[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel');
    _pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
    _pending.clear();
  }

  @override
  Future<Set<int>> pendingIds() async {
    calls.add('pendingIds');
    return _pending.keys.toSet();
  }

  /// What was armed, whole. **Test-only**: the real platform cannot answer
  /// this, which is exactly why it is not on the port. Tests assert on it so
  /// they can say "at local 08:00, repeating" rather than only "some id".
  List<ScheduledNotification> get pending => _pending.values.toList();

  @override
  Future<PermissionState> checkPermission() async {
    calls.add('checkPermission');
    return permission;
  }

  @override
  Future<PermissionState> requestPermission() async {
    calls.add('requestPermission');
    return permission;
  }
}
