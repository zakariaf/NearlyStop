#!/usr/bin/env bash
# Build, install and launch on an iOS Simulator, then screenshot it.
#
# Used after each epic to see the app as a person would, on a device, rather
# than only through the test suite. The very first run of this found that the
# disclaimer gate had no accept action — a fresh install could never reach the
# app — which every widget test had missed because they all asserted where the
# redirect LANDS and none asked whether it can be left.
#
# Usage: tool/run_simulator.sh [output.png] [--fresh]
#   --fresh  uninstall first, so the run starts from a genuine first launch
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

DEVICE="${NEARLYSTOP_SIM:-iPhone 16 Pro}"
BUNDLE=com.buzzjective.nearlystop
SHOT="${1:-/tmp/nearlystop-sim.png}"
FRESH="${2:-}"

UDID="$(xcrun simctl list devices available \
  | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
[ -n "$UDID" ] || { echo "no simulator named '$DEVICE'"; exit 1; }

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
open -a Simulator

[ "$FRESH" = "--fresh" ] && xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true

flutter build ios --simulator --debug
xcrun simctl install "$UDID" build/ios/iphonesimulator/Runner.app
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE"

# Let the first frame land before capturing.
python3 -c "import time; time.sleep(4)"
xcrun simctl io "$UDID" screenshot "$SHOT"
echo "screenshot: $SHOT"
