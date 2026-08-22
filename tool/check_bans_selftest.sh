#!/usr/bin/env bash
set -uo pipefail
# Both arms of every rule in tool/check_bans.sh. A gate that has never been
# seen to fail is a comment.
#
# Usage: bash tool/check_bans_selftest.sh     (from the repo root; wired into CI)

cd "$(dirname "$0")/.."
gate=tool/check_bans.sh
scratch=lib/features/_bans_scratch.dart
scratch2=lib/features/_bans_scratch_two.dart
clock=lib/core/time/clock.dart
clock_backup=".clock.bak"
failures=0

cleanup() {
  rm -f "$scratch" "$scratch2"
  [ -f "$clock_backup" ] && mv "$clock_backup" "$clock"
  return 0
}
trap cleanup EXIT

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

# run_gate → sets $out and $code
run_gate() {
  out="$(bash "$gate" 2>&1)"
  code=$?
}

expect_clean() {
  run_gate
  if [ "$code" -ne 0 ]; then
    bad "$1 (expected exit 0, got $code)"
    echo "$out" | sed 's/^/         /'
  else
    pass "$1"
  fi
}

# expect_flagged <description> <needle-in-message> [<second-needle>]
expect_flagged() {
  local desc="$1" needle="$2" needle2="${3:-}"
  run_gate
  if [ "$code" -ne 1 ]; then
    bad "$desc (expected exit 1, got $code)"
  elif ! grep -q "$needle" <<<"$out"; then
    bad "$desc (message never mentioned '$needle')"
  elif [ -n "$needle2" ] && ! grep -q "$needle2" <<<"$out"; then
    bad "$desc (message never mentioned '$needle2')"
  else
    pass "$desc"
  fi
}

echo "case 1: the clean tree"
expect_clean "clean tree exits 0 (and tool/, full of needles by construction, is never scanned)"

echo "case 2: a banned network import"
cat >"$scratch" <<'DART'
import 'package:http/http.dart';

/// Scratch.
void scratch() {}
DART
expect_flagged "planted package:http import is named by path and reason" \
  "$scratch" "zero network calls"

echo "case 3: hardcoded left/right padding"
cat >"$scratch" <<'DART'
import 'package:flutter/widgets.dart';

/// Scratch.
const EdgeInsets scratchPadding = EdgeInsets.only(left: 8);
DART
expect_flagged "planted EdgeInsets.only(left:) is named with the RTL reason" \
  "$scratch" "directional geometry"

echo "case 4: both at once — accumulate and fail ONCE with both offenders"
cat >"$scratch" <<'DART'
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';

/// Scratch.
const EdgeInsets scratchPadding = EdgeInsets.only(left: 8);
DART
run_gate
if [ "$code" -ne 1 ]; then
  bad "expected exit 1, got $code"
elif ! grep -q 'zero network calls' <<<"$out"; then
  bad "the http offender is missing — a per-rule 'exit 1' stopped at the first hit"
elif ! grep -q 'directional geometry' <<<"$out"; then
  bad "the EdgeInsets offender is missing — a per-rule 'exit 1' stopped at the first hit"
elif [ "$(grep -c 'violation(s)' <<<"$out")" -ne 1 ]; then
  bad "the gate reported its verdict more than once"
else
  pass "one exit 1, both offenders listed"
fi

echo "case 5: DateTime.now() — banned in features, legitimate in the clock seam"
cat >"$scratch" <<'DART'
/// Scratch.
DateTime scratchNow() => DateTime.now();
DART
expect_flagged "planted DateTime.now() in a feature is flagged" \
  "$scratch" "never DateTime.now()"
rm -f "$scratch"
cp "$clock" "$clock_backup"
cat >>"$clock" <<'DART'

/// The one legitimate wall-clock read in the codebase.
DateTime selftestNow() => DateTime.now();
DART
expect_clean "the identical call inside $clock is exempt"
mv "$clock_backup" "$clock"

echo "case 6: Icons.arrow_back vs Icons.adaptive.arrow_back"
cat >"$scratch" <<'DART'
import 'package:flutter/material.dart';

/// Scratch.
const Icon scratchIcon = Icon(Icons.arrow_back);
DART
expect_flagged "planted Icons.arrow_back is flagged" "$scratch" "Icons.adaptive"
cat >"$scratch" <<'DART'
import 'package:flutter/material.dart';

/// Scratch.
final Icon scratchIcon = Icon(Icons.adaptive.arrow_back);
DART
expect_clean "Icons.adaptive.arrow_back passes — anchored to the structure, not a substring"

echo "case 7: file-scoped vs line-scoped suppression"
cat >"$scratch" <<'DART'
// ignore_for_file: unawaited_futures

/// Scratch.
void scratch() {}
DART
expect_flagged "planted // ignore_for_file: on a promoted rule is flagged" \
  "$scratch" "line-scoped"
cat >"$scratch" <<'DART'
/// Scratch.
void scratch() {
  // ignore: unawaited_futures — deliberate: the selftest asserts this passes
}
DART
expect_clean "a line-scoped // ignore: with a reason passes"

echo "case 8: every needle inside a comment is not an offender"
cat >"$scratch" <<'DART'
/// Scratch.
///
/// import 'package:http/http.dart';
/// EdgeInsets.only(left: 8)
/// Icons.arrow_back
void scratch() {
  // DateTime.now() and import 'package:dio/dio.dart' live in a comment here
  /* EdgeInsets.only(right: 4) and Icons.arrow_forward too, across
     more than one line */
}
DART
expect_clean "needles inside stripped comments are not offenders"
rm -f "$scratch"

if [ "$failures" -ne 0 ]; then
  echo "check_bans_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_bans_selftest: OK"
