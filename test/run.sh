#!/usr/bin/env bash
# test/run.sh — dispatch one tpick test step.
# Usage: test/run.sh <step-id>   e.g. test/run.sh 01-args
set -uo pipefail
STEP="${1:?step id required (e.g. 01-args)}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/steps/${STEP}.sh"
if [[ ! -f "$SCRIPT" ]]; then
  printf 'PENDING  %s (create %s)\n' "$STEP" "$SCRIPT"
  exit 0
fi
bash "$SCRIPT"
