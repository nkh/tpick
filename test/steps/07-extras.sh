#!/usr/bin/env bash
# test/steps/07-extras.sh — unrecognized options are forwarded to fzf verbatim
# when fzf is available (verified via the fake fzf's argv recording), and the
# pick still works. Rejection when fzf is absent is covered by step 01.
#
# FAKE_FZF_PICK / FAKE_FZF_ARGV are exported and set as separate statements
# before each call, so they reach tpick even when its stdout is captured
# in a command substitution (temporary prefixes on an assignment line do not).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "07 — extra options forwarded to fzf"

FAKEBIN="$(mktemp -d)"
cp "$HERE/lib/fake-fzf.sh" "$FAKEBIN/fzf"
chmod +x "$FAKEBIN/fzf"
export PATH="$FAKEBIN:$PATH"
export FAKE_FZF_PICK FAKE_FZF_ARGV

items="$(mktemp)"; printf 'a\talpha\nb\tbeta\n' > "$items"
argv="$(mktemp)"

# a flag option (--reverse) is forwarded, and the pick still works
: > "$argv"; FAKE_FZF_PICK=a; FAKE_FZF_ARGV="$argv"
out="$("$PP" --prompt pick --reverse "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "--reverse: exit 0"
assert_eq $'a\talpha' "$out" "--reverse: pick still works (whole line)"
assert_contains "$(cat "$argv")" "--reverse" "fzf got --reverse"

# --opt=value form forwards the option and its value as one token
: > "$argv"; FAKE_FZF_PICK=a; FAKE_FZF_ARGV="$argv"
"$PP" --height=10 "$items" >/dev/null 2>&1
assert_contains "$(cat "$argv")" "--height=10" "fzf got --height=10 (one token)"

# --opt=value with a non-trivial value
: > "$argv"; FAKE_FZF_PICK=a; FAKE_FZF_ARGV="$argv"
"$PP" --pointer=PTR "$items" >/dev/null 2>&1
assert_contains "$(cat "$argv")" "--pointer=PTR" "fzf got --pointer=PTR (one token)"

# several extras at once + a pick from further down the list
: > "$argv"; FAKE_FZF_PICK=b; FAKE_FZF_ARGV="$argv"
out="$("$PP" --reverse --height=10 --cycle "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "several extras: exit 0"
assert_eq $'b\tbeta' "$out" "several extras: pick b (whole line)"
av="$(cat "$argv")"
assert_contains "$av" "--reverse" "fzf got --reverse"
assert_contains "$av" "--height=10" "fzf got --height=10"
assert_contains "$av" "--cycle" "fzf got --cycle"

rm -rf "$FAKEBIN" "$items" "$argv"
