#!/usr/bin/env bash
# test/steps/02-fallback.sh — the numbered-list fallback used when fzf is absent.
# Run with a PATH that contains no fzf, so tpick takes the fallback path.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "02 — numbered-list fallback (no fzf)"

# guarantee no fzf on PATH for this step
export PATH=/usr/bin:/bin
if command -v fzf >/dev/null 2>&1; then
  ok "SKIP: fzf present on minimal PATH (unexpected); fallback not exercised"
  exit 0
fi

items="$(mktemp)"
printf 'a\talpha\nb\tbeta\n' > "$items"

# pick 1 -> whole line a
out="$(printf '1\n' | "$PP" --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "pick 1 -> exit 0"
assert_eq $'a\talpha' "$out" "pick 1 -> whole line a"

# pick 2 -> whole line b
out="$(printf '2\n' | "$PP" --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "pick 2 -> exit 0"
assert_eq $'b\tbeta' "$out" "pick 2 -> whole line b"

# out of range -> cancelled
out="$(printf '9\n' | "$PP" --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 1 "$rc" "pick 9 (out of range) -> exit 1"
assert_eq "" "$out" "out-of-range selection -> empty output"

# empty choice -> cancelled
out="$(printf '' | "$PP" --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 1 "$rc" "empty choice -> exit 1"

# fallback prints a numbered list to stderr
errf="$(mktemp)"; printf '1\n' | "$PP" --prompt pick "$items" 2>"$errf" >/dev/null
assert_contains "$(cat "$errf")" "1) alpha" "fallback prints '1) alpha'"
assert_contains "$(cat "$errf")" "2) beta" "fallback prints '2) beta'"

# empty items file -> exit 1
empty="$(mktemp)"
out="$("$PP" "$empty" 2>/dev/null </dev/null)"; rc=$?
assert_eq 1 "$rc" "empty items file -> exit 1"

# bare-key items (no display) are shown as their own display after normalization
bare="$(mktemp)"; printf 'x\ny\n' > "$bare"
errb="$(mktemp)"
bout="$(printf '1\n' | "$PP" --prompt pick "$bare" 2>"$errb")"
assert_eq $'x\tx' "$bout" "bare-key pick 1 -> whole line x"
assert_contains "$(cat "$errb")" "1) x" "bare-key fallback shows '1) x' (display = key)"

rm -f "$items" "$errf" "$empty" "$bare" "$errb"
