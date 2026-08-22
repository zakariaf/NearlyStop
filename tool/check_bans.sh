#!/usr/bin/env bash
set -uo pipefail
# check_bans.sh — THE static gate for this repo. One accumulate-and-fail-once
# script holding the invariants no test can see, because they are properties of
# the SOURCE GRAPH: an import that is never reached at runtime still ships.
#
# Usage: bash tool/check_bans.sh [ROOT]     (ROOT defaults to the repo root)
#
# ADDING A RULE: append one row to the RULES table below. Nothing else changes.
# Later epics do exactly that — 02 (raw token values), 03 (ARB parity and i18n
# bans), 07 (component patterns), 12 (the plugin-import gate), 14 (a11y and RTL
# patterns). No epic creates a second gate under scripts/; tool/ is the only
# script directory and this is the only grep entry point CI calls.
#
# Every rule must clear the three-criteria bar: textually decidable, silent
# when broken, one line to break. A pattern that fails the bar belongs in code
# review, not here.
#
# The scanner's own pattern list contains every needle by construction, so only
# lib/ and test/ are ever scanned — never tool/.

cd "${1:-$(dirname "$0")/..}"

stripper=tool/strip_comments.awk

# The rules promoted to `error` in analysis_options.yaml, read from that file so
# the suppression rule below cannot drift out of step with the promotions it
# protects.
promoted="$(awk '
  /^[[:space:]]*errors:[[:space:]]*$/ { inerrors = 1; next }
  inerrors && /^[[:space:]]{4}[a-z_]+:/ {
    split($0, kv, ":")
    gsub(/[[:space:]]/, "", kv[1])
    sub(/^[[:space:]]+/, "", kv[2])
    sub(/[[:space:]#].*/, "", kv[2])
    if (kv[2] == "error") printf "%s|", kv[1]
    next
  }
  inerrors && /^[^[:space:]]/ { inerrors = 0 }
' analysis_options.yaml)"
promoted="${promoted%|}"

# ------------------------------------------------------------------ the rules
# Tab-separated: SCOPE <tab> MODE <tab> EXEMPT-PATH <tab> REGEX <tab> REASON
#   SCOPE  — a directory to walk (`lib`, `test`)
#   MODE   — `code` matches comment-stripped source; `comment` matches the raw
#            file, and is only for rules that are ABOUT comments
#   EXEMPT — one path this rule does not apply to, or `-`
rules=()
add_rule() { rules+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$4"$'\t'"$5"); }

# Zero network calls, zero telemetry, bundled fonts. The store listing will
# claim all three; an import is the one place the claim can quietly break.
add_rule lib code - \
  "^[[:space:]]*(import|export)[[:space:]]+['\"]package:(http|dio|firebase_[a-z_]*|google_fonts|sentry[a-z_]*|dynamic_color)/" \
  "zero network calls, zero telemetry, bundled fonts — this import breaks a promise the store listing makes"

# Every date comes from clockProvider. A 780-day plan crosses DST twice a year;
# a wall-clock read is how a dose silently lands on the wrong calendar day.
add_rule lib code lib/core/time/clock.dart \
  'DateTime\.now\(\)' \
  "use the injected Clock (clockProvider), never DateTime.now() — DST and the 780-day horizon depend on it"

# RTL correctness by construction: four locales, two of them right-to-left.
add_rule lib code - \
  'EdgeInsets\.only\([[:space:]]*(left|right):|EdgeInsets\.fromLTRB\(|Alignment\.center(Left|Right)\b|Positioned\([[:space:]]*(left|right):|TextAlign\.(left|right)\b' \
  "use directional geometry (EdgeInsetsDirectional, AlignmentDirectional, PositionedDirectional, TextAlign.start/end) — fa and ckb mirror"

# Icons.adaptive.* mirrors and platform-matches; the fixed glyph does neither.
# Anchored to the structure: "Icons.adaptive.arrow_back" does not contain
# "Icons.arrow_", so it passes without needing a lookbehind.
add_rule lib code - \
  'Icons\.arrow_(back|forward)\b' \
  "use Icons.adaptive.arrow_back / arrow_forward — the fixed glyph does not mirror in RTL"

# Suppressions are line-scoped with a reason. A file-scoped ignore on a rule we
# deliberately promoted to error leaves every later edit in that file
# unprotected — exactly the leak the promotion exists to catch.
if [ -n "$promoted" ]; then
  for scope in lib test; do
    add_rule "$scope" comment - \
      "//[[:space:]]*ignore_for_file:.*(${promoted})" \
      "suppressions are line-scoped with a reason — // ignore_for_file: on a promoted rule disarms it for the whole file"
  done
fi

# ------------------------------------------------------------------ the walk
# One pass per file: read once, strip once, then apply every rule that governs
# it. Stripping per rule instead re-reads the tree once for each rule, which
# grows with both the codebase and the five epics still to append rules here.
offenders=()

scan_scope() {
  local scope="$1" file stripped raw rule scope_of mode exempt pattern reason haystack hit
  [ -d "$scope" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    raw="$(cat "$file")"
    stripped=""
    for rule in "${rules[@]}"; do
      IFS=$'\t' read -r scope_of mode exempt pattern reason <<<"$rule"
      [ "$scope_of" = "$scope" ] || continue
      [ "$exempt" = "$file" ] && continue
      if [ "$mode" = "code" ]; then
        [ -n "$stripped" ] || stripped="$(awk -f "$stripper" "$file")"
        haystack="$stripped"
      else
        haystack="$raw"
      fi
      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        offenders+=("$file:${hit%%:*}: $reason"$'\n'"        ${hit#*:}")
      done < <(grep -nE "$pattern" <<<"$haystack" || true)
    done
  done < <(find "$scope" -type f -name '*.dart' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.drift.dart' \
    ! -path '*/l10n/gen/*' | sort)
}

for scope in lib test; do
  scan_scope "$scope"
done

# ------------------------------------------------------------------- verdict
if [ "${#offenders[@]}" -ne 0 ]; then
  echo "check_bans: ${#offenders[@]} violation(s)."
  echo
  for o in "${offenders[@]}"; do
    echo "  $o"
    echo
  done
  echo "Each of these is a promise the app makes that a passing test cannot see."
  exit 1
fi

echo "check_bans: OK"
