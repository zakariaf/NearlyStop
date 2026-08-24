#!/usr/bin/env bash
set -uo pipefail
# check-single-fln-import.sh — the plugin lives behind ONE file.
#
# `flutter_local_notifications` is the only dependency in this app that talks
# to the OS on its own schedule. Confining it to a single adapter is what makes
# every other test in the notification stack run against `FakeNotificationGateway`
# with no platform-channel mocking anywhere — and a second import is how that
# stops being true, silently, in a feature file somebody was in a hurry in.
#
# Two packages, two different confinements, because they are different things:
#
#   * `flutter_local_notifications` and `flutter_timezone` TALK TO THE DEVICE.
#     One file each, and that file is the adapter.
#   * `package:timezone` is the scheduling core's TYPE LANGUAGE. CONTRACTS §2
#     allows it under `lib/core/notifications/**` — a core without `TZDateTime`
#     cannot express "08:00 local on this date" — and the seam that hands a
#     `tz.Location` from the platform to that core has to name the type too.
#     So `lib/services/notifications/**` may import it and nothing else may.
#
# Usage: bash tool/check-single-fln-import.sh [ROOT]

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stripper="$tool_dir/strip_comments.awk"
root="${1:-$tool_dir/..}"
cd "$root" || {
  echo "check-single-fln-import: cannot enter '$root' — refusing to report OK."
  exit 2
}
[ -f "$stripper" ] || {
  echo "check-single-fln-import: $stripper is missing."
  exit 2
}
[ -d lib ] || {
  echo "check-single-fln-import: lib/ does not exist under '$root'."
  exit 2
}

adapter='lib/services/notifications/fln_notification_gateway.dart'
core_prefix='lib/core/notifications/'
seam_prefix='lib/services/notifications/'

offenders=()
scanned=0

while IFS= read -r file; do
  [ -n "$file" ] || continue
  stripped="$(awk -f "$stripper" "$file")"
  scanned=$((scanned + 1))

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    [ "$file" = "$adapter" ] && continue
    offenders+=("$file:${hit%%:*}: imports flutter_local_notifications")
  done < <(grep -nE "^[[:space:]]*(import|export)[[:space:]]+['\"]package:flutter_local_notifications" <<<"$stripped" || true)

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    [ "$file" = "$adapter" ] && continue
    [[ "$file" == "$core_prefix"* ]] && continue
    [[ "$file" == "$seam_prefix"* ]] && continue
    offenders+=("$file:${hit%%:*}: imports timezone outside the core and its seam")
  done < <(grep -nE "^[[:space:]]*(import|export)[[:space:]]+['\"]package:timezone/" <<<"$stripped" || true)

  # `flutter_timezone` reads the DEVICE's zone. That is a platform call, so it
  # lives with the other platform calls.
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    [ "$file" = "$adapter" ] && continue
    offenders+=("$file:${hit%%:*}: imports flutter_timezone outside the adapter")
  done < <(grep -nE "^[[:space:]]*(import|export)[[:space:]]+['\"]package:flutter_timezone" <<<"$stripped" || true)

  # `timezone/browser.dart` is the ONE file in that package that reaches for
  # `package:http`. This app has no web target; importing it would make the
  # audit's exemption a lie.
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    offenders+=("$file:${hit%%:*}: imports timezone/browser.dart, which pulls package:http")
  done < <(grep -nE "['\"]package:timezone/browser\.dart" <<<"$stripped" || true)
done < <(find lib -type f -name '*.dart' ! -path 'lib/l10n/gen/*' | sort)

if [ "$scanned" -eq 0 ]; then
  echo "check-single-fln-import: scanned 0 files — refusing to report OK."
  exit 2
fi

if [ "${#offenders[@]}" -ne 0 ]; then
  echo "check-single-fln-import: ${#offenders[@]} violation(s)."
  echo
  printf '  %s\n' "${offenders[@]}"
  echo
  echo "The plugin belongs in $adapter and nowhere else."
  echo "package:timezone is additionally allowed under ${core_prefix}** and"
  echo "${seam_prefix}** (CONTRACTS §2). flutter_timezone is not."
  exit 1
fi

echo "check-single-fln-import: OK ($scanned files)"
