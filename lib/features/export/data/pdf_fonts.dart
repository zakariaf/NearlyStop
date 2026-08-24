/// The two bundled faces, as PDF fonts.
library;

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// The Latin face, as declared in `pubspec.yaml`.
const String kNunitoAsset = 'assets/fonts/Nunito-VariableFont_wght.ttf';

/// The Perso-Arabic face, as declared in `pubspec.yaml`.
const String kVazirmatnAsset = 'assets/fonts/Vazirmatn-VariableFont_wght.ttf';

/// The faces a handout embeds.
typedef PdfFonts = ({pw.Font latin, pw.Font perso});

/// Loads both bundled faces.
///
/// **Both, always.** `google_fonts` is banned in this app and the `pdf`
/// package's built-in Helvetica has no Perso-Arabic coverage at all — a
/// Persian handout built on it is a page of empty boxes, and nothing in the
/// app would report it.
Future<PdfFonts> loadBundledPdfFonts() async => (
  latin: pw.Font.ttf(await rootBundle.load(kNunitoAsset)),
  perso: pw.Font.ttf(await rootBundle.load(kVazirmatnAsset)),
);
