import 'dart:async';

/// The one hook every `flutter test` run passes through.
///
/// Deliberately empty for now. EPIC-02 bundles Nunito and Vazirmatn and calls
/// `loadAppFonts()` here: goldens must never render with Ahem, because
/// Perso-Arabic shaping and Persian-Indic digits would then never be
/// exercised by a single golden in the suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
