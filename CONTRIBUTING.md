# Contributing to NearlyStop

## The front door

Read **`.claude/skills/flutter-conventions-index`** first. It states the
cross-cutting house rules and routes each task to the skill that owns it. This
file deliberately restates none of them — a second copy is a copy that drifts.

Two documents outrank a skill where they disagree:

- **`epics/CONTRACTS.md`** — the arbiter for anything that crosses an epic
  boundary (canonical types, the repository API, token slot names, formatting).
- **`SPEC.md`** — the product. Read it before writing code.

## The workflow, one epic at a time

```
1. branch: epic/NN-slug
2. read epics/EPIC-NN-*.md and load every skill in its "Skills to load" table
3. for each task, in order:
     RED      write the named failing test, run it, watch it fail for the right reason
     GREEN    the least code that passes
     REFACTOR clean up, tests stay green
4. /simplify     → fix every finding
5. /code-review  → fix every finding
6. open a PR using .github/pull_request_template.md
7. CI green — never merge on red, never on pending
8. merge to main
```

**Both quality gates run before the PR is opened, not after.** They answer
different questions: `/simplify` is quality only and does not hunt bugs;
`/code-review` is the bug hunt. Running one is not running the other.

A task tagged **Scaffold** in an epic has no behaviour to assert and gets no
test; a task tagged **TDD** is written test-first, and the red step is not
optional. Watching a test fail *for the right reason* is the whole value.

## Running the gates locally

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
bash tool/check_bans.sh
bash tool/check_core_purity.sh
bash tool/check_structure.sh
bash tool/audit-deps.sh
bash tool/coverage_include_untested.sh
flutter test --coverage --test-randomize-ordering-seed random
bash tool/coverage_floor.sh
```

`tool/` is the only script directory, and `tool/check_bans.sh` is the single
grep entry point CI calls. Later epics **extend** it; none of them creates a
second gate somewhere else. Every gate ships a `*_selftest.sh` asserting both
arms, because a gate that has never been seen to fail is a comment.
