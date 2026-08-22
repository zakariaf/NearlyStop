import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/fonts.dart';

/// The one hook every `flutter test` run passes through.
///
/// It loads Nunito and Vazirmatn before any test runs. Goldens must **never**
/// render with Ahem: its uniform metrics make a width assertion vacuously true
/// and mean Perso-Arabic shaping and Persian-Indic digits are never exercised
/// by a single golden in the suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  await testMain();
}
