#!/usr/bin/env bash
set -euo pipefail
# Fill the booted simulator's NearlyStop database with a taper months old.
#
# The app only lets you tick TODAY, so a fresh install shows a Progress chart
# with one point on it. This writes the history a real user would have after
# most of a year, so the staircase, the flare marks and the axis can actually
# be looked at.
#
# Usage: bash tool/seed_demo.sh [simulator-name]
#
# It is a DEMO seeder and it lives in tool/ for a reason: `check_bans.sh` bans
# fixture seeding under `lib/` outright, because a seeder that ships writes
# invented doses into a real patient's database.
cd "$(git rev-parse --show-toplevel)"

DEVICE="${1:-${NEARLYSTOP_SIM:-iPhone 16 Pro}}"
BUNDLE=io.applander.nearlystop

UDID="$(xcrun simctl list devices available \
  | awk -v d="$DEVICE" '$0 ~ d {match($0, /[0-9A-F-]{36}/); if (RSTART) {print substr($0, RSTART, RLENGTH); exit}}')"
if [ -z "$UDID" ]; then
  echo "no simulator matching '$DEVICE'"
  exit 1
fi

CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null || true)"
if [ -z "$CONTAINER" ]; then
  echo "$BUNDLE is not installed on '$DEVICE' — run tool/run_simulator.sh first"
  exit 1
fi

DB="$CONTAINER/Documents/nearlystop.sqlite"
if [ ! -f "$DB" ]; then
  echo "no database yet at $DB — launch the app once so it creates one"
  exit 1
fi

echo "seeding $DB"
flutter test tool/seed_demo_taper.dart --dart-define=DB="$DB" --reporter=compact

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
echo "relaunched — open the Progress tab"
