#!/usr/bin/env bash
# check_raw_values.sh — design values live in lib/theme/ and nowhere else.
#
# Usage: bash tool/check_raw_values.sh [TARGET_DIR]   (default: lib)
#
# Called from tool/check_bans.sh, which is the single grep entry point CI runs.
# EPIC-07 EXTENDS this file with its component patterns and EPIC-14 with its
# a11y ones; neither creates a second script, because two files with the same
# name in two directories is how a rule tightened in one goes silently missing
# from the other.
#
# A legitimate new need is A NEW TOKEN SLOT, never an `// ignore` — one place to
# diff is the whole point. Per daybreak-tokens rule 14 a new or changed slot
# lands in the contrast-budget table with its test in the same commit: an
# ungated colour is an unverified colour, and the failure mode is silent for
# exactly the population that will not file a bug.
set -uo pipefail

TARGET="${1:-lib}"
if [ ! -d "$TARGET" ]; then
  echo "check_raw_values: '$TARGET' not found; nothing to scan."
  exit 0
fi
STRIPPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/strip_comments.awk"
if [ ! -f "$STRIPPER" ]; then
  echo "check_raw_values: $STRIPPER is missing — the stripper is load-bearing."
  exit 2
fi

# Generated files are exempt.
GEN_RE='\.g\.dart$|\.freezed\.dart$|\.gr\.dart$'

# Banned raw-value patterns in feature/shared UI code.
#
# `EdgeInsetsDirectional.` is deliberately NOT matched: it is the sanctioned
# form, and a regex that ate it would make every component uneditable while
# also banning the RTL discipline the app depends on. The pattern is anchored
# so `EdgeInsets.` matches and `EdgeInsetsDirectional.` does not.
# `Colors.`/`Curves.` are
# anchored with a non-identifier lookbehind so custom reads like `AppColors.of`
# or `MyCurves.foo` do not trip the gate.
PATTERNS='Color\(0x|Color\.fromARGB\(|Color\.fromRGBO\(|(^|[^A-Za-z0-9_])Colors\.|(^|[^A-Za-z0-9_])Curves\.|Duration\(milliseconds:|Duration\(seconds:|BorderRadius\.circular\([0-9]|Radius\.circular\([0-9]|fontSize:[[:space:]]*[0-9]|fontFamily:[[:space:]]*.[A-Za-z]|ColorScheme\.fromSeed\(|BoxShadow\(|LinearGradient\(|RadialGradient\(|SweepGradient\(|(^|[^A-Za-z0-9_])EdgeInsets\.'

# Legitimate exceptions. Neutralized (stripped) BEFORE the ban scan — not used to
# drop the whole line — so a banned value elsewhere on the same line still fails
# (e.g. `x ? Colors.transparent : Color(0xFFAA0000)` must not slip through).
ALLOW_STRIP='s/Colors\.transparent//g; s/Duration\.zero//g; s/EdgeInsets\.zero//g'

fail=0
while IFS= read -r -d '' f; do
  # `lib/theme/`, NOT `*/theme/*`: a feature-local `lib/features/x/theme/`
  # folder is a natural name, and the wildcard would disarm the whole gate for
  # every file inside it.
  #
  # Both shapes, because the target is sometimes `lib` (so `find` yields
  # `lib/theme/...`) and sometimes an absolute root (so it yields
  # `/tmp/xyz/lib/theme/...`). Matching only the first meant the exemption
  # silently stopped applying under any other root, and lib/theme/ itself
  # failed the gate that exists to protect it. Neither pattern matches a
  # feature-local `lib/features/x/theme/`.
  case "$f" in lib/theme/*|*/lib/theme/*) continue ;; esac
  if printf '%s\n' "$f" | grep -qE "$GEN_RE"; then continue; fi

  # Comments are stripped first — this file's own rule list contains every
  # needle by construction — and both the stripper and sed preserve the line
  # count, so grep -n line numbers still match the source file.
  hits="$(awk -f "$STRIPPER" "$f" | sed -E "$ALLOW_STRIP" | grep -nE "$PATTERNS" || true)"
  if [ -n "$hits" ]; then
    echo "== $f =="
    printf '%s\n' "$hits"
    fail=1
  fi
done < <(find "$TARGET" -name '*.dart' -type f -print0)

if [ "$fail" -ne 0 ]; then
  echo "FAIL: raw aesthetic value(s) outside */theme/. Read a ThemeExtension slot, or add a token."
  exit 1
fi
echo "OK: no raw aesthetic values outside */theme/."
