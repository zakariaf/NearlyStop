#!/usr/bin/env bash
set -uo pipefail
# check-adhoc-schedule-calls.sh — one reconcile, and nothing else writes.
#
# The OS pending set is a disposable cache reconciled against the database. A
# feature that calls `gateway.schedule(...)` directly cannot be made idempotent
# — the next reconcile diffs against a set it did not produce and either
# cancels the feature's entry or leaves a duplicate — and neither outcome is
# visible until somebody's 08:00 does not arrive.
#
# Usage: bash tool/check-adhoc-schedule-calls.sh [ROOT]

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stripper="$tool_dir/strip_comments.awk"
root="${1:-$tool_dir/..}"
cd "$root" || {
  echo "check-adhoc-schedule-calls: cannot enter '$root' — refusing to report OK."
  exit 2
}
[ -f "$stripper" ] || {
  echo "check-adhoc-schedule-calls: $stripper is missing."
  exit 2
}
[ -d lib ] || {
  echo "check-adhoc-schedule-calls: lib/ does not exist under '$root'."
  exit 2
}

reconcile='lib/services/notifications/sync_notifications.dart'
port='lib/services/notifications/notification_gateway.dart'
# The adapter IS the thing being called; it forwards to the plugin and decides
# nothing. It is confined by check-single-fln-import.sh instead.
adapter='lib/services/notifications/fln_notification_gateway.dart'

offenders=()
scanned=0

while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ "$file" = "$reconcile" ] && continue
  [ "$file" = "$port" ] && continue
  [ "$file" = "$adapter" ] && continue
  stripped="$(awk -f "$stripper" "$file")"

  # Only files that can SEE the port. `_timer?.cancel()` is a `dart:async`
  # Timer and has nothing to do with notifications; a bare `.cancel(` rule
  # flags it, and a gate that cries wolf is a gate somebody deletes.
  grep -qE "['\"](package:nearlystop/services/notifications/notification_gateway\.dart|notification_gateway\.dart)['\"]" <<<"$stripped" || continue
  scanned=$((scanned + 1))

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    offenders+=("$file:${hit%%:*}: arms or cancels outside the reconcile"$'\n'"        ${hit#*:}")
  done < <(grep -nE '\.(schedule|cancel|cancelAll)\(' <<<"$stripped" || true)
done < <(find lib -type f -name '*.dart' ! -path 'lib/l10n/gen/*' | sort)

# Zero is legitimate here and only here: before the port exists, nothing
# imports it. The gate's own self-test drives a tree where it does.
if [ "$scanned" -eq 0 ]; then
  echo "check-adhoc-schedule-calls: OK (no file imports the gateway port yet)"
  exit 0
fi

if [ "${#offenders[@]}" -ne 0 ]; then
  echo "check-adhoc-schedule-calls: ${#offenders[@]} violation(s)."
  echo
  for o in "${offenders[@]}"; do
    echo "  $o"
    echo
  done
  echo "Every scheduling change goes through syncNotifications() in"
  echo "$reconcile, which is the only thing that can be idempotent."
  exit 1
fi

echo "check-adhoc-schedule-calls: OK ($scanned files)"
