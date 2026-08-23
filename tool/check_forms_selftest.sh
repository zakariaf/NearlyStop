#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/check_forms.sh. A gate that has only ever been green is a
# comment, and each of the three rules has a SCOPE that is only proven real by
# the case showing it is scoped rather than absent.
#
# Usage: bash tool/check_forms_selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/check_forms.sh
failures=0

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

# Every case runs against a THROWAWAY tree, so the gate is exercised on a
# haystack whose whole content is known — and the repo is never edited.
scratch_root() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/lib/features/plan/presentation" "$dir/lib/core/units" \
    "$dir/lib/l10n" "$dir/lib/data"
  cat >"$dir/lib/features/plan/presentation/clean.dart" <<'DART'
/// Scratch: a field done right.
class Clean {
  final controller = TextEditingController();
  void dispose() => controller.dispose();
}
DART
  echo "$dir"
}

run_on() {
  out="$(bash "$gate" "$1" 2>&1)"
  code=$?
}

echo "case 1: a clean tree"
dir="$(scratch_root)"
run_on "$dir"
if [ "$code" -ne 0 ]; then
  bad "expected exit 0, got $code"
  echo "$out" | sed 's/^/         /'
else
  pass "a controller created and disposed passes"
fi
rm -rf "$dir"

echo "case 2: a controller created and never disposed"
for kind in TextEditingController FocusNode ScrollController; do
  dir="$(scratch_root)"
  cat >"$dir/lib/features/plan/presentation/planted.dart" <<DART
/// Scratch.
class Planted {
  final thing = $kind();
}
DART
  run_on "$dir"
  if [ "$code" -ne 1 ]; then
    bad "an undisposed $kind was not rejected (exit $code)"
  elif ! grep -q 'planted.dart' <<<"$out"; then
    bad "an undisposed $kind was rejected but the file was not named"
  else
    pass "an undisposed $kind is rejected, by name"
  fi
  rm -rf "$dir"
done

echo "case 3: the disposal rule reads the CODE, not the comments"
dir="$(scratch_root)"
cat >"$dir/lib/features/plan/presentation/planted.dart" <<'DART'
/// Scratch.
///
/// This doc comment says .dispose() and that must not satisfy the gate.
class Planted {
  final thing = TextEditingController();
}
DART
run_on "$dir"
if [ "$code" -ne 1 ]; then
  bad "a .dispose() in a COMMENT satisfied the gate (exit $code)"
else
  pass "a .dispose() in a comment does not count"
fi
rm -rf "$dir"

echo "case 4: a second input formatter"
dir="$(scratch_root)"
cat >"$dir/lib/features/plan/presentation/planted.dart" <<'DART'
/// Scratch.
final f = FilteringTextInputFormatter.digitsOnly;
DART
run_on "$dir"
if [ "$code" -ne 1 ]; then
  bad "FilteringTextInputFormatter was not rejected (exit $code)"
elif ! grep -q 'kDoseInputFormatter' <<<"$out"; then
  bad "rejected, but the message does not name the one to use instead"
else
  pass "FilteringTextInputFormatter is rejected, and names the replacement"
fi
rm -rf "$dir"

echo "case 5: the formatter rule is SCOPED to lib/l10n/"
dir="$(scratch_root)"
cat >"$dir/lib/l10n/numeric_input.dart" <<'DART'
/// Scratch: the one legal home.
final f = TextInputFormatter.withFunction((a, b) => b);
DART
run_on "$dir"
if [ "$code" -ne 0 ]; then
  bad "a formatter under lib/l10n/ must be allowed (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "TextInputFormatter.withFunction is allowed under lib/l10n/"
fi
cp "$dir/lib/l10n/numeric_input.dart" "$dir/lib/features/plan/presentation/planted.dart"
run_on "$dir"
if [ "$code" -ne 1 ]; then
  bad "the identical formatter under lib/features/ must be rejected (exit $code)"
else
  pass "the identical formatter under lib/features/ is rejected — the home is scoped"
fi
rm -rf "$dir"

echo "case 6: a direct parse of user text"
for call in 'double.parse(raw)' 'int.tryParse(raw)' 'num.parse(raw)'; do
  dir="$(scratch_root)"
  cat >"$dir/lib/features/plan/presentation/planted.dart" <<DART
