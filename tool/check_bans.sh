#!/usr/bin/env bash
set -uo pipefail
# check_bans.sh — THE static gate for this repo. One accumulate-and-fail-once
# script holding the invariants no test can see, because they are properties of
# the SOURCE GRAPH: an import that is never reached at runtime still ships.
#
# Usage: bash tool/check_bans.sh [ROOT]     (ROOT defaults to the repo root)
#
# Extended by later epics — 02 (raw token values), 03 (ARB parity and i18n
# bans), 07 (component patterns), 12 (the plugin-import gate), 14 (a11y and
# RTL patterns). They APPEND a rule group here; no epic creates a second gate
# under scripts/, and tool/ is the only script directory.
#
# Every rule clears the three-criteria bar: textually decidable, silent when
# broken, one line to break. A pattern that fails the bar belongs in code
# review, not here.
#
# The scanner's own pattern list contains every needle by construction, so only
# lib/ (and test/ for the suppression rule) is ever scanned — never tool/.

cd "${1:-$(dirname "$0")/..}"

offenders=()

# Blank out comments while preserving line numbers, so a rule's own explanation
# is never an offender. String literals are not tracked: stripping slightly too
# much is the safe direction for these needles.
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

dart_files() {
  local root="$1"
  [ -d "$root" ] || return 0
  find "$root" -type f -name '*.dart' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.drift.dart' \
    ! -path '*/l10n/gen/*' | sort
}

# record <file> <line-number> <matched-line> <reason>
record() {
  offenders+=("$1:$2: $4"$'\n'"        $3")
}

# scan_stripped <root> <extended-regex> <reason> [exempt-path]
scan_stripped() {
  local root="$1" pattern="$2" reason="$3" exempt="${4:-}"
  local file hit lineno text
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -n "$exempt" ] && [ "$file" = "$exempt" ] && continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      lineno="${hit%%:*}"
      text="${hit#*:}"
      record "$file" "$lineno" "$text" "$reason"
    done < <(strip_comments "$file" | grep -nE "$pattern" || true)
  done < <(dart_files "$root")
}

# scan_raw <root> <extended-regex> <reason> — for rules ABOUT comments.
scan_raw() {
  local root="$1" pattern="$2" reason="$3"
  local file hit lineno text
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      lineno="${hit%%:*}"
      text="${hit#*:}"
      record "$file" "$lineno" "$text" "$reason"
    done < <(grep -nE "$pattern" "$file" || true)
  done < <(dart_files "$root")
}

# ---------------------------------------------------------------- rule group 1
# Zero network calls, zero telemetry, bundled fonts. The store listing will
# claim all three; an import is the one place the claim can quietly break.
scan_stripped lib \
  "^[[:space:]]*(import|export)[[:space:]]+['\"]package:(http|dio|firebase_[a-z_]*|google_fonts|sentry[a-z_]*|dynamic_color)/" \
  "zero network calls, zero telemetry, bundled fonts — this import breaks a promise the store listing makes"

# ---------------------------------------------------------------- rule group 2
# Every date comes from clockProvider. A 780-day plan crosses DST twice a year;
# a wall-clock read is how a dose silently lands on the wrong calendar day.
scan_stripped lib \
  'DateTime\.now\(\)' \
  "use the injected Clock (clockProvider), never DateTime.now() — DST and the 780-day horizon depend on it" \
  lib/core/time/clock.dart

# ---------------------------------------------------------------- rule group 3
# RTL correctness by construction: four locales, two of them right-to-left.
scan_stripped lib \
  'EdgeInsets\.only\([[:space:]]*(left|right):|EdgeInsets\.fromLTRB\(|Alignment\.center(Left|Right)\b|Positioned\([[:space:]]*(left|right):|TextAlign\.(left|right)\b' \
  "use directional geometry (EdgeInsetsDirectional, AlignmentDirectional, PositionedDirectional, TextAlign.start/end) — fa and ckb mirror"

# ---------------------------------------------------------------- rule group 4
# Icons.adaptive.* mirrors and platform-matches; the fixed glyph does neither.
# Anchored to the structure: Icons.adaptive.arrow_back does not contain
# "Icons.arrow_", so it passes without a lookbehind.
scan_stripped lib \
  'Icons\.arrow_(back|forward)\b' \
  "use Icons.adaptive.arrow_back / arrow_forward — the fixed glyph does not mirror in RTL"

# ---------------------------------------------------------------- rule group 5
# Suppressions are line-scoped with a reason. A file-scoped ignore on a rule we
# deliberately promoted to error leaves every later edit in that file
# unprotected — which is exactly the leak the promotion exists to catch.
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
if [ -n "$promoted" ]; then
  for root in lib test; do
    scan_raw "$root" \
      "//[[:space:]]*ignore_for_file:.*(${promoted})" \
      "suppressions are line-scoped with a reason — // ignore_for_file: on a promoted rule disarms it for the whole file"
  done
fi

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
