#!/usr/bin/env bash
set -uo pipefail
# check_core_purity.sh — lib/core/ is the pure foundation. The missing Flutter
# import is a compile firewall: it is what lets the domain be unit-tested in
# milliseconds with package:test and no widget harness, and what stops a
# framework type leaking into the 52-day arithmetic.
#
# Usage: bash tool/check_core_purity.sh [ROOT]   (ROOT defaults to the repo root)
#
# Extended by EPIC-04 (which adds files, not a second walker). CONTRACTS.md §2
# is the contract.

cd "${1:-$(dirname "$0")/..}"

core=lib/core
offenders=()

# The four riverpod spellings are listed SEPARATELY on purpose:
# "package:riverpod" is not a substring of "package:flutter_riverpod", and one
# loose pattern would pass one of these and leave a hole the shape of the rest.
banned_uris=(
  "package:flutter/"
  "package:flutter_riverpod/"
  "package:hooks_riverpod/"
  "package:riverpod/"
  "package:drift/"
  "package:flutter_test/"
  "dart:ui"
  "package:timezone/"
)

# The ONE exception, encoded here rather than discovered later: a scheduling
# core without TZDateTime cannot express "08:00 local on this date".
# package:timezone stays banned everywhere else under lib/core/. Outside
# lib/core/ it is EPIC-12 that confines flutter_local_notifications and
# flutter_timezone — not timezone — to the single gateway file.
timezone_exception_dir="lib/core/notifications/"

if [ ! -d "$core" ]; then
  echo "check_core_purity: $core does not exist"
  exit 2
fi

strip_comments() {
  awk '
    BEGIN { inblock = 0 }
    {
      line = $0; out = ""; i = 1; n = length(line)
      while (i <= n) {
        two = substr(line, i, 2)
        if (inblock) {
          if (two == "*/") { inblock = 0; i += 2 } else { i++ }
        } else if (two == "/*") {
          inblock = 1; i += 2
        } else if (two == "//") {
          break
        } else {
          out = out substr(line, i, 1); i++
        }
      }
      print out
    }
  ' "$1"
}

while IFS= read -r file; do
  [ -n "$file" ] || continue
  stripped="$(strip_comments "$file")"
  for uri in "${banned_uris[@]}"; do
    if [ "$uri" = "package:timezone/" ] && [[ "$file" == "$timezone_exception_dir"* ]]; then
      continue
    fi
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      offenders+=("$file:${hit%%:*}: imports $uri"$'\n'"        ${hit#*:}")
    done < <(grep -nE "^[[:space:]]*(import|export)[[:space:]]+['\"]${uri//\//\\/}" <<<"$stripped" || true)
  done
done < <(find "$core" -type f -name '*.dart' | sort)

if [ "${#offenders[@]}" -ne 0 ]; then
  echo "check_core_purity: ${#offenders[@]} violation(s) under $core/."
  echo
  for o in "${offenders[@]}"; do
    echo "  $o"
    echo
  done
  echo "lib/core/ is pure Dart: no Flutter, no Riverpod, no drift, no dart:ui."
  echo "package:timezone is allowed under ${timezone_exception_dir} and nowhere else."
  exit 1
fi

echo "check_core_purity: OK"
