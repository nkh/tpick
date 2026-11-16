#!/usr/bin/env bash
# test/steps/10-shellcheck.sh — the script and test helpers are shellcheck-clean.
# Skips (PASS, exit 0) if shellcheck is not installed, so `make test` still
# passes in environments without it. Use `make shellcheck` for a hard check.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "10 — shellcheck clean"

if ! command -v shellcheck >/dev/null 2>&1; then
  ok "shellcheck not installed — skipped"
  exit 0
fi

out="$(mktemp)"
# -x follows `source` so test/lib/assert.sh is checked in the steps' context.
if shellcheck -x "$PP" "$HERE/run.sh" "$HERE"/lib/*.sh "$HERE"/steps/*.sh >"$out" 2>&1; then
  ok "tpick + test/ : shellcheck clean"
else
  fail "shellcheck reported findings:"
  sed 's/^/    /' "$out" >&2
fi
rm -f "$out"
