#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/check_core_purity.sh. A purity gate that has never been
# seen to fail is a comment — and the timezone exception is only proven real by
# the case that shows it is SCOPED.
#
# Usage: bash tool/check_core_purity_selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/check_core_purity.sh
clock=lib/core/time/clock.dart
clock_backup=".clock_purity.bak"
notif_scratch=lib/core/notifications/_purity_scratch.dart
dsns_scratch=lib/core/dsns/_purity_scratch.dart
failures=0

cleanup() {
  [ -f "$clock_backup" ] && mv "$clock_backup" "$clock"
  rm -f "$notif_scratch" "$dsns_scratch"
  rmdir lib/core/notifications lib/core/dsns 2>/dev/null
  return 0
}
trap cleanup EXIT

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

run_gate() {
  out="$(bash "$gate" 2>&1)"
  code=$?
}

echo "case 9: the clean tree"
run_gate
if [ "$code" -ne 0 ]; then
  bad "expected exit 0, got $code"
  echo "$out" | sed 's/^/         /'
else
  pass "clean tree exits 0"
fi

echo "cases 10-11: each banned URI, planted one at a time in $clock"
cp "$clock" "$clock_backup"
for uri in \
  "package:flutter_riverpod/flutter_riverpod.dart" \
  "package:flutter/material.dart" \
  "package:riverpod/riverpod.dart" \
  "package:hooks_riverpod/hooks_riverpod.dart" \
  "package:drift/drift.dart" \
  "package:flutter_test/flutter_test.dart" \
  "dart:ui"; do
  # The redirect truncates $clock; `cat -` reads the header from stdin and the
  # body from the BACKUP, so the backup is what restores the file. Do not add a
  # cp here — it would be undone by the redirect on the next line and would hide
  # which statement actually does the restoring.
  printf "import '%s';\n" "$uri" | cat - "$clock_backup" >"$clock"
  run_gate
  if [ "$code" -ne 1 ]; then
    bad "$uri in $clock was not rejected (exit $code)"
  elif ! grep -q "$clock:1:" <<<"$out"; then
    bad "$uri was rejected but the message does not name $clock and its line"
  else
    pass "$uri rejected, named by path and line"
  fi
done
mv "$clock_backup" "$clock"

echo "case 12: the timezone exception is SCOPED, not a hole"
mkdir -p lib/core/notifications lib/core/dsns
cat >"$notif_scratch" <<'DART'
import 'package:timezone/timezone.dart';

/// Scratch: a scheduling core needs TZDateTime to say "08:00 local".
TZDateTime? scratch;
DART
run_gate
if [ "$code" -ne 0 ]; then
  bad "package:timezone under lib/core/notifications/ must be allowed (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "package:timezone allowed under lib/core/notifications/"
fi
cp "$notif_scratch" "$dsns_scratch"
run_gate
if [ "$code" -ne 1 ]; then
  bad "the identical import under lib/core/dsns/ must be rejected (exit $code)"
elif ! grep -q "$dsns_scratch" <<<"$out"; then
  bad "rejected, but the message does not name $dsns_scratch"
else
  pass "the identical import under lib/core/dsns/ is rejected — the exception is scoped"
fi
rm -f "$notif_scratch" "$dsns_scratch"
rmdir lib/core/notifications lib/core/dsns 2>/dev/null

echo "case 12b: near-misses the walker must NOT report"
mkdir -p lib/core/drift_shaped
near=lib/core/drift_shaped/_purity_near_miss.dart
cat >"$near" <<'DART'
/// Scratch. Mentions package:flutter_lints and package:drift in prose only.
///
/// See also: import 'package:flutter/material.dart';
const String importDirectiveExample = "import 'package:flutter/material.dart';";

// package:riverpod/riverpod.dart named in a line comment
const String other = 'package:drift/drift.dart';
DART
run_gate
if [ "$code" -ne 0 ]; then
  bad "a comment, a string literal, or a path containing 'drift' was reported"
  echo "$out" | sed 's/^/         /'
else
  pass "comments, string literals and a drift-shaped PATH are not import directives"
fi
rm -f "$near"
rmdir lib/core/drift_shaped 2>/dev/null

echo "case 13: the gate refuses to report OK on a tree it could not scan"
out="$(bash "$gate" /definitely/not/a/directory 2>&1)"
code=$?
if [ "$code" -eq 0 ]; then
  bad "a bad ROOT reported success"
elif ! grep -qi 'cannot enter' <<<"$out"; then
  bad "a bad ROOT failed but never said why"
else
  pass "a bad ROOT exits non-zero and says so"
fi

echo "case 14: the gate works from an arbitrary ROOT"
alt="$(mktemp -d)"
mkdir -p "$alt/lib/core/dsns"
cat >"$alt/lib/core/dsns/planted.dart" <<'DART'
import 'package:flutter/material.dart';

/// Scratch.
Widget? scratch;
DART
out="$(bash "$gate" "$alt" 2>&1)"
code=$?
rm -rf "$alt"
if [ "$code" -ne 1 ]; then
  bad "the gate did not flag a planted import under an explicit ROOT (exit $code)"
elif ! grep -q 'package:flutter/' <<<"$out"; then
  bad "the gate ran under an explicit ROOT but scanned an empty haystack"
else
  pass "an explicit ROOT is scanned, not silently skipped"
fi

if [ "$failures" -ne 0 ]; then
  echo "check_core_purity_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_core_purity_selftest: OK"
