#!/usr/bin/env bash
set -uo pipefail
# check_ipa_slices.sh — no simulator slice in an artifact bound for the store.
#
# Usage: bash tool/check_ipa_slices.sh <path-to-.ipa-or-.app>
#
# A tree that last built for the simulator leaves a simulator framework slice
# behind, and `flutter build ipa` will happily package it. Apple rejects the
# upload with 90087 or 91169 — AFTER the upload is spent and the build number
# is burned. Only a `flutter clean` fixes it, which is why RELEASING.md makes
# the clean mandatory and this the check before the upload rather than after.

target="${1:-}"
if [ -z "$target" ] || [ ! -e "$target" ]; then
  echo "usage: bash tool/check_ipa_slices.sh <path-to-.ipa-or-.app>"
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

case "$target" in
  *.ipa) unzip -q "$target" -d "$work"; root="$work" ;;
  *)     root="$target" ;;
esac

problems=0
while IFS= read -r binary; do
  [ -n "$binary" ] || continue
  # `lipo -info` names the architectures; a simulator slice on Apple silicon
  # is arm64 too, so the architecture alone cannot tell them apart. The
  # load command can: a simulator build carries LC_BUILD_VERSION with
  # platform IOSSIMULATOR.
  if otool -l "$binary" 2>/dev/null | grep -q "platform 7"; then
    echo "  simulator slice: $binary"
    problems=$((problems + 1))
  fi
done < <(find "$root" -type f -perm +111 \
  \( -path '*.framework/*' -o -path '*.app/*' \) 2>/dev/null |
  while read -r f; do file "$f" | grep -q 'Mach-O' && echo "$f"; done)

if [ "$problems" -ne 0 ]; then
  echo
  echo "check_ipa_slices: $problems simulator slice(s)."
  echo "Run 'flutter clean' and rebuild. Apple rejects this with 90087/91169,"
  echo "and the rejection costs the build number."
  exit 1
fi

echo "check_ipa_slices: OK"
