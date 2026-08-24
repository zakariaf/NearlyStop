#!/usr/bin/env python3
"""Audit the FULL transitive pub dependency tree against a policy ban list.

Usage (from the repo / workspace root):
    dart pub deps --json > /tmp/deps.json
    python3 audit_deps.py /tmp/deps.json

Exit 0 = clean. Exit 1 = a banned package ships in the binary, directly or
transitively. Exit 2 = usage/parse error. Direct-only inspection of pubspec.yaml
cannot find transitive hits; that is the entire point of walking the resolved
graph.

EDIT THE `BANNED` AND `ALLOW` LISTS BELOW to encode YOUR project's policy. The
defaults suit a no-network / no-telemetry app; a normal networked app should
delete the network-client and identifier entries it legitimately uses.
"""

import json
import re
import sys

# --- EDIT ME: substring/regex patterns matched against package names ---------
# case-insensitive. Each entry: (pattern, why it is refused).
BANNED = [
    (r"^firebase", "Firebase — its core registers device/usage data categories"),
    (r"^cloud_fire", "Firebase (Firestore) — same core"),
    (r"crashlytics", "crash reporting = telemetry"),
    (r"sentry", "crash reporting = telemetry"),
    (r"analytics", "analytics of any kind is refused by policy"),
    (r"^posthog|^mixpanel|^amplitude|^segment", "product analytics"),
    (r"^google_mobile_ads|^appsflyer|^adjust", "ads/attribution SDK — network + identifiers"),
    (r"^http$|^dio$|^web_socket|^grpc$|^socket_io", "a network client (policy: no network path)"),
    (r"^googleapis|^google_sign_in|^firebase_auth", "accounts + network"),
    (r"^device_info_plus|^package_info_plus", "device identifiers with no shipped use (allow if you ship one)"),
]

# --- EDIT ME: names that match a BANNED pattern but are deliberately kept -----
# Add a name here ONLY with a written justification: WHY the reachable-but-inert
# dependency is acceptable and what the real, enforced gate is instead.
ALLOW: set[str] = {
    # riverpod 3.x declares `test: ^1.0.0` as a REGULAR dependency (it ships
    # ProviderContainer.test() and matchers in the main library), so the test
    # runner's own transport tree — web_socket and web_socket_channel — is
    # reachable from `dependencies:` rather than `dev_dependencies:` on every
    # riverpod app. Verified path:
    #     riverpod -> test -> web_socket_channel -> web_socket
    # No file under lib/ imports any of them, so nothing references the sockets
    # and they are tree-shaken out of the AOT snapshot. The enforced gates are
    # real ones, not this note: tool/check_bans.sh bans BOTH an import of
    # package:web_socket / package:web_socket_channel anywhere under lib/ AND
    # the socket call sites themselves (HttpClient, Socket, WebSocket, ...), and
    # EPIC-15 owns the absent INTERNET permission in the release manifest plus
    # the airplane-mode clean-install check (SPEC §10). Re-audit if riverpod ever
    # drops `test` to a dev dependency.
    "web_socket",
    "web_socket_channel",
    # `timezone` — which EPIC-12 needs and which every current
    # `flutter_local_notifications` requires at `^0.11.0` — declares `http` as a
    # regular dependency. Verified path and reachability:
    #     flutter_local_notifications -> timezone -> http
    # Inside `timezone`, `package:http` is imported by exactly ONE file,
    # `lib/browser.dart`, which fetches the IANA database over HTTP in a WEB
    # app. This app has no web target and imports `timezone/timezone.dart` and
    # `timezone/data/latest_all.dart` — the bundled database — so no code path
    # reaches it and it is tree-shaken out of the AOT snapshot.
    # The enforced gates are real ones, not this note:
    #   * tool/check_bans.sh bans an import of package:http anywhere under lib/
    #     AND every socket call site (HttpClient, Socket, WebSocket, ...);
    #   * tool/check-manifest-permissions.sh asserts the WHOLE permission set of
    #     the merged release manifest, in which INTERNET is absent — so on
    #     Android the process cannot open a socket even if something tried;
    #   * EPIC-15 owns the airplane-mode clean-install check (SPEC §10).
    # Re-audit if `timezone` ever moves `http` out of `lib/browser.dart`, or if
    # this app ever gains a web target.
    "http",
}

USAGE = """usage: audit_deps.py <deps.json>

Generate the input first (from the repo / workspace root):
    dart pub deps --json > deps.json

Flags any banned package in the resolved tree and says whether it arrived
directly or transitively. Exits 1 on a shipping hit so it can gate CI."""


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        with open(sys.argv[1]) as f:
            data = json.load(f)
    except OSError as e:
        print(f"audit_deps: cannot read {sys.argv[1]}: {e}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"audit_deps: {sys.argv[1]} is not valid JSON: {e}", file=sys.stderr)
        print("  (expected the output of: dart pub deps --json)", file=sys.stderr)
        return 2

    pkgs = {p["name"]: p for p in data.get("packages", [])}
    names = {n for n, p in pkgs.items() if p.get("kind") != "root"}

    def reachable(kind: str) -> set[str]:
        """Everything pulled in transitively by one class of declared dependency."""
        seen: set[str] = set()
        stack = [n for n, p in pkgs.items() if p.get("kind") == kind]
        while stack:
            n = stack.pop()
            if n in seen or n not in pkgs:
                continue
            seen.add(n)
            stack.extend(pkgs[n].get("dependencies", []))
        return seen

    # What ships is what `dependencies:` drags in. `dev_dependencies:` (build_runner,
    # codegen, the test framework) never reach the binary, so a banned package that is
    # ONLY dev-reachable is not a shipping defect — build_runner legitimately pulls a
    # local HTTP server for watch mode. A gate that fails on that gets switched off.
    ships = reachable("direct")
    dev_only = reachable("dev") - ships

    def banned_in(pool: set[str]) -> list[tuple[str, str]]:
        found = []
        for name in sorted(pool):
            if name in ALLOW:
                continue
            for pattern, why in BANNED:
                if re.search(pattern, name, re.IGNORECASE):
                    found.append((name, why))
                    break
        return found

    hits = banned_in(ships)
    noise = banned_in(dev_only)
    direct_names = {n for n, p in pkgs.items() if p.get("kind") == "direct"}

    print(f"{len(names)} resolved · {len(ships)} ship in the binary · {len(dev_only)} build/test only")
    for name, why in hits:
        how = "direct" if name in direct_names else "TRANSITIVE"
        print(f"BANNED  {name}  [{how}]\n        {why}")

    if noise:
        print("\nBuild/test only — not in the binary, not a defect:")
        for name, _ in noise:
            print(f"  {name}")

    if hits:
        print("\nRefuse the dependency, or find one that does not pull these in.")
        print("To see who pulls a package in:  dart pub deps | grep -B4 <name>")
        return 1

    print("\nClean: nothing banned reaches the binary.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
