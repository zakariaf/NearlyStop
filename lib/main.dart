import 'package:nearlystop/bootstrap.dart';

/// Awaited rather than dropped.
///
/// `bootstrap()` became async when it started loading `intl`'s symbol data, and
/// an `unawaited()` here would put the whole launch path on an unhandled-async
/// route: `runApp` is never reached, the crash sink is not installed yet, and
/// the user sees the splash and then nothing at all.
Future<void> main() async => bootstrap();
