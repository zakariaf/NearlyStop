// The launch MODE, asserted where it is decided.
//
// `tool/check_bans.sh` refuses the in-app modes by grep, which catches the
// obvious edit. It cannot catch the subtle one: `launchUrl` with the `mode`
// argument dropped defaults to `PreferredLaunchMode.platformDefault`, which on
// Android IS `inAppBrowserView` — an in-app webview reached by deleting a line
// rather than by writing one, in a binary whose store listing says it has no
// network client.
//
// So the mode is pinned here too, at the call site, against the real platform
// interface `url_launcher` talks to.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app_links.dart';
import 'package:nearlystop/services/links/link_opener.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingLauncher platform;

  setUp(() {
    platform = _RecordingLauncher();
    UrlLauncherPlatform.instance = platform;
  });

  test('the repository is launched in the OS browser, never in-app', () async {
    final opened = await openExternally(kSourceRepositoryUrl);

    expect(opened, isTrue);
    expect(platform.urls, <String>[kSourceRepositoryUrl.toString()]);
    expect(
      platform.modes,
      <PreferredLaunchMode>[PreferredLaunchMode.externalApplication],
    );
  });

  test('a platform that refuses the URL is reported, not swallowed', () async {
    // The Settings row copies the address to the clipboard on a false, so a
    // swallowed refusal would look to the reader like a link that does nothing.
    platform.answer = false;

    expect(await openExternally(kSourceRepositoryUrl), isFalse);
  });
}

/// Stands in for whatever `url_launcher` would talk to on a real phone.
final class _RecordingLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  /// Every URL asked for, in order.
  final List<String> urls = <String>[];

  /// Every mode asked for, in order.
  final List<PreferredLaunchMode> modes = <PreferredLaunchMode>[];

  /// What the platform answers.
  bool answer = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    modes.add(options.mode);
    return answer;
  }
}
