#!/usr/bin/env bash
set -uo pipefail
# Both arms of tool/coverage_floor.sh, driven by the hand-written lcov fixtures
# under tool/fixtures/lcov/. No `flutter test` runs inside this self-test — the
# fixtures ARE the input, so a case is ten lines and never flakes.
#
# Usage: bash tool/coverage_floor_selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/coverage_floor.sh
fixtures=tool/fixtures/lcov
scratch=".coverage_floor_selftest"
failures=0

cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT
mkdir -p "$scratch"

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

# run <lcov> <floors>
run() {
  out="$(bash "$gate" "$1" "$2" analysis_options.yaml 2>&1)"
  code=$?
}

: >"$scratch/empty_floors.txt"
cat >"$scratch/step_size_100.txt" <<'EOF'
# a floor on one file where a bug is unrecoverable
lib/core/dsns/step_size.dart 100
EOF

echo "case 1: an empty floor list passes on any fixture"
for fixture in "$fixtures"/*.info; do
  run "$fixture" "$scratch/empty_floors.txt"
  if [ "$code" -ne 0 ]; then
    bad "empty floors should pass on $(basename "$fixture") (exit $code)"
    echo "$out" | sed 's/^/         /'
  fi
done
[ "$failures" -eq 0 ] && pass "every fixture passes with no floors declared"

echo "case 2: a 100% floor met exactly (12/12)"
run "$fixtures/full.info" "$scratch/step_size_100.txt"
if [ "$code" -ne 0 ]; then
  bad "expected exit 0, got $code"
  echo "$out" | sed 's/^/         /'
else
  pass "12/12 against a 100% floor exits 0"
fi

echo "case 3: the same floor missed (7/12)"
run "$fixtures/partial.info" "$scratch/step_size_100.txt"
if [ "$code" -ne 1 ]; then
  bad "expected exit 1, got $code"
elif ! grep -q 'lib/core/dsns/step_size.dart' <<<"$out"; then
  bad "message does not name the path"
elif ! grep -q '58\.3%' <<<"$out"; then
  bad "message does not report 58.3%"
elif ! grep -q '100% floor' <<<"$out"; then
  bad "message does not report the 100% floor"
else
  pass "exit 1 naming the path, 58.3% and the 100% floor"
fi

echo "case 4: a listed path absent from lcov.info is a FAILURE, not a skip"
run "$fixtures/missing_path.info" "$scratch/step_size_100.txt"
if [ "$code" -ne 1 ]; then
  bad "expected exit 1, got $code — a rename would disarm the floor silently"
elif ! grep -q 'lib/core/dsns/step_size.dart' <<<"$out"; then
  bad "message does not name the missing path"
elif ! grep -qi 'absent' <<<"$out"; then
  bad "message does not say the path is absent"
else
  pass "exit 1 naming the missing path"
fi

echo "case 5: generated code is stripped using the analyzer's OWN globs"
run "$fixtures/with_generated.info" "$scratch/step_size_100.txt"
if [ "$code" -ne 0 ]; then
  bad "expected exit 0, got $code"
  echo "$out" | sed 's/^/         /'
elif ! grep -q 'lib/l10n/gen/app_localizations.dart' <<<"$out"; then
  bad "the l10n gen file was not reported as excluded"
elif ! grep -q 'lib/data/db.g.dart' <<<"$out"; then
  bad "the .g.dart file was not reported as excluded"
elif ! grep -q 'aggregate 100.0%' <<<"$out"; then
  bad "the 1300 generated lines were not removed before the aggregate"
else
  pass "both generated files stripped; aggregate computed without them"
fi
# The globs are read from analysis_options.yaml, not retyped in the gate. Prove
# it by asserting the gate names that file and holds no glob of its own.
if grep -qE "'\*\*/\*\.g\.dart'|\"\*\*/\*\.g\.dart\"" "$gate"; then
  bad "the gate hardcodes a generated-file glob — it must read analysis_options.yaml"
elif ! grep -q 'analysis_options.yaml' "$gate"; then
  bad "the gate never mentions analysis_options.yaml as the source of the globs"
else
  pass "the globs live in exactly one place (analysis_options.yaml)"
fi

echo "case 6: an untested lib/ file is REPORTED, not gated — and drops the aggregate"
run "$fixtures/tested_only.info" "$scratch/empty_floors.txt"
tested_only_pct="$(sed -E -n 's/.*aggregate ([0-9.]+)%.*/\1/p' <<<"$out")"
run "$fixtures/with_untested.info" "$scratch/empty_floors.txt"
with_untested_code=$code
with_untested_pct="$(sed -E -n 's/.*aggregate ([0-9.]+)%.*/\1/p' <<<"$out")"
if [ "$with_untested_code" -ne 0 ]; then
  bad "an untested file must be reported, never gated (exit $with_untested_code)"
elif [ -z "$tested_only_pct" ] || [ -z "$with_untested_pct" ]; then
  bad "the gate did not print an aggregate percentage"
elif ! awk -v a="$tested_only_pct" -v b="$with_untested_pct" 'BEGIN { exit !(b < a) }'; then
  bad "aggregate did not drop: $tested_only_pct% -> $with_untested_pct%"
else
  pass "aggregate drops $tested_only_pct% -> $with_untested_pct% once the untested file counts"
fi

echo "case 7: duplicate SF: records for one path are MERGED per line, never summed"
run "$fixtures/duplicate_records.info" "$scratch/step_size_100.txt"
if [ "$code" -ne 0 ]; then
  bad "two records covering 3 distinct lines between them must read 3/3 (exit $code)"
  echo "$out" | sed 's/^/         /'
elif ! grep -q '(3/3 lines)' <<<"$out"; then
  bad "records were summed, not merged: $out"
else
  pass "3/3 lines, not 6/4 — a second --coverage pass cannot fail a covered file"
fi

if [ "$failures" -ne 0 ]; then
  echo "coverage_floor_selftest: $failures case(s) failed"
  exit 1
fi
echo "coverage_floor_selftest: OK"
