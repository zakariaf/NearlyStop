/// When an async provider should try again, and when trying again is futile.
library;

import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:riverpod/riverpod.dart';

/// Retries a transient failure; never retries a refusal.
///
/// Riverpod's default retries ten times with exponential backoff — about half
/// a minute of skeleton. That is the right answer for a disk that is briefly
/// busy, and the wrong one for a [DomainFailure], which is the generator
/// saying *these facts do not describe a schedule*. Re-running a pure function
/// over unchanged facts produces the identical refusal, so the only thing the
/// retry buys is thirty seconds of spinner before the same error appears.
///
/// Providers that can fail with a domain refusal pass this as their `retry`.
Duration? retryTransientOnly(int retryCount, Object error) {
  if (error is DomainFailure) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}
