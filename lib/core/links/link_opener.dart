/// The single seam through which this app leaves itself.
library;

import 'package:riverpod/riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url], answering whether anything took it.
///
/// A typedef rather than a class: there is one operation, tests need to record
/// the URL and choose the answer, and a one-method interface plus a fake is
/// two more files saying the same thing.
typedef LinkOpener = Future<bool> Function(Uri url);

/// The opener the app runs with.
final Provider<LinkOpener> linkOpenerProvider = Provider<LinkOpener>(
  (ref) => openExternally,
);

/// Hands [url] to whatever the operating system uses for the web.
///
/// **`externalApplication`, permanently.** The mode is the difference between
/// the reader's browser making a request and THIS app making one inside its
/// own process. An in-app webview would put a network client in a binary whose
/// store listing says there is none, and would do it in the one place a reader
/// went looking for proof of the opposite. `tool/check_bans.sh` refuses the
/// in-app modes anywhere under `lib/` so the decision is not re-litigated by a
/// later edit that looks harmless.
Future<bool> openExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
