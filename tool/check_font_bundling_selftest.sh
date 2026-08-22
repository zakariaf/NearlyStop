#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/check_font_bundling.sh.
#
# Usage: bash tool/check_font_bundling_selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/check_font_bundling.sh
scratch=lib/features/_font_scratch.dart
fixture_lock=".font_selftest_lock"
failures=0

cleanup() { rm -f "$scratch" "$fixture_lock"; }
trap cleanup EXIT

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

echo "case 1: the clean tree"
out="$(bash "$gate" 2>&1)"
if [ $? -ne 0 ]; then
  bad "clean tree should exit 0"
  echo "$out" | sed 's/^/         /'
else
  pass "clean tree exits 0"
fi

echo "case 2: a google_fonts import"
cat >"$scratch" <<'DART'
import 'package:google_fonts/google_fonts.dart';

/// Scratch.
void scratch() {}
DART
out="$(bash "$gate" 2>&1)"
code=$?
if [ "$code" -ne 1 ]; then
  bad "a google_fonts import must be refused (exit $code)"
elif ! grep -q 'google_fonts' <<<"$out"; then
  bad "refused but never named google_fonts"
else
  pass "a google_fonts import is refused"
fi

echo "case 3: a FontVariation on an axis the shipped faces do not have"
cat >"$scratch" <<'DART'
import 'package:flutter/material.dart';

/// Scratch: both bundled faces expose `wght` only, so `opsz` no-ops silently.
const List<FontVariation> scratch = <FontVariation>[FontVariation('opsz', 14)];
DART
out="$(bash "$gate" 2>&1)"
if [ $? -ne 1 ]; then
  bad "FontVariation('opsz') must be refused"
else
  pass "FontVariation('opsz') is refused — it no-ops silently otherwise"
fi
rm -f "$scratch"

echo "case 4: the wght axis the faces DO expose passes"
cat >"$scratch" <<'DART'
import 'package:flutter/material.dart';

/// Scratch.
const List<FontVariation> scratch = <FontVariation>[FontVariation('wght', 800)];
DART
out="$(bash "$gate" 2>&1)"
if [ $? -ne 0 ]; then
  bad "FontVariation('wght') must pass — it is how the ladder reaches the face"
  echo "$out" | sed 's/^/         /'
else
  pass "FontVariation('wght') passes"
fi
rm -f "$scratch"

echo "case 5: the real lockfile holds no google_fonts"
if grep -q '^  google_fonts:' pubspec.lock; then
  bad "google_fonts is in pubspec.lock"
else
  pass "pubspec.lock is clean"
fi
printf '  google_fonts:\n    dependency: "direct main"\n' >"$fixture_lock"
if grep -q '^  google_fonts:' "$fixture_lock"; then
  pass "the same check DOES find it in a fixture lock — both arms asserted"
else
  bad "the lockfile check cannot detect google_fonts at all"
fi

if [ "$failures" -ne 0 ]; then
  echo "check_font_bundling_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_font_bundling_selftest: OK"
