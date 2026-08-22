#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/verify_include_pin.sh, plus the never-trust-green ritual:
# a gate that has never been seen to fail is a comment.
#
# Usage: bash tool/verify_include_pin_selftest.sh
# Run from the repo root. Wired into CI.

cd "$(dirname "$0")/.."
gate=tool/verify_include_pin.sh
scratch=".verify_include_pin_selftest"
failures=0

cleanup() { rm -rf "$scratch" lib/_selftest_print.dart; }
trap cleanup EXIT

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

mkdir -p "$scratch"

echo "case 1: an include filename absent from the resolved package"
cat >"$scratch/options.yaml" <<'YAML'
include: package:very_good_analysis/analysis_options.99.0.0.yaml
YAML
out="$(bash "$gate" "$scratch/options.yaml" pubspec.lock 2>&1)"
code=$?
if [ "$code" -ne 1 ]; then
  bad "expected exit 1, got $code"
elif ! grep -q 'analysis_options.99.0.0.yaml' <<<"$out"; then
  bad "message does not name the missing filename"
elif ! grep -q 'very_good_analysis-.*/lib' <<<"$out"; then
  bad "message does not name the resolved package lib/ directory"
else
  pass "exit 1, names the missing filename and the directory it looked in"
fi

echo "case 2: the real analysis_options.yaml"
out="$(bash "$gate" analysis_options.yaml pubspec.lock 2>&1)"
code=$?
if [ "$code" -ne 0 ]; then
  bad "expected exit 0, got $code: $out"
else
  pass "exit 0 on the shipped config"
fi

echo "case 3: never trust green — a planted print() must still fail analysis"
cat >lib/_selftest_print.dart <<'DART'
/// Scratch file planted by tool/verify_include_pin_selftest.sh.
void selftestPrint() {
  print('x');
}
DART
out="$(flutter analyze --fatal-infos --fatal-warnings 2>&1)"
code=$?
if [ "$code" -eq 0 ]; then
  bad "analyze passed over a planted print() — the ruleset is not applied"
elif ! grep -q 'avoid_print' <<<"$out"; then
  bad "analyze failed but never named avoid_print"
else
  pass "analyze fails and names avoid_print"
fi
rm -f lib/_selftest_print.dart
out="$(flutter analyze --fatal-infos --fatal-warnings 2>&1)"
code=$?
if [ "$code" -ne 0 ]; then
  bad "analyze still red after removing the planted file: $out"
else
  pass "analyze green again once the violation is removed"
fi

# case 4 (the riverpod_lint plugin, both arms) is DEFERRED and the reason is
# recorded at the bottom of analysis_options.yaml: on this toolchain the
# first-party plugin block reported nothing and hung `dart analyze`. Assert the
# deferral is still documented so re-adding the block is a deliberate act.
echo "case 4: the riverpod_lint deferral is recorded"
if grep -q 'riverpod_lint is DEFERRED' analysis_options.yaml; then
  pass "deferral recorded in analysis_options.yaml"
else
  bad "the riverpod_lint deferral note is gone — re-run the planted-violation check"
fi

if [ "$failures" -ne 0 ]; then
  echo "verify_include_pin_selftest: $failures case(s) failed"
  exit 1
fi
echo "verify_include_pin_selftest: OK"
