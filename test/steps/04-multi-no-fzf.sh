#!/usr/bin/env bash
# test/steps/04-multi-no-fzf.sh — --multi without fzf errors cleanly.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "04 — --multi without fzf errors"

export PATH=/usr/bin:/bin
if command -v fzf >/dev/null 2>&1; then
  ok "SKIP: fzf present on minimal PATH (unexpected)"
  exit 0
fi

items="$(mktemp)"; printf 'a\talpha\nb\tbeta\n' > "$items"

errf="$(mktemp)"
out="$("$PP" --multi "$items" 2>"$errf" </dev/null)"; rc=$?
assert_eq 2 "$rc" "--multi without fzf -> exit 2"
assert_contains "$(cat "$errf")" "--multi requires fzf" "stderr explains --multi needs fzf"
assert_eq "" "$out" "--multi without fzf -> no output"

rm -f "$items" "$errf"
