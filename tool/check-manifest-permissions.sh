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
#
# **Two lanes, since EPIC-15.** A release build now fails without signing
# credentials — correctly, because a debug-signed release installs and can
# then never be updated on Play — so PR CI cannot produce a release manifest
# and passes the PROFILE one instead. Profile carries INTERNET legitimately,
# for the VM service, so the INTERNET check below is skipped on a profile
# manifest and says so out loud rather than quietly passing. The full
# assertion runs in `release.yml`, against the real signed build.

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

# Which variant this manifest came from. A profile build adds INTERNET on
# purpose; a release build must not have it, and that difference is the whole
# reason the gate has to know which one it is looking at.
case "$manifest" in
  *[Pp]rofile*) variant=profile ;;
  *[Dd]ebug*)   variant=debug ;;
  *)            variant=release ;;
esac

if [ "$variant" != release ]; then
  expected+=(android.permission.INTERNET)
  echo "NOTE: reading the $variant manifest. INTERNET is expected here — the"
  echo "      VM service needs it. The release lane asserts its ABSENCE."
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
