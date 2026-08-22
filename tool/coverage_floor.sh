#!/usr/bin/env bash
set -uo pipefail
# coverage_floor.sh — coverage is a published REPORT, never a global gate. A
# percentage threshold rewards tests that assert nothing. What is gated is a
# short, named list of FILES where a bug is unrecoverable, held at their floor.
#
# Usage: bash tool/coverage_floor.sh [LCOV] [FLOORS] [ANALYSIS_OPTIONS]
#        defaults: coverage/lcov.info tool/coverage_floors.txt analysis_options.yaml
#
# The generated-code globs are READ FROM analysis_options.yaml, never retyped
# here: excludes and coverage filters that drift apart lie the number upward.
#
# Requires python3 (preinstalled on ubuntu-24.04 runners and on macOS).

lcov_file="${1:-coverage/lcov.info}"
floors_file="${2:-tool/coverage_floors.txt}"
options_file="${3:-analysis_options.yaml}"

exec python3 - "$lcov_file" "$floors_file" "$options_file" <<'PY'
import re
import sys

lcov_path, floors_path, options_path = sys.argv[1:4]


def die(message):
    print(message)
    raise SystemExit(1)


def read_excludes(path):
    """The analyzer's exclude globs — the ONE place these are written down."""
    globs = []
    in_analyzer = False
    in_exclude = False
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if re.match(r'^analyzer:\s*$', line):
            in_analyzer, in_exclude = True, False
            continue
        if in_analyzer and re.match(r'^\S', line):
            in_analyzer = in_exclude = False
        if in_analyzer and re.match(r'^  exclude:\s*$', line):
            in_exclude = True
            continue
        if in_exclude:
            item = re.match(r'^    - (.+?)\s*$', line)
            if item:
                globs.append(item.group(1).strip('"\''))
                continue
            if line.strip() and not line.startswith('    '):
                in_exclude = False
    return globs


def glob_to_regex(glob):
    out, i = [], 0
    while i < len(glob):
        if glob.startswith('**', i):
            out.append('.*')
            i += 2
        elif glob[i] == '*':
            out.append('[^/]*')
            i += 1
        elif glob[i] == '?':
            out.append('.')
            i += 1
        else:
            out.append(re.escape(glob[i]))
            i += 1
    return re.compile('^' + ''.join(out) + '$')


def read_lcov(path):
    """Returns {source path: (lines_found, lines_hit)}."""
    records, current, found, hit, da = {}, None, None, None, {}
    for raw in open(path, encoding='utf-8'):
        line = raw.strip()
        if line.startswith('SF:'):
            current, found, hit, da = line[3:], None, None, {}
        elif line.startswith('DA:') and current is not None:
            number, _, count = line[3:].partition(',')
            da[number] = int(count or 0)
        elif line.startswith('LF:'):
            found = int(line[3:])
        elif line.startswith('LH:'):
            hit = int(line[3:])
        elif line == 'end_of_record' and current is not None:
            if found is None:
                found = len(da)
            if hit is None:
                hit = sum(1 for c in da.values() if c > 0)
            previous = records.get(current, (0, 0))
            records[current] = (previous[0] + found, previous[1] + hit)
            current = None
    return records


try:
    records = read_lcov(lcov_path)
except OSError:
    die('FAIL: %s not found — run `flutter test --coverage` first.' % lcov_path)

excludes = [glob_to_regex(g) for g in read_excludes(options_path)]
stripped = {p: v for p, v in records.items()
            if not any(rx.match(p) for rx in excludes)}
removed = sorted(set(records) - set(stripped))

floors = []
try:
    for raw in open(floors_path, encoding='utf-8'):
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) != 2:
            die('FAIL: malformed floor line in %s: %r' % (floors_path, raw.rstrip()))
        floors.append((parts[0], float(parts[1])))
except OSError:
    die('FAIL: %s not found.' % floors_path)

total_found = sum(f for f, _ in stripped.values())
total_hit = sum(h for _, h in stripped.values())
aggregate = (100.0 * total_hit / total_found) if total_found else 100.0

print('coverage_floor: %d file(s) after excludes, aggregate %.1f%% (%d/%d lines).'
      % (len(stripped), aggregate, total_hit, total_found))
if removed:
    print('  excluded by the analyzer globs in %s:' % options_path)
    for path in removed:
        print('    %s' % path)

problems = []
for path, floor in floors:
    if path not in stripped:
        problems.append(
            '%s is listed at a %.0f%% floor but is ABSENT from %s.\n'
            '        A missing path is never a skip — a rename would silently\n'
            '        disarm the floor on a file whose bug is unrecoverable.'
            % (path, floor, lcov_path))
        continue
    found, hit = stripped[path]
    pct = (100.0 * hit / found) if found else 100.0
    if pct + 1e-9 < floor:
        problems.append('%s is at %.1f%% (%d/%d lines), below its %.0f%% floor.'
                        % (path, pct, hit, found, floor))

if problems:
    print()
    print('coverage_floor: %d floor violation(s).' % len(problems))
    for problem in problems:
        print('  %s' % problem)
    raise SystemExit(1)

print('coverage_floor: OK (%d floor(s) held; everything else is reported, not gated).'
      % len(floors))
PY
