#!/usr/bin/env bash
set -uo pipefail
# Every locale carries exactly the template's keys, with exactly the template's
# placeholders and the same ICU branch SHAPES.
#
# A missing key does not fail the build — gen-l10n falls back to the template
# language and ships English inside an otherwise-German app, which is invisible
# in review. A renamed placeholder is worse: it breaks that translation at
# RUNTIME, long after anyone is looking.
#
# The expected locale set is spelled out in the script rather than read from
# the directory, for the same reason: a gate that derives its expectations from
# the thing it is checking cannot fail.
#
# Usage: bash tool/check_arb_parity.sh [ARB_DIR]
arb_dir="${1:-lib/l10n/arb}"
template="$arb_dir/app_en.arb"

if [ ! -f "$template" ]; then
  echo "check_arb_parity: no template at $template" >&2
  exit 2
fi

python3 - "$arb_dir" <<'PY'
import json
import os
import re
import sys

arb_dir = sys.argv[1]
template_path = os.path.join(arb_dir, 'app_en.arb')

def load(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)

def placeholders(value):
    """Every `{name}` in an ICU message, including inside plural branches."""
    return {
        name
        for name in re.findall(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*[,}]', value)
    }

def branches(value):
    """The ICU branch KEYWORDS, e.g. {one, other}. Bodies are translation."""
    return set(re.findall(r'(?:^|\s)(=\d+|zero|one|two|few|many|other)\s*\{', value))

template = load(template_path)
keys = [k for k in template if not k.startswith('@')]
problems = []

# The FILE SET, before any key comparison. Iterating whatever happens to be on
# disk can only ever see a missing key, never a missing LOCALE: delete
# app_fa.arb entirely and the loop simply has one fewer file to compare, prints
# OK, and a Persian phone throws on its first frame because
# `AppLocalizations.of` is non-nullable and the delegate no longer supports fa.
expected = {'en', 'de', 'fa', 'ckb'}
present = {
    name[len('app_'):-len('.arb')]
    for name in os.listdir(arb_dir)
    if name.startswith('app_') and name.endswith('.arb')
}
for missing in sorted(expected - present):
    problems.append(f'app_{missing}.arb is MISSING — kSupportedLocales still '
                    'advertises it')
for extra in sorted(present - expected):
    problems.append(f'app_{extra}.arb is not one of the shipped locales')

for name in sorted(os.listdir(arb_dir)):
    if not name.endswith('.arb') or name == 'app_en.arb':
        continue
    path = os.path.join(arb_dir, name)
    locale = load(path)
    present = [k for k in locale if not k.startswith('@')]

    for key in keys:
        if key not in present:
            problems.append(f'{name}: missing key "{key}"')

    for key in present:
        if key not in keys:
            problems.append(f'{name}: key "{key}" is not in the template')
            continue
        want = placeholders(template[key])
        got = placeholders(locale[key])
        for missing in sorted(want - got):
            problems.append(
                f'{name}: "{key}" has no placeholder {{{missing}}}'
            )
        for extra in sorted(got - want):
            problems.append(
                f'{name}: "{key}" has placeholder {{{extra}}}, '
                'which the template does not declare'
            )
        # Branch SHAPES, not bodies. A locale legitimately drops `one` when its
        # grammar has no singular — but only by declaring `other`, never by
        # having no branches where the template has some.
        want_branches = branches(template[key])
        got_branches = branches(locale[key])
        if want_branches and not got_branches:
            problems.append(
                f'{name}: "{key}" is an ICU plural in the template and a '
                'plain string here'
            )
        if got_branches and 'other' not in got_branches:
            problems.append(f'{name}: "{key}" has no `other` branch')

if problems:
    print('check_arb_parity: FAILED')
    for problem in problems:
        print(f'  {problem}')
    sys.exit(1)
print(f'check_arb_parity: OK ({len(keys)} keys)')
PY
