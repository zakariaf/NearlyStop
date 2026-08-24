#!/usr/bin/env bash
set -uo pipefail
# check_release_hygiene.sh — no signing material in the repo, now or ever.
#
# Usage: bash tool/check_release_hygiene.sh [ROOT]
#
# Two halves, and the second is the one that matters. A working-tree check
# tells you the keystore is not there TODAY. A credential that was committed
# and later deleted is invisible to it and permanently present in every clone
# anybody has ever fetched — deleting it from `main` does nothing. So this also
# walks `git log --all --name-only`, which is the only check that can see it.
#
# A hit here is not a lint. It means rotating the credential and, if it ever
# left the machine, rewriting history.

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$root" || {
  echo "check_release_hygiene: cannot enter '$root' — refusing to report OK."
  exit 2
}

# Extended-regex, matched against a path. Deliberately broad on the extensions
# — a keystore named `whatever.jks` is still a keystore.
patterns='(^|/)key\.properties$|\.(jks|keystore|p12|p8|mobileprovision)$|(^|/)service-account[^/]*\.json$|(^|/)AuthKey_[^/]*\.p8$'

# The `.gitignore` rules that keep it that way. Asserted as PRESENT, not
# inferred from the tree being clean: a clean tree with no rule is one
# `git add -A` away from a committed keystore.
required_ignores='key.properties *.jks *.keystore *.p12 *.p8 service-account'

problems=0

if [ ! -f .gitignore ]; then
  echo "  .gitignore is missing entirely — nothing stops the next 'git add -A'"
  problems=$((problems + 1))
else
  for rule in $required_ignores; do
    if ! grep -qF -- "$rule" .gitignore; then
      echo "  .gitignore does not mention '$rule'"
      problems=$((problems + 1))
    fi
  done
fi

# Half one: what is tracked right now.
while IFS= read -r file; do
  [ -n "$file" ] || continue
  echo "  tracked now: $file"
  problems=$((problems + 1))
done < <(git ls-files 2>/dev/null | grep -E "$patterns" || true)

# Half two: what was EVER tracked, on any branch.
while IFS= read -r file; do
  [ -n "$file" ] || continue
  echo "  in history (rotate the credential, then rewrite): $file"
  problems=$((problems + 1))
done < <(git log --all --pretty=format: --name-only --diff-filter=A 2>/dev/null |
  sort -u | grep -E "$patterns" || true)

if [ "$problems" -ne 0 ]; then
  echo
  echo "check_release_hygiene: $problems problem(s)."
  echo "Signing material never lives in the repo. CI injects it from secrets."
  exit 1
fi

echo "check_release_hygiene: OK"
