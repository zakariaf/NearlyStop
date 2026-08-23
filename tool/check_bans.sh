#!/usr/bin/env bash
set -uo pipefail
# check_bans.sh — THE static gate for this repo. One accumulate-and-fail-once
# script holding the invariants no test can see, because they are properties of
# the SOURCE GRAPH: an import that is never reached at runtime still ships.
#
# Usage: bash tool/check_bans.sh [ROOT]     (ROOT defaults to the repo root)
#
# ADDING A RULE: append one `add_rule` call below. Nothing else changes. Later
# epics do exactly that — 02 (raw token values), 03 (ARB parity and i18n bans),
# 07 (component patterns), 12 (the plugin-import gate), 14 (a11y and RTL
# patterns). No epic creates a second gate under scripts/; tool/ is the only
# script directory and this is the only grep entry point CI calls.
#
# Every rule must clear the three-criteria bar: textually decidable, silent
# when broken, one line to break. A pattern that fails the bar belongs in code
# review, not here.
#
# The scanner's own pattern list contains every needle by construction, so only
# lib/ and test/ are ever scanned — never tool/.

# Resolve tool/ before cd-ing anywhere: the awk stripper is loaded by path, and
# a relative path plus a ROOT argument means awk silently finds nothing, every
# rule scans an empty haystack, and the gate reports OK.
tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stripper="$tool_dir/strip_comments.awk"

root="${1:-$tool_dir/..}"
cd "$root" || {
  echo "check_bans: cannot enter '$root' — refusing to report OK on an unscanned tree."
  exit 2
}
[ -f "$stripper" ] || {
  echo "check_bans: $stripper is missing — the comment stripper is load-bearing."
  exit 2
}

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
# add_rule <scopes> <mode> <exempt-path> <extended-regex> <reason>
#   scopes — space-separated directories to walk (`lib`, `lib test`)
#   mode   — `code` matches comment-stripped source (string literals survive, so
#            an import URI is still matchable); `comment` matches the raw file
#            and is only for rules that are ABOUT comments
#   exempt — one path this rule does not apply to, or a glob (`lib/data/*`),
#            or `-`
# Fields are held in four parallel arrays rather than one delimited string: a
# delimited encoding shifts every column the first time a rule needs an empty
# field.
rule_scopes=()
rule_modes=()
rule_exempt=()
rule_patterns=()
rule_reasons=()
# A glob a rule is CONFINED to, or `-` for the whole scope. The inverse of
# `rule_exempt`: some rules are about one layer rather than about the tree.
rule_only=()
add_rule() {
  rule_scopes+=("$1")
  rule_modes+=("$2")
  rule_exempt+=("$3")
  rule_patterns+=("$4")
  rule_reasons+=("$5")
  rule_only+=("${6:--}")
}

# Zero network calls, zero telemetry, bundled fonts. The store listing will
# claim all three; an import is the one place the claim can quietly break.
add_rule lib code - \
  "^[[:space:]]*(import|export)[[:space:]]+['\"]package:(http|dio|firebase_[a-z_]*|google_fonts|sentry[a-z_]*|dynamic_color|grpc|socket_io[a-z_]*|web_socket[a-z_]*)/" \
  "zero network calls, zero telemetry, bundled fonts — this import breaks a promise the store listing makes"

# The same promise at the call site. `dart:io` itself stays allowed — EPIC-13
# writes a backup file — but the socket half of it does not, and web_socket /
# web_socket_channel are ALLOW-listed in tool/audit_deps.py precisely because
# this rule stops them ever being reached from lib/.
add_rule lib code - \
  '\b(HttpClient|HttpServer|RawDatagramSocket|RawSecureSocket|RawSocket|SecureSocket|Socket|WebSocket)[[:space:]]*[.(]' \
  "zero network calls — a socket API in lib/ is the runtime half of the promise the import ban makes"

# Every date comes from clockProvider. A 780-day plan crosses DST twice a year;
# a wall-clock read is how a dose silently lands on the wrong calendar day.
add_rule lib code lib/core/time/clock.dart \
  'DateTime\.now\(\)' \
  "use the injected Clock (clockProvider), never DateTime.now() — DST and the 780-day horizon depend on it"

# The void arm is spelled `Result<void, F>`. EPIC-12 and EPIC-13 drafts say
# `Result<Unit, F>`; this stops one landing by accident.
add_rule lib code - \
  '\bUnit\b' \
  "there is no Unit type in this codebase — the void arm of Result is Result<void, F>"

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

# A FontVariation on an axis the shipped faces do not expose is a SILENT no-op:
# both bundled TTFs carry `wght` only, so `opsz` or `ital` changes nothing and
# the defect is invisible in a golden.
add_rule lib code - \
  "FontVariation\\([[:space:]]*'(opsz|ital|slnt|wdth)'" \
  "both bundled faces expose the wght axis only — any other FontVariation no-ops silently"

