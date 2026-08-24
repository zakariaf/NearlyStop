#!/usr/bin/env bash
set -uo pipefail
# check-manifest-permissions.sh — the WHOLE permission set of the MERGED manifest.
#
# Two decisions this encodes, both from CONTRACTS §12:
#
#   1. **The merged manifest, not the source.** `flutter_local_notifications`
#      and every other library contribute `<uses-permission>` nodes of their
#      own. A grep of `android/app/src/main/AndroidManifest.xml` sees none of
#      them, so it cannot see the day one of them adds SCHEDULE_EXACT_ALARM.
#   2. **The whole set, not a deny list.** This app's premise is that it has no
#      network path. `INTERNET` arriving through a transitive dependency would
#      break that without anybody editing a file, and a "no exact alarms" grep
#      would pass it.
#
# Usage: bash tool/check-manifest-permissions.sh [MANIFEST]
#   MANIFEST defaults to the release merged manifest, built by
#   `flutter build apk --release` (or `--debug`, which adds INTERNET on
#   purpose and is therefore NOT what this gate reads).

expected=(
  android.permission.POST_NOTIFICATIONS
  android.permission.RECEIVE_BOOT_COMPLETED
  android.permission.VIBRATE
)

# The plugin's own receivers. The BOOT one is what re-arms alarms after a
# restart; declaring RECEIVE_BOOT_COMPLETED without it grants a permission
# nothing listens to, and every reminder is lost at the next reboot.
required_nodes=(
  com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
)

default=build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
manifest="${1:-$default}"

if [ ! -f "$manifest" ]; then
  echo "check-manifest-permissions: '$manifest' does not exist."
  echo "Build it first:  flutter build apk --release"
  echo "Refusing to report OK on a manifest that was never produced."
  exit 2
fi

# One name per line, deduplicated and sorted, so the comparison is a set
# comparison rather than a line-order comparison.
found="$(grep -oE 'android:name="android\.permission\.[A-Z_]+"' "$manifest" |
  sed -E 's/.*"(.*)"/\1/' | sort -u)"
want="$(printf '%s\n' "${expected[@]}" | sort -u)"

status=0

while IFS= read -r missing; do
  [ -n "$missing" ] || continue
  echo "MISSING : $missing is expected and not declared"
  status=1
done < <(comm -23 <(echo "$want") <(echo "$found"))

while IFS= read -r extra; do
  [ -n "$extra" ] || continue
  echo "UNEXPECTED: $extra is declared and is not in the expected set"
  status=1
done < <(comm -13 <(echo "$want") <(echo "$found"))

for node in "${required_nodes[@]}"; do
  if grep -q "$node" "$manifest"; then
    echo "OK      : $node registered"
  else
    echo "MISSING : $node is not registered"
    status=1
  fi
done

if [ "$status" -ne 0 ]; then
  echo
  echo "The expected set is exactly:"
  printf '  %s\n' "${expected[@]}"
  echo
  echo "SCHEDULE_EXACT_ALARM and USE_EXACT_ALARM are deliberately absent:"
  echo "a daily 'your plan for today' does not need alarm-clock precision,"
  echo "and Play policy restricts USE_EXACT_ALARM to alarm/timer/calendar apps."
  exit 1
fi

echo "check-manifest-permissions: OK ($(echo "$found" | wc -l | tr -d ' ') permissions)"
