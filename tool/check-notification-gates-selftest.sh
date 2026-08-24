#!/usr/bin/env bash
set -uo pipefail
# Both arms of the two notification source gates, over throwaway trees.
#
# check-single-fln-import.sh and check-adhoc-schedule-calls.sh are the whole
# reason every other test in the notification stack can run against a fake with
# no platform-channel mocking. A gate that has only ever been green cannot make
# that claim.
#
# Usage: bash tool/check-notification-gates-selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
imports=tool/check-single-fln-import.sh
adhoc=tool/check-adhoc-schedule-calls.sh
failures=0

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

scratch() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/lib/core/notifications" \
    "$dir/lib/services/notifications" \
    "$dir/lib/features/today/presentation" \
    "$dir/lib/app"
  printf '/// Scratch.\nconst int a = 1;\n' > "$dir/lib/app/clean.dart"
  echo "$dir"
}

check() { # check <gate> <dir> <expected-exit> <substring> <description>
  local out code
  out="$(bash "$1" "$2" 2>&1)"
  code=$?
  if [ "$code" -ne "$3" ]; then
    bad "$5 (exit $code, wanted $3)"
    echo "$out" | sed 's/^/         /'
  elif [ -n "$4" ] && ! grep -q "$4" <<<"$out"; then
    bad "$5 — right exit, but the message never says '$4'"
    echo "$out" | sed 's/^/         /'
  else
    pass "$5"
  fi
}

echo "case 1: the plugin lives in one file"
dir="$(scratch)"
printf "/// Scratch.\nimport 'package:flutter_local_notifications/flutter_local_notifications.dart';\n" \
  > "$dir/lib/services/notifications/fln_notification_gateway.dart"
check "$imports" "$dir" 0 "OK" "the adapter may import the plugin"
cp "$dir/lib/services/notifications/fln_notification_gateway.dart" \
  "$dir/lib/features/today/presentation/planted.dart"
check "$imports" "$dir" 1 "planted.dart" "a feature file may not"
rm -rf "$dir"

echo "case 2: timezone reaches the core and its seam, and stops there"
dir="$(scratch)"
printf "/// Scratch.\nimport 'package:timezone/timezone.dart';\n" \
  > "$dir/lib/core/notifications/rule.dart"
printf "/// Scratch.\nimport 'package:timezone/timezone.dart';\n" \
  > "$dir/lib/services/notifications/providers.dart"
check "$imports" "$dir" 0 "OK" "the core and the seam may name TZDateTime"
cp "$dir/lib/core/notifications/rule.dart" \
  "$dir/lib/features/today/presentation/planted.dart"
check "$imports" "$dir" 1 "planted.dart" "a feature file may not"
rm -rf "$dir"

echo "case 3: flutter_timezone is a DEVICE call, adapter only"
dir="$(scratch)"
printf "/// Scratch.\nimport 'package:flutter_timezone/flutter_timezone.dart';\n" \
  > "$dir/lib/services/notifications/fln_notification_gateway.dart"
check "$imports" "$dir" 0 "OK" "the adapter may read the device's zone"
printf "/// Scratch.\nimport 'package:flutter_timezone/flutter_timezone.dart';\n" \
  > "$dir/lib/app/planted.dart"
check "$imports" "$dir" 1 "flutter_timezone" "bootstrap may not — it goes through the adapter"
rm -rf "$dir"

echo "case 4: timezone/browser.dart is banned everywhere"
dir="$(scratch)"
printf "/// Scratch.\nimport 'package:timezone/browser.dart';\n" \
  > "$dir/lib/core/notifications/planted.dart"
check "$imports" "$dir" 1 "package:http" \
  "the one timezone file that pulls package:http is refused even in the core"
rm -rf "$dir"

echo "case 5: only the reconcile arms or cancels"
dir="$(scratch)"
printf "/// Scratch.\nabstract class NotificationGateway {}\n" \
  > "$dir/lib/services/notifications/notification_gateway.dart"
printf "/// Scratch.\nimport 'notification_gateway.dart';\nvoid f(NotificationGateway g) => g.cancelAll();\n" \
  > "$dir/lib/services/notifications/sync_notifications.dart"
check "$adhoc" "$dir" 0 "OK" "the reconcile may arm and cancel"
printf "/// Scratch.\nimport 'notification_gateway.dart';\nvoid f(NotificationGateway g) => g.schedule(1);\n" \
  > "$dir/lib/features/today/presentation/planted.dart"
check "$adhoc" "$dir" 1 "planted.dart" "a feature file may not"
rm -rf "$dir"

echo "case 6: a dart:async Timer is not a notification"
dir="$(scratch)"
printf "/// Scratch.\nimport 'dart:async';\nvoid f(Timer? t) => t?.cancel();\n" \
  > "$dir/lib/app/day_ticker.dart"
check "$adhoc" "$dir" 0 "OK" "a file that cannot see the port is not this gate's business"
rm -rf "$dir"

echo "case 7: neither gate reports OK on a tree it could not read"
for gate in "$imports" "$adhoc"; do
  out="$(bash "$gate" /definitely/not/a/directory 2>&1)"
  code=$?
  if [ "$code" -eq 0 ]; then
    bad "$(basename "$gate"): a bad ROOT reported success"
  else
    pass "$(basename "$gate"): a bad ROOT exits non-zero"
  fi
done

echo "case 8: the real repo passes both"
for gate in "$imports" "$adhoc"; do
  out="$(bash "$gate" "$(pwd)" 2>&1)"
  code=$?
  if [ "$code" -ne 0 ]; then
    bad "$(basename "$gate"): the repository does not pass its own gate"
    echo "$out" | sed 's/^/         /'
  else
    pass "$(basename "$gate"): the repository passes"
  fi
done

if [ "$failures" -ne 0 ]; then
  echo "check-notification-gates-selftest: $failures case(s) failed"
  exit 1
fi
echo "check-notification-gates-selftest: OK"