# drift stays behind the data layer. The domain and every screen see facts and
# `Result`; the day an `Insertable` or a generated row class reaches a widget,
# the UI cannot be tested without a database. test/data/no_drift_in_api_test
# covers the half a grep cannot: no drift type in a public SIGNATURE.
add_rule lib code 'lib/data/*' \
  "^[[:space:]]*(import|export)[[:space:]]+['\"]package:drift/" \
  "drift lives behind lib/data/ — the domain and the UI never learn it exists"

# drift_dev is a DEV dependency and it drags `analyzer` and `build` with it.
# `validateDatabaseSchema` is the tempting one: it is an extension in
# package:drift_dev/api/migrations.dart, and importing it from lib/ puts the
# whole analyzer on the shipping app's compile path.
add_rule lib code - \
  "^[[:space:]]*(import|export)[[:space:]]+['\"]package:drift_dev/" \
  "drift_dev is a dev dependency — an import from lib/ puts analyzer and build on the shipping compile path"

# Shrinking text to fit is always the wrong answer for this audience. A
# `FittedBox` around the 72px dose numeral scales down the one number the
# patient reads every morning; around a German button label it turns a loud
# layout failure into an unreadable instruction on a 78-year-old's phone. The
# fix for text that does not fit is a layout that reflows or a width that is
# reserved — measured in test/theme/tabular_figures_test.dart.
add_rule lib code - \
  '\bFittedBox\b' \
  "never shrink text to fit — reflow the layout or reserve the width; this audience cannot read a scaled-down instruction"

# Casing lives in the ARB string, never at render: `.toUpperCase()` on a
# Perso-Arabic string is a no-op that silently does nothing, and on German it
# produces a word no translator approved.
add_rule lib code - \
  '\.toUpperCase\(\)' \
  "casing belongs in the ARB string — .toUpperCase() no-ops on Perso-Arabic and bypasses the translator on Latin"

# A hand-written digit table gets the SEPARATOR wrong. `'۰۱۲۳۴۵۶۷۸۹'[d]` maps
# digits and then someone writes `.` between them, producing `۱.۵` — a Persian
# number with a Latin decimal point, which no Persian reader parses as 1.5.
# `numberFormatFor(locale)` reads the separators from intl's symbol data along
# with the digits.
#
# **No exemption.** One was written for `lib/l10n/number_formats.dart`, on the
# theory that its doc comment names the U+06Fx block — but comments are
# stripped before matching, so the file passes on its own and the exemption
# protected nothing. An exemption that has never been needed is a hole waiting
# for the day it is.
add_rule lib code - \
  '[۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩]' \
  "never hand-roll a digit table — numberFormatFor(locale) carries the digits AND the separators"

# Route paths live in lib/routing/routes.dart and nowhere else. A '/today'
# typed into a screen is a navigation that compiles, runs, and silently goes
# somewhere the router does not know about — go_router answers an unknown path
# with the error page, not a compile error.
add_rule lib code 'lib/routing/routes.dart' \
  "'/(welcome|today|schedule|progress|plan|settings)" \
  "route paths belong in lib/routing/routes.dart — a literal elsewhere is a navigation that compiles and goes nowhere"

# The OS text-scale setting is the user's, not ours. `accessibility-as-code`:
# never clamp it DOWN. Our own multiplier is bounded in the shell's builder,
# because that one is our control; the product of the two is left unbounded and
# the screens have to survive it.
add_rule lib code - \
  'withClampedTextScaling' \
  "never clamp the OS text scale — bound the app's own multiplier instead, and let the product be unbounded"

# A presentation widget takes pre-formatted strings and callbacks. Nothing
# else. `widget-composition`'s dumb-view rule and CONTRACTS.md 4's layering are
# both about the same failure: the day a widget reaches the repository is the
# day formatting, locale and domain math live in the view — and then the same
# rounding lives in two places, which for a dose is the unforgivable bug.
#
# Scoped with `only`, because this is a rule about ONE layer rather than about
# the tree. The screen itself is the `ConsumerWidget`; its widgets are not.
add_rule lib code - \
  "^[[:space:]]*import[[:space:]]+['\"](package:drift/|package:nearlystop/data/|package:flutter_riverpod/|package:riverpod/)" \
  "a presentation widget may not import drift, the data layer or Riverpod — it takes pre-formatted strings and callbacks (CONTRACTS.md 4)" \
  "lib/features/*/presentation/widgets/*"

add_rule lib code - \
  '\b(WidgetRef|ProviderScope|ConsumerWidget|ConsumerStatefulWidget|TaperRepository)\b' \
  "a presentation widget may not name WidgetRef, ProviderScope, a Consumer base class or the repository — the screen watches, the widget paints" \
  "lib/features/*/presentation/widgets/*"

