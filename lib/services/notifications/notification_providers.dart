/// The notification seam, as providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/notifications/reminder_scheduler.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:timezone/timezone.dart' as tz;

/// The OS notification service.
///
/// **Throws until overridden.** `bootstrap()` supplies the real adapter and
/// every test supplies the fake; a default that silently did nothing would let
/// a whole suite pass while the app armed no reminders at all.
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>((ref) {
      throw StateError(
        'notificationGatewayProvider was read before bootstrap() overrode it. '
        'Tests override it with FakeNotificationGateway.',
      );
    });

/// The zone reminders are resolved in.
///
/// A provider rather than a direct read of `tz.local` so a test can pin one:
/// a rule resolved against the machine's zone passes on the author's laptop
/// and fires at 03:00 in Tehran.
final Provider<tz.Location> notificationZoneProvider = Provider<tz.Location>(
  (ref) => tz.local,
);

/// The words a reminder carries, in the APP's locale.
///
/// The app locale, not the OS one: EPIC-11's Language picker writes
/// `localeTag`, so somebody reading the app in Persian on an English phone
/// gets a Persian reminder.
final Provider<NotificationCopy> notificationCopyProvider =
    Provider<NotificationCopy>((ref) {
      final l10n = ref.watch(appLocalizationsProvider);
      return NotificationCopy(
        title: l10n.reminderTitle,
        body: l10n.reminderBody,
      );
    });

/// Whether there is a taper to remind anybody about.
///
/// **A pure function of the snapshot, not a provider.** As a provider it had to
/// answer while the snapshot was still loading, and the only answer available
/// then is "no taper" — which is indistinguishable from a finished one and
/// cancels a perfectly good reminder. The reconcile awaits the snapshot and
/// calls this with a real one.
///
/// False on a fresh install and false once the target is reached: a daily nudge
/// to open an app that has nothing to show is the fastest way to have
/// notifications turned off for good.
bool taperActive(TaperSnapshot snapshot) {
  final plan = snapshot.plan;
  if (plan == null || snapshot.steps.isEmpty) return false;
  // `fromDose`, not `toDose`. The final step RUNS from above the target down
  // to it, and somebody in the middle of that step still has a dose to take
  // every morning — cutting their reminder off the day the last step starts
  // is 52 days early. It ends when there is no reduction left to make.
  return snapshot.steps.last.fromDose > plan.targetDose;
}

/// The one asynchronous read the reconcile makes.
///
/// **A seam, deliberately.** The reconcile needs the taper's facts, and it
/// cannot get them from `taperSnapshotProvider`: Riverpod 3 disposes a
/// provider the moment nothing listens, and the first reconcile runs at
/// bootstrap with no widget attached, so awaiting a `StreamProvider`'s future
/// there hangs for ever. The repository's own stream is the read that works —
/// one subscription, one event, closed.
///
/// It is a provider rather than an inline call so a widget test can supply the
/// facts directly. Driving real drift I/O from inside `testWidgets`' fake-async
/// zone means pumping every await by hand, and the acceptance gate should be
/// about the reminder, not about the database.
final Provider<Future<TaperSnapshot?> Function()> taperFactsReaderProvider =
    Provider<Future<TaperSnapshot?> Function()>(
      (ref) => () async {
        final snapshot = await ref
            .read(taperRepositoryProvider)
            .watchSnapshot()
            .first;
        return switch (snapshot) {
          Ok<TaperSnapshot, StorageFailure>(:final value) => value,
          // An unreadable database is not a reason to cancel somebody's
          // reminder. Leave the pending set alone and let the next run decide.
          Err<TaperSnapshot, StorageFailure>() => null,
        };
      },
    );
