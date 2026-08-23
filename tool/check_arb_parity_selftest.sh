#!/usr/bin/env bash
set -uo pipefail
# Both arms of every rule in tool/check_arb_parity.sh, against checked-in
# fixtures. A gate that has never been seen to fail is a comment.
#
# Usage: bash tool/check_arb_parity_selftest.sh   (from the repo root; in CI)

cd "$(dirname "$0")/.."
gate=tool/check_arb_parity.sh
clean=tool/fixtures/arb/clean
work="$(mktemp -d)"
# The python heredocs below edit the working copy; they read this.
export WORK="$work"
failures=0

cleanup() { rm -rf "$work"; return 0; }
trap cleanup EXIT

pass() { echo "  ok   — $1"; }
bad() {
  echo "  FAIL — $1"
  failures=$((failures + 1))
}

# reset → a pristine copy of the clean set in $work
reset() {
  rm -rf "${work:?}"/*
  cp "$clean"/*.arb "$work/"
}

run_gate() {
  out="$(bash "$gate" "$work" 2>&1)"
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

# expect_flagged <description> <needle> [<second needle>]
expect_flagged() {
  local desc="$1" needle="$2" needle2="${3:-}"
  run_gate
  if [ "$code" -ne 1 ]; then
    bad "$desc (expected exit 1, got $code)"
    echo "$out" | sed 's/^/         /'
  elif ! grep -q "$needle" <<<"$out"; then
    bad "$desc (message never mentioned '$needle')"
    echo "$out" | sed 's/^/         /'
  elif [ -n "$needle2" ] && ! grep -q "$needle2" <<<"$out"; then
    bad "$desc (message never mentioned '$needle2')"
    echo "$out" | sed 's/^/         /'
  else
    pass "$desc"
  fi
}

echo "case 1: the clean four-file set"
reset
expect_clean "a complete, consistent set exits 0"

echo "case 2: a key deleted from a translation"
reset
python3 - <<'PY'
import json, os, sys
p = os.path.join(os.environ['WORK'], 'app_de.arb')
d = json.load(open(p, encoding='utf-8')); del d['greeting']
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY
expect_flagged "a deleted key is named with its file" "app_de.arb" "greeting"

echo "case 3: a key the template does not have"
reset
python3 - <<'PY'
import json, os
p = os.path.join(os.environ['WORK'], 'app_fa.arb')
d = json.load(open(p, encoding='utf-8')); d['invented'] = 'چیزی'
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY
expect_flagged "an extra key is flagged" "app_fa.arb" "not in the template"

echo "case 4: a renamed placeholder — breaks at RUNTIME, not build time"
reset
python3 - <<'PY'
import json, os
p = os.path.join(os.environ['WORK'], 'app_fa.arb')
d = json.load(open(p, encoding='utf-8'))
d['takenDays'] = '{n, plural, other{{n} روز}}'
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY
expect_flagged "a renamed placeholder names key and placeholder" "takenDays" "count"

echo "case 5: ICU branch SHAPES, but not bodies"
reset
python3 - <<'PY'
import json, os
p = os.path.join(os.environ['WORK'], 'app_de.arb')
d = json.load(open(p, encoding='utf-8'))
d['takenDays'] = 'ein paar Tage'
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY
expect_flagged "a plural flattened to a plain string is flagged" "plain string"

reset
python3 - <<'PY'
import json, os
# Dropping `one` is LEGITIMATE — fa and ckb have no singular. Only the absence
# of `other` is a defect, and differing bodies are what translation IS.
p = os.path.join(os.environ['WORK'], 'app_de.arb')
d = json.load(open(p, encoding='utf-8'))
d['takenDays'] = '{count, plural, other{voellig andere Woerter}}'
json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY
expect_clean 'dropping one and rewording other passes — that is translation'

echo "case 6: a DELETED locale, which iterating the directory cannot see"
reset
rm -f "$work/app_fa.arb"
expect_flagged "a missing locale file is named" "app_fa.arb" "MISSING"

reset
cp "$work/app_de.arb" "$work/app_it.arb"
expect_flagged "a locale the app does not ship is flagged" "app_it.arb"

if [ "$failures" -ne 0 ]; then
  echo "check_arb_parity_selftest: $failures case(s) failed"
  exit 1
fi
echo "check_arb_parity_selftest: OK"