# The Schedule screen is never a seven-column month grid (SPEC.md 4.2,
# `daybreak-components` rule 4). A calendar square has no room for a state
# shape, a localized state word and 200% text; it forces the eye horizontally
# across unrelated days; and it teaches "a taper is a month" when a taper is a
# sequence of blocks — which is precisely the confusion this app exists to
# remove. Block grouping is the teaching device and it is the product, so the
# ban gets a gate rather than a convention.
#
# Scoped with `only` to the Schedule feature: date ENTRY is legal, and the Plan
# screen asks for a start date with `showDatePicker`. A repo-wide ban would
# have to be relitigated the first time someone needed a date field.
add_rule lib code - \
  '\b(GridView|SliverGrid|CalendarDatePicker|showDatePicker)\b|GridDelegate|table_calendar' \
  "the Schedule is never a seven-column month grid — block grouping is the teaching device and the product (SPEC.md 4.2)" \
  "lib/features/schedule/*"

# Suppressions are line-scoped with a reason. A file-scoped ignore on a rule we
# deliberately promoted to error leaves every later edit in that file
# unprotected — exactly the leak the promotion exists to catch.
if [ -n "$promoted" ]; then
  add_rule "lib test" comment - \
    "//[[:space:]]*ignore_for_file:.*(${promoted})" \
    "suppressions are line-scoped with a reason — // ignore_for_file: on a promoted rule disarms it for the whole file"
fi

# ------------------------------------------------------------------ the walk
# One pass per file: read once, strip once, then apply every rule that governs
# it. Stripping per rule re-reads the tree once for each rule, which grows with
# both the codebase and the epics still to append rules here.
offenders=()

scan_scope() {
  local scope="$1"
  local file stripped raw stripped_done raw_done haystack hit r
  [ -d "$scope" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    stripped=""
    raw=""
    stripped_done=0
    raw_done=0
    for r in "${!rule_patterns[@]}"; do
      case " ${rule_scopes[$r]} " in *" $scope "*) ;; *) continue ;; esac
      # A glob, so a rule can exempt a whole layer (`lib/data/*`) and not just
      # one file. An exact path is a glob with no wildcards, so the older rules
      # are unaffected.
      case "$file" in ${rule_exempt[$r]}) [ "${rule_exempt[$r]}" = '-' ] || continue ;; esac
      if [ "${rule_only[$r]}" != '-' ]; then
        case "$file" in ${rule_only[$r]}) ;; *) continue ;; esac
      fi
      if [ "${rule_modes[$r]}" = "code" ]; then
        if [ "$stripped_done" -eq 0 ]; then
          stripped="$(awk -f "$stripper" "$file")"
          stripped_done=1
        fi
        haystack="$stripped"
      else
        if [ "$raw_done" -eq 0 ]; then
          raw="$(cat "$file")"
          raw_done=1
        fi
        haystack="$raw"
      fi
      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        offenders+=("$file:${hit%%:*}: ${rule_reasons[$r]}"$'\n'"        ${hit#*:}")
      done < <(grep -nE "${rule_patterns[$r]}" <<<"$haystack" || true)
    done
  done < <(find "$scope" -type f -name '*.dart' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.drift.dart' \
    ! -path '*/l10n/gen/*' | sort)
}

for scope in lib test; do
  scan_scope "$scope"
done

# ------------------------------------------------- delegated rule groups
# EPIC-02's design-value gates. They live in their own files because their
# patterns are a different KIND of rule — an aesthetic value rather than a
# source-graph property — but they are reached only from here, so there is one
# entry point and one exit code. Their output is captured and replayed with the
# rest, so a raw hex and a hardcoded padding in the same run are reported
# together rather than the first one masking the second.
delegated=()
run_delegated() {
  local script="$1" reason="$2" output
  output="$(bash "$tool_dir/$script" 2>&1)"
  if [ $? -ne 0 ]; then
    delegated+=("$reason"$'\n'"$output")
  fi
}

run_delegated check_raw_values.sh \
  "design values belong in lib/theme/ — read a token slot, or add one (with its contrast-budget row and its test in the same commit)"

# The lockfile half of the bundled-fonts promise. The IMPORT half is rule group
# 1 above; a second script re-greping the same import URI with a different
# matcher is exactly the drift this file's header warns about, so
# check_font_bundling.sh is gone and its one unique rule is a row above.
if grep -qE '^  google_fonts:' pubspec.lock; then
  offenders+=("pubspec.lock: google_fonts is in the resolved dependency tree, and it fetches a font over the network at runtime")
fi

# ------------------------------------------------------------------- verdict
if [ "${#delegated[@]}" -ne 0 ]; then
  for d in "${delegated[@]}"; do
    echo "$d"
    echo
  done
fi

if [ "${#offenders[@]}" -ne 0 ] || [ "${#delegated[@]}" -ne 0 ]; then
  if [ "${#offenders[@]}" -eq 0 ]; then
    echo "check_bans: ${#delegated[@]} delegated gate(s) failed."
    echo "Each of these is a promise the app makes that a passing test cannot see."
    exit 1
  fi
fi

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
