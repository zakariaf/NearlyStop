/// The composition root.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app.dart';

/// The bundled faces, and the OFL text file that licenses each.
///
/// Both are SIL Open Font License 1.1, verified from the shipped files rather
/// than from memory.
const Map<String, String> bundledFontLicenses = <String, String>{
  'Nunito': 'assets/fonts/OFL-Nunito.txt',
  'Vazirmatn': 'assets/fonts/OFL-Vazirmatn.txt',
};

/// Registers the bundled fonts' OFL text with the framework.
///
/// An unregistered OFL font makes the app's own licenses page a lie, and
/// nothing else in the suite would notice. Called from [bootstrap] before
/// `runApp`, and directly by `test/theme/font_bundling_test.dart`.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: path)
        in bundledFontLicenses.entries) {
      yield LicenseEntryWithLineBreaks(
        <String>[family],
        await rootBundle.loadString(path),
      );
    }
  });
}

/// Builds the app's infrastructure and runs it.
///
/// EPIC-06 adds the global error net and the provider overrides. Keep the order
/// deliberate: the error handlers must be installed before any code that can
/// throw.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  runApp(const ProviderScope(child: NearlyStopApp()));
}
