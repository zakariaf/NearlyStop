#!/usr/bin/env bash
set -uo pipefail
# check_forms.sh — the three ways a text field in this app goes wrong silently.
#
# Every rule here is a SOURCE-GRAPH property a passing test cannot prove:
#
#   1. A controller or focus node created and never disposed leaks for as long
#      as the app runs. Nothing turns red; the screen keeps working.
#   2. A second input formatter is a second answer to "which characters are a
#      dose". The field then accepts a keystroke the parser refuses, and the
#      person retyping it cannot see any difference between the two strings.
#   3. `double.parse` on user text reads German `7,5` as a FormatException and
#      Persian `۷٫۵` as nothing at all. `parseDose` folds the digits and asks
#      intl for the separators; a direct parse skips both.
#
# Usage: bash tool/check_forms.sh [ROOT]   (ROOT defaults to the repo root)
#
# EPIC-11 owns this gate. CONTRACTS.md §10 (doses are integer hundredths) and
# EPIC-03 (one digit table) are the contracts behind rules 2 and 3.

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stripper="$tool_dir/strip_comments.awk"

root="${1:-$tool_dir/..}"
cd "$root" || {
  echo "check_forms: cannot enter '$root' — refusing to report OK on an unscanned tree."
  exit 2
}
[ -f "$stripper" ] || {
  echo "check_forms: $stripper is missing — the comment stripper is load-bearing."
  exit 2
}
[ -d lib ] || {
  echo "check_forms: lib/ does not exist under '$root'."
  exit 2
}

# Where the ONE character set lives. Rule 2's only legal home.
formatter_home='lib/l10n/'

# Rule 3's two legal homes. `lib/core/` holds the app's canonical parsers —
# `Milligrams.parse` and `LocalDate.parse` are the funnel every other layer is
# required to use, and they have to be built out of something. `lib/l10n/`
# holds `parseDose` and `parseWholeNumber`, which fold the digits and read the
# separators from intl before delegating to that funnel. Everywhere else — a
# screen, a repository, an importer — a direct parse is a locale skipped.
parser_homes=('lib/core/' 'lib/l10n/')

# The ONE file exemption, named rather than a directory: drift's type
# converters read back a string the APP wrote — `'500,100'` — where no locale
# has ever been involved and none can be. It is one file so that EPIC-13's
# importer, which reads a string a PERSON may have edited, is still covered.
parser_exempt_files=('lib/data/db/converters.dart')

offenders=()
scanned=0

while IFS= read -r file; do
  [ -n "$file" ] || continue
  stripped="$(awk -f "$stripper" "$file")"
  scanned=$((scanned + 1))

  # 1. Created here, so disposed here. Deliberately per FILE rather than per
  #    class: a `State` that hands its controller to a helper class in the same
  #    file is fine, and a controller whose file never says `dispose` is not.
  if grep -qE '(TextEditingController|FocusNode|ScrollController)\(' <<<"$stripped"; then
    if ! grep -qE '\.dispose\(\)' <<<"$stripped"; then
      offenders+=("$file: creates a controller or focus node and never disposes one")
    fi
  fi

  # 2. One formatter, in one place.
  if grep -qE 'FilteringTextInputFormatter|LengthLimitingTextInputFormatter' <<<"$stripped"; then
    offenders+=("$file: a second input formatter — use kDoseInputFormatter or kWholeNumberInputFormatter from ${formatter_home}numeric_input.dart")
  fi
  if grep -qE 'TextInputFormatter\.withFunction' <<<"$stripped" &&
    [[ "$file" != "$formatter_home"* ]]; then
    offenders+=("$file: input formatters live in ${formatter_home} so the formatter and the parser cannot disagree")
  fi

  # 3. User text goes through parseDose / parseWholeNumber. `int.tryParse` is
  #    allowed inside lib/l10n/, which is where parseWholeNumber itself lives.
  is_parser_home=0
  for home in "${parser_homes[@]}"; do
    [[ "$file" == "$home"* ]] && is_parser_home=1
  done
  for exempt in "${parser_exempt_files[@]}"; do
    [ "$file" = "$exempt" ] && is_parser_home=1
  done
  if [ "$is_parser_home" -eq 0 ]; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      offenders+=("$file:${hit%%:*}: parses text directly — go through parseDose or parseWholeNumber"$'\n'"        ${hit#*:}")
    done < <(grep -nE '\b(double|num|int)\.(parse|tryParse)\(' <<<"$stripped" || true)
  fi
done < <(find lib -type f -name '*.dart' ! -path 'lib/l10n/gen/*' | sort)

if [ "$scanned" -eq 0 ]; then
  echo "check_forms: scanned 0 files under '$root/lib' — refusing to report OK."
  exit 2
fi

if [ "${#offenders[@]}" -ne 0 ]; then
  echo "check_forms: ${#offenders[@]} violation(s) across $scanned file(s)."
  echo
  for o in "${offenders[@]}"; do
    echo "  $o"
    echo
  done
  echo "A field that leaks, a second character set, or a parse that skips the"
  echo "locale — none of the three turns a test red on its own."
  exit 1
fi

echo "check_forms: OK ($scanned files)"
