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
data_scratch=lib/data/_bans_scratch.dart
clock=lib/core/time/clock.dart
clock_backup=".clock.bak"
failures=0

cleanup() {
  rm -f "$scratch" "$scratch2" "$data_scratch"
  rm -rf lib/features/_scratchfeature
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

echo "case 2b: dynamic_color and a no-op FontVariation axis"
cat >"$scratch" <<'DART'
import 'package:dynamic_color/dynamic_color.dart';

/// Scratch.
void scratch() {}
DART
expect_flagged "a dynamic_color import is flagged" "$scratch" "zero network calls"
cat >"$scratch" <<'DART'
import 'package:flutter/material.dart';

/// Scratch: neither bundled face exposes an optical-size axis.
const List<FontVariation> scratch = <FontVariation>[FontVariation('opsz', 14)];
DART
expect_flagged "FontVariation('opsz') is flagged" "$scratch" "wght axis only"
cat >"$scratch" <<'DART'
import 'package:flutter/material.dart';

/// Scratch.
const List<FontVariation> scratch = <FontVariation>[FontVariation('wght', 800)];
DART
expect_clean "FontVariation('wght') passes — it is how the ladder reaches the face"

echo "case 3: hardcoded left/right padding"
cat >"$scratch" <<'DART'
import 'package:flutter/widgets.dart';

/// Scratch.
const EdgeInsets scratchPadding = EdgeInsets.only(left: 8);
DART
expect_flagged "planted EdgeInsets.only(left:) is named with the RTL reason" \
  "$scratch" "directional geometry"

echo "case 4: two offenders in TWO files — accumulate and fail ONCE with both"
cat >"$scratch" <<'DART'
import 'package:http/http.dart';

/// Scratch.
void scratch() {}
DART
cat >"$scratch2" <<'DART'
import 'package:flutter/widgets.dart';

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
elif ! grep -q "$scratch2" <<<"$out"; then
  bad "the second FILE is missing — accumulation stops at the first offending file"
else
  pass "one exit 1, both offenders listed across two files"
fi
rm -f "$scratch2"

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

echo "case 9: an unterminated /* inside a STRING must not blank the rest of the file"
cat >"$scratch" <<'DART'
/// Scratch.
const String globPattern = '/*';

/// A wall-clock read that must still be seen after the string above.
DateTime scratchNow() => DateTime.now();
DART
expect_flagged "a '/*' string literal does not disarm the rules below it" \
  "$scratch" "never DateTime.now()"

echo "case 10: the socket half of the zero-network promise"
cat >"$scratch" <<'DART'
import 'dart:io';

/// Scratch.
HttpClient scratchClient() => HttpClient();
DART
expect_flagged "HttpClient() from dart:io is flagged" "$scratch" "socket API in lib/"
cat >"$scratch" <<'DART'
import 'package:web_socket_channel/web_socket_channel.dart';

/// Scratch.
void scratch() {}
DART
expect_flagged "a web_socket_channel import is flagged" "$scratch" "zero network calls"
cat >"$scratch" <<'DART'
import 'dart:io';

/// Scratch: reading and writing a backup file is legitimate; sockets are not.
Future<String> scratchRead(File f) => f.readAsString();
DART
expect_clean "dart:io file IO passes — EPIC-13 writes a backup file"

echo "case 11: there is no Unit type under lib/"
cat >"$scratch" <<'DART'
/// Scratch.
typedef Unit = void;
DART
expect_flagged "a Unit typedef is flagged" "$scratch" "no Unit type"
rm -f "$scratch"

echo "case 12: the gate refuses to report OK on a tree it could not scan"
out="$(bash "$gate" /definitely/not/a/directory 2>&1)"
code=$?
if [ "$code" -eq 0 ]; then
  bad "a bad ROOT reported success — a mistyped CI variable would silence the gate"
elif ! grep -qi 'cannot enter' <<<"$out"; then
  bad "a bad ROOT failed but never said why"
else
  pass "a bad ROOT exits non-zero and says so"
fi

echo "case 12b: drift stays behind lib/data/"
cat >"$scratch" <<'DART'
import 'package:drift/drift.dart';

/// Scratch.
void scratch() {}
DART
expect_flagged "a package:drift import outside lib/data/ is flagged" \
  "$scratch" "drift lives behind lib/data/"
rm -f "$scratch"

cat >"$data_scratch" <<'DART'
import 'package:drift/drift.dart';

/// Scratch.
void scratch() {}
DART
run_gate
if [ "$code" -ne 0 ]; then
  bad "the identical import inside lib/data/ should be exempt (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "the identical import inside lib/data/ is exempt — the glob resolves"
fi
rm -f "$data_scratch"

echo "case 12c: drift_dev never reaches the shipping compile path"
cat >"$data_scratch" <<'DART'
import 'package:drift_dev/api/migrations.dart';

/// Scratch.
void scratch() {}
DART
expect_flagged "a package:drift_dev import is flagged even inside lib/data/" \
  "$data_scratch" "dev dependency"
rm -f "$data_scratch"

echo "case 12d: text is never shrunk to fit"
cat >"$scratch" <<'DART'
import 'package:flutter/widgets.dart';

/// Scratch.
Widget scratch() => const FittedBox(child: Text('9'));
DART
expect_flagged "a planted FittedBox is flagged" "$scratch" "never shrink text"

cat >"$scratch" <<'DART'
/// Scratch. The BAN is discussed in a comment: FittedBox, .toUpperCase().
String scratch() => 'ok';
DART
expect_clean "the same words in a COMMENT pass — the gate strips comments"
rm -f "$scratch"

echo "case 12e: casing lives in the ARB, not at render"
cat >"$scratch" <<'DART'
/// Scratch.
String scratch(String label) => label.toUpperCase();
DART
expect_flagged "a planted .toUpperCase() is flagged" "$scratch" "casing belongs in the ARB"
rm -f "$scratch"

echo "case 12f: no hand-rolled digit tables"
cat >"$scratch" <<'DART'
/// Scratch.
const faDigits = <String>['\u06F0', '\u06F1', '\u06F2'];
DART
expect_clean "escaped code points are not a digit TABLE the eye can misread"

printf '/// Scratch.\nconst faDigits = <String>[%s];\n' \
  "'\u06F0','\u06F1','\u06F2'" >/dev/null
cat >"$scratch" <<'DART'
/// Scratch.
const faDigits = '۰۱۲۳۴۵۶۷۸۹';
DART
expect_flagged "a literal Persian digit table is flagged" \
  "$scratch" "never hand-roll a digit table"

cat >"$scratch" <<'DART'
/// Scratch. The Arabic-Indic block ٠١٢ is wrong for fa, says this COMMENT.
const note = 'ok';
DART
expect_clean "the same digits in a comment pass — the gate strips comments"
rm -f "$scratch"

echo "case 12g: the file that documents the block needs no exemption"
# It carries the digits only inside a `//` comment, and the gate strips
# comments, so it passes the rule on its own terms. This case exists because an
# earlier version of the self-test asserted the OPPOSITE of what it printed —
# a negated grep that reported ok precisely when the block was absent.
if awk -f tool/strip_comments.awk lib/l10n/number_formats.dart \
  | grep -qE '[۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩]'; then
  bad "number_formats.dart has Perso-Arabic digits in CODE, not just comments"
else
  pass "number_formats.dart carries the block in comments only"
fi
run_gate
if [ "$code" -ne 0 ]; then
  bad "the real tree fails the digit ban (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "the real tree passes with no exemption for it"
fi

echo "case 12h: route paths live in one file"
cat >"$scratch" <<'DART'
/// Scratch.
void scratch() {
  const destination = '/today';
  print(destination);
}
DART
expect_flagged "a planted route literal is flagged" \
  "$scratch" "routes.dart"

cat >"$scratch" <<'DART'
import 'package:nearlystop/routing/routes.dart';

/// Scratch.
String scratch() => Routes.today;
DART
expect_clean "reading the constant passes — that is the whole point"
rm -f "$scratch"

run_gate
if [ "$code" -ne 0 ]; then
  bad "routes.dart itself is flagged by its own rule (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "routes.dart is exempt from the rule it exists to enforce"
fi

echo "case 12i: the OS text scale is never clamped down"
cat >"$scratch" <<'DART'
import 'package:flutter/widgets.dart';

/// Scratch.
Widget scratch(Widget child) =>
    MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child);
