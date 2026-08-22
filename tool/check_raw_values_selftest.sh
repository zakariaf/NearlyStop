#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/check_raw_values.sh, and the composition arm through the
# single entry point. A gate that has never been seen to fail is a comment.
#
# Usage: bash tool/check_raw_values_selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/check_raw_values.sh
entry=tool/check_bans.sh
scratch=lib/features/_raw_scratch.dart
theme_scratch=lib/theme/_raw_scratch.dart
rtl_scratch=lib/features/_rtl_scratch.dart
failures=0

cleanup() { rm -f "$scratch" "$theme_scratch" "$rtl_scratch"; }
trap cleanup EXIT

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

# plant <path> <body>
plant() { printf '%s\n' "$2" >"$1"; }

# expect_gate <expected-exit> <description> [needle]
expect_gate() {
  local expected="$1" desc="$2" needle="${3:-}" out code
  out="$(bash "$gate" 2>&1)"
  code=$?
  if [ "$code" -ne "$expected" ]; then
    bad "$desc (expected exit $expected, got $code)"
    echo "$out" | sed 's/^/         /'
  elif [ -n "$needle" ] && ! grep -q "$needle" <<<"$out"; then
    bad "$desc (message never mentioned '$needle')"
  else
    pass "$desc"
  fi
}

echo "case 1: the clean tree"
expect_gate 0 "clean tree exits 0"

echo "case 2: a raw hex outside lib/theme/, and the one file allowed one"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
const Color scratchColor = Color(0xFF123456);"
expect_gate 1 "a planted Color(0xFF123456) in lib/features/ is flagged" "$scratch"
rm -f "$scratch"
plant "$theme_scratch" "import 'dart:ui';

/// Scratch.
const Color scratchColor = Color(0xFF123456);"
expect_gate 0 "the identical literal inside lib/theme/ passes"
rm -f "$theme_scratch"

echo "case 3: Colors.* is banned, Colors.transparent is not"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
const Color scratchColor = Colors.red;"
expect_gate 1 "Colors.red is flagged"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
const Color scratchColor = Colors.transparent;"
expect_gate 0 "Colors.transparent passes"

echo "case 4: a literal Duration is banned, Duration.zero is not"
plant "$scratch" "/// Scratch.
const Duration scratchDuration = Duration(milliseconds: 200);"
expect_gate 1 "Duration(milliseconds: 200) is flagged"
plant "$scratch" "/// Scratch.
const Duration scratchDuration = Duration.zero;"
expect_gate 0 "Duration.zero passes"

echo "case 5: the rule is a LITERAL radius, not the constructor"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
final BorderRadius scratchRadius = BorderRadius.circular(12);"
expect_gate 1 "BorderRadius.circular(12) is flagged"
plant "$scratch" "import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Scratch.
final BorderRadius scratchRadius = BorderRadius.circular(
  daybreakShapes.radiusSm,
);"
expect_gate 0 "BorderRadius.circular(shapes.radiusSm) passes"

echo "case 6: fontSize outside lib/theme/"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
const TextStyle scratchStyle = TextStyle(fontSize: 20);"
expect_gate 1 "fontSize: 20 in lib/features/ is flagged"
rm -f "$scratch"
plant "$theme_scratch" "import 'package:flutter/material.dart';

/// Scratch.
const TextStyle scratchStyle = TextStyle(fontSize: 20);"
expect_gate 0 "the identical fontSize inside lib/theme/ passes"
rm -f "$theme_scratch"

echo "case 7: Curves.* outside lib/theme/"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
const Curve scratchCurve = Curves.easeOut;"
expect_gate 1 "Curves.easeOut in lib/features/ is flagged"

echo "case 8: fromSeed and dynamic_color are gated, not merely promised"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
final ColorScheme scratchScheme = ColorScheme.fromSeed(seedColor: Colors.red);"
expect_gate 1 "ColorScheme.fromSeed( is flagged" "fromSeed"
plant "$scratch" "import 'package:dynamic_color/dynamic_color.dart';

/// Scratch.
void scratch() {}"
expect_gate 1 "a dynamic_color import is flagged"
rm -f "$scratch"

echo "case 9: every needle inside a stripped comment, and the gate's own source"
plant "$scratch" "/// Scratch.
///
/// Color(0xFF123456), Colors.red, Curves.easeOut,
/// Duration(milliseconds: 200), BorderRadius.circular(12), fontSize: 20,
/// ColorScheme.fromSeed(
void scratch() {
  // Color(0xFFAA0000) and fontSize: 14 live in a comment here
  /* Colors.blue and Duration(seconds: 1) too, across
     more than one line */
}"
expect_gate 0 "needles inside stripped comments are not offenders"
rm -f "$scratch"
expect_gate 0 "the gate is not red on its own source (tool/ is never scanned)"

echo "case 10: accumulate and fail ONCE through the single entry point"
plant "$scratch" "import 'package:flutter/material.dart';

/// Scratch.
const Color scratchColor = Color(0xFF123456);"
plant "$rtl_scratch" "import 'package:flutter/widgets.dart';

/// Scratch.
const EdgeInsets scratchPadding = EdgeInsets.only(left: 8);"
out="$(bash "$entry" 2>&1)"
code=$?
if [ "$code" -ne 1 ]; then
  bad "expected exit 1 from the entry point, got $code"
elif ! grep -q 'Color(0xFF123456)' <<<"$out"; then
  bad "the raw hex is missing — a sub-script's set -e killed the run early"
elif ! grep -q 'directional geometry' <<<"$out"; then
  bad "the RTL offender is missing"
else
  pass "one exit 1 from tool/check_bans.sh, both a raw hex and an RTL offender listed"
fi
rm -f "$scratch" "$rtl_scratch"

if [ "$failures" -ne 0 ]; then
  echo "check_raw_values_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_raw_values_selftest: OK"
