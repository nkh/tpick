#!/usr/bin/env bash
# test/steps/01-args.sh — argument parsing and usage.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "01 — args / usage"

# no ITEMS_FILE: items come from stdin; empty stdin -> no items -> exit 1
rc=0; "$PP" </dev/null >/dev/null 2>&1 || rc=$?
assert_eq 1 "$rc" "no items on stdin -> exit 1"
# explicit "-" also reads stdin
rc=0; "$PP" - </dev/null >/dev/null 2>&1 || rc=$?
assert_eq 1 "$rc" "'-' reads stdin; empty -> exit 1"

# extra option with no fzf installed -> rejected (exit 2)
rc=0; printf 'a\n' | "$PP" --reverse >/dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "extra option without fzf -> exit 2"

# items file not found
rc=0; "$PP" /tmp/does-not-exist-$$ >/dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "missing items file -> exit 2"

# --help exits 0 and prints a usage line
out="$("$PP" --help 2>&1)"; rc=$?
assert_eq 0 "$rc" "--help -> exit 0"
assert_contains "$out" "tpick" "--help prints the program name"
assert_contains "$out" "ITEMS_FILE" "--help mentions ITEMS_FILE"
assert_contains "$out" "stdin" "--help mentions stdin"