DART
expect_flagged "a planted withClampedTextScaling is flagged" \
  "$scratch" "never clamp the OS text scale"
rm -f "$scratch"

echo "case 13: the gate works from an arbitrary ROOT, not just the repo root"
alt="$(mktemp -d)"
mkdir -p "$alt/lib/features"
cp analysis_options.yaml "$alt/"
cat >"$alt/lib/features/planted.dart" <<'DART'
import 'package:http/http.dart';

/// Scratch.
void scratch() {}
DART
out="$(bash "$gate" "$alt" 2>&1)"
code=$?
rm -rf "$alt"
if [ "$code" -ne 1 ]; then
  bad "the gate did not flag a planted import under an explicit ROOT (exit $code)"
elif ! grep -q 'zero network calls' <<<"$out"; then
  bad "the gate ran under an explicit ROOT but scanned an empty haystack"
else
  pass "an explicit ROOT is scanned, not silently skipped"
fi

echo "case 14: the presentation-widget layering rules, and their SCOPE"
widget_dir=lib/features/_scratchfeature/presentation/widgets
mkdir -p "$widget_dir"
widget="$widget_dir/planted.dart"

cat >"$widget" <<'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scratch.
void scratch() {}
DART
expect_flagged "a widget importing Riverpod is flagged" \
  "$widget" "a presentation widget may not import drift"

cat >"$widget" <<'DART'
import 'package:flutter/material.dart';

/// Scratch.
class Scratch extends ConsumerWidget {}
DART
expect_flagged "a widget naming ConsumerWidget is flagged" \
  "$widget" "a presentation widget may not name WidgetRef"

# The other arm, and the one that matters: the rule is CONFINED. A screen —
# one directory up from `widgets/` — is exactly where the Consumer belongs, and
# a rule that flagged it would be a rule somebody deletes.
cat >"$widget_dir/../planted_screen.dart" <<'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scratch.
abstract class Scratch extends ConsumerWidget {}
DART
rm -f "$widget"
expect_clean "the same import in a SCREEN, one level up, is allowed"
rm -rf lib/features/_scratchfeature

if [ "$failures" -ne 0 ]; then
  echo "check_bans_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_bans_selftest: OK"
