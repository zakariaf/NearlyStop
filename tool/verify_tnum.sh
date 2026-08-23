#!/usr/bin/env bash
set -euo pipefail
# Prints the OpenType feature tags each bundled face carries, so the
# `FontFeature.tabularFigures()` declaration on the dose numeral can be checked
# against the SHIPPED files rather than against memory.
#
# Re-run after any font bump and update the comment beside the `doseNumeral`
# slot in lib/theme/daybreak_typography.dart with the date and the result.
cd "$(dirname "$0")/.."
exec python3 tool/verify_tnum.py
