#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/check-manifest-permissions.sh, over committed fixtures.
#
# The fixtures are merged manifests rather than source ones on purpose: every
# case here is a node a LIBRARY contributed, which is the only way any of them
# would actually arrive.
#
# Usage: bash tool/check-manifest-permissions-selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/check-manifest-permissions.sh
fixtures=tool/fixtures/manifests
failures=0

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

check() { # check <fixture> <expected-exit> <expected-substring> <description>
  local out code
  out="$(bash "$gate" "$fixtures/$1.xml" 2>&1)"
  code=$?
  if [ "$code" -ne "$2" ]; then
    bad "$4 (exit $code, wanted $2)"
    echo "$out" | sed 's/^/         /'
  elif [ -n "$3" ] && ! grep -q "$3" <<<"$out"; then
    bad "$4 — right exit, but the message never says '$3'"
    echo "$out" | sed 's/^/         /'
  else
    pass "$4"
  fi
}

echo "case 1: the expected merged manifest"
check good 0 "OK" "exactly the three expected permissions passes"

echo "case 2: an exact-alarm permission, however it arrived"
check exact-alarm 1 "SCHEDULE_EXACT_ALARM" "SCHEDULE_EXACT_ALARM is rejected by name"
check use-exact-alarm 1 "USE_EXACT_ALARM" "USE_EXACT_ALARM is rejected by name"

echo "case 3: the set is asserted WHOLE, not as a deny list"
check internet 1 "INTERNET" "an unexpected permission is rejected — including INTERNET"

echo "case 4: the permission without the receiver that uses it"
check no-boot-receiver 1 "ScheduledNotificationBootReceiver" \
  "RECEIVE_BOOT_COMPLETED without the boot receiver is rejected"

echo "case 5: the gate refuses to report OK on a manifest it never read"
out="$(bash "$gate" /definitely/not/a/manifest.xml 2>&1)"
code=$?
if [ "$code" -eq 0 ]; then
  bad "a missing manifest reported success"
elif ! grep -q 'does not exist' <<<"$out"; then
  bad "a missing manifest failed but never said why"
else
  pass "a missing manifest exits non-zero and says how to build it"
fi

if [ "$failures" -ne 0 ]; then
  echo "check-manifest-permissions-selftest: $failures case(s) failed"
  exit 1
fi
echo "check-manifest-permissions-selftest: OK"
