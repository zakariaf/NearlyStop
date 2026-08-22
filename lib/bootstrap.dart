/// The composition root.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app.dart';

/// Builds the app's infrastructure and runs it.
///
/// EPIC-02 adds the bundled-font `LicenseRegistry` entry here; EPIC-06 adds the
/// global error net and the provider overrides. Keep the order deliberate: the
/// error handlers must be installed before any code that can throw.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NearlyStopApp()));
}