/// Scratch.
final v = $call;
DART
  run_on "$dir"
  if [ "$code" -ne 1 ]; then
    bad "$call under lib/features/ was not rejected (exit $code)"
  elif ! grep -q 'parseDose' <<<"$out"; then
    bad "$call was rejected but the message does not name parseDose"
  else
    pass "$call under lib/features/ is rejected"
  fi
  rm -rf "$dir"
done

echo "case 7: the parse rule is SCOPED to the canonical parsers"
dir="$(scratch_root)"
cat >"$dir/lib/core/units/milligrams.dart" <<'DART'
/// Scratch: the domain's own funnel has to be built out of something.
final v = int.parse(whole);
DART
cat >"$dir/lib/l10n/number_formats.dart" <<'DART'
/// Scratch: the locale layer folds the digits, then delegates.
final v = int.tryParse(ascii);
DART
run_on "$dir"
if [ "$code" -ne 0 ]; then
  bad "lib/core/ and lib/l10n/ must be allowed to parse (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "the canonical parsers are allowed; every other layer delegates"
fi
cp "$dir/lib/core/units/milligrams.dart" "$dir/lib/data/planted.dart"
run_on "$dir"
if [ "$code" -ne 1 ]; then
  bad "the identical parse under lib/data/ must be rejected (exit $code)"
else
  pass "the identical parse under lib/data/ is rejected — the exemption is scoped"
fi
rm -rf "$dir"

echo "case 7b: the storage-converter exemption is one FILE, not lib/data/"
dir="$(scratch_root)"
mkdir -p "$dir/lib/data/db"
cat >"$dir/lib/data/db/converters.dart" <<'DART'
/// Scratch: reads back a string the app itself wrote.
final v = int.tryParse(part);
DART
run_on "$dir"
if [ "$code" -ne 0 ]; then
  bad "lib/data/db/converters.dart must be allowed to parse (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "the storage converter may parse its own encoding"
fi
cp "$dir/lib/data/db/converters.dart" "$dir/lib/data/db/importer.dart"
run_on "$dir"
if [ "$code" -ne 1 ]; then
  bad "the identical parse in a NEIGHBOURING file must be rejected (exit $code)"
else
  pass "a neighbour in the same directory is still rejected — the exemption is one file"
fi
rm -rf "$dir"

echo "case 8: generated localizations are not the app's code"
dir="$(scratch_root)"
mkdir -p "$dir/lib/l10n/gen"
cat >"$dir/lib/l10n/gen/app_localizations.dart" <<'DART'
/// Scratch: gen-l10n output, not hand-written.
final c = TextEditingController();
DART
run_on "$dir"
if [ "$code" -ne 0 ]; then
  bad "lib/l10n/gen/ must be skipped (exit $code)"
  echo "$out" | sed 's/^/         /'
else
  pass "lib/l10n/gen/ is skipped — it is regenerated, not reviewed"
fi
rm -rf "$dir"

echo "case 9: the gate refuses to report OK on a tree it could not scan"
out="$(bash "$gate" /definitely/not/a/directory 2>&1)"
code=$?
if [ "$code" -eq 0 ]; then
  bad "a bad ROOT reported success"
elif ! grep -qi 'cannot enter' <<<"$out"; then
  bad "a bad ROOT failed but never said why"
else
  pass "a bad ROOT exits non-zero and says so"
fi

echo "case 10: an empty lib/ is not a pass"
dir="$(mktemp -d)"
mkdir -p "$dir/lib"
run_on "$dir"
rm -rf "$dir"
if [ "$code" -eq 0 ]; then
  bad "a lib/ with no Dart files reported OK"
elif ! grep -q 'scanned 0 files' <<<"$out"; then
  bad "an empty lib/ failed but never said the haystack was empty"
else
  pass "scanning nothing is reported, not rewarded"
fi

echo "case 11: the real repo passes"
run_on "$(pwd)"
if [ "$code" -ne 0 ]; then
  bad "the repository itself does not pass its own gate"
  echo "$out" | sed 's/^/         /'
else
  pass "the repository passes"
fi

if [ "$failures" -ne 0 ]; then
  echo "check_forms_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_forms_selftest: OK"
