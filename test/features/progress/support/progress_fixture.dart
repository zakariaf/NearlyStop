/// Shared Progress fixtures.
///
/// The fixed-state notifier had been written three times, once per suite; a
/// fourth copy is where one of them quietly emits something different.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/features/progress/application/progress_view_provider.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';

/// A notifier that emits one fixed [AsyncValue] and nothing else.
final class FixedProgress extends ProgressNotifier {
  /// Emits [fixture].
  FixedProgress(this.fixture);

  /// Emits [state] as data.
  FixedProgress.data(ProgressViewState state)
    : fixture = AsyncValue<ProgressViewState>.data(state);

  /// What to emit.
  final AsyncValue<ProgressViewState> fixture;

  @override
  Stream<ProgressViewState> build() => switch (fixture) {
    AsyncData<ProgressViewState>(:final value) =>
      Stream<ProgressViewState>.value(value),
    AsyncError<ProgressViewState>(:final error, :final stackTrace) =>
      Stream<ProgressViewState>.error(error, stackTrace),
    // Loading: a stream that never emits, which is what "still reading the
    // database" looks like from the screen's side.
    _ => const Stream<ProgressViewState>.empty(),
  };
}
