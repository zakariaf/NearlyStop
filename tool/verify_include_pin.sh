#!/usr/bin/env bash
set -euo pipefail
# verify_include_pin.sh — the gate for the trap that silently disables every
# lint. If the version-pinned `include:` names a file that is absent from the
# RESOLVED linter package, the analyzer emits one include_file_not_found and
# then runs with zero added rules: a green build that checks nothing.
#
# Usage: tool/verify_include_pin.sh [ANALYSIS_OPTIONS] [PUBSPEC_LOCK]
#        defaults: ./analysis_options.yaml ./pubspec.lock
#
# Messages go to stdout so the self-test can assert on them.

opts_file="${1:-analysis_options.yaml}"
lock_file="${2:-pubspec.lock}"

fail() {
  echo "FAIL: $*"
  exit 1
}

[ -f "$opts_file" ] || fail "$opts_file not found."
[ -f "$lock_file" ] || fail "$lock_file not found."

include_line="$(grep -E '^[[:space:]]*include:[[:space:]]*package:' "$opts_file" || true)"
[ -n "$include_line" ] || fail "no 'include: package:...' line in $opts_file."

if echo "$include_line" | grep -qE 'analysis_options\.yaml[[:space:]]*$'; then
  fail "$opts_file includes the bare, unversioned analysis_options.yaml. A pub upgrade would then silently change what counts as an error. Pin the version-numbered file."
fi

# package:<pkg>/<path-under-lib>
ref="$(echo "$include_line" | sed -E 's/.*package:([^[:space:]]+).*/\1/')"
pkg="${ref%%/*}"
rel="${ref#*/}"

# The resolved version, not "whatever is in the cache". A stale 10.0.0 sitting
# beside the resolved 10.3.0 would otherwise satisfy a glob and hide the miss.
version="$(awk -v pkg="$pkg" '
  $0 ~ "^  " pkg ":$" { inpkg = 1; next }
  inpkg && /^  [a-z0-9_]+:$/ { inpkg = 0 }
  inpkg && /^    version:/ { gsub(/[",]/, "", $2); print $2; exit }
' "$lock_file")"
[ -n "$version" ] || fail "$pkg is not in $lock_file — run 'flutter pub get'."

pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"
pkg_lib="$pub_cache/hosted/pub.dev/${pkg}-${version}/lib"

if [ ! -d "$pkg_lib" ]; then
  fail "resolved $pkg $version is not unpacked at $pkg_lib — run 'flutter pub get'."
fi

if [ ! -e "$pkg_lib/$rel" ]; then
  echo "FAIL: '$rel' is missing from $pkg_lib (resolved $pkg $version)."
  echo "      The analyzer would emit one include_file_not_found warning and"
  echo "      then run with ZERO added rules — a green build that checks nothing."
  echo "      Available include files:"
  ls "$pkg_lib" | sed 's/^/        /'
  exit 1
fi

echo "OK: $ref resolves to $pkg_lib/$rel (resolved $pkg $version)."
echo "verify_include_pin: OK — now confirm a known violation still errors."
