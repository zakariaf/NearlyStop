#!/usr/bin/env bash
set -uo pipefail
# check_bundle_id.sh — print every place the bundle identifier is written.
#
# The identifier is going to change before this app is published, and a bundle
# ID is PERMANENT on both stores once a build is accepted under it. So the
# change has to be a mechanical sweep with nothing missed, not a hunt.
#
# Usage: bash tool/check_bundle_id.sh [ROOT]
#
# Exits 0 always — this is an inventory, not a gate. What IS a gate is that the
# count matches what `docs/release/RELEASING.md` documents; a new hardcoded
# occurrence appearing in Dart source is caught by `check_bans.sh`.

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$root" || exit 2

id="$(sed -n 's/.*applicationId[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' \
  android/app/build.gradle.kts | head -1)"

if [ -z "$id" ]; then
  echo "check_bundle_id: no applicationId found in android/app/build.gradle.kts"
  exit 2
fi

echo "bundle identifier: $id"
echo

# `--` before the pattern: an identifier starting with a dash would otherwise
# be read as a flag.
grep -rn --binary-files=without-match -- "$id" \
  android ios lib test tool docs store 2>/dev/null |
  grep -v '^docs/release/RELEASING.md' |
  grep -v '^tool/check_bundle_id.sh' |
  sed 's/^/  /'

echo
echo "occurrences: $(grep -rl --binary-files=without-match -- "$id" \
  android ios lib test tool 2>/dev/null | grep -vc 'check_bundle_id.sh')" \
  "file(s)"
