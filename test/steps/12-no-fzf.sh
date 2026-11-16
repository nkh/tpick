#!/usr/bin/env bash
# test/steps/12-no-fzf.sh — --no-fzf forces the numbered-list fallback even
# when fzf IS installed. A fake fzf is put on PATH (so `command -v fzf` wins);
# with --no-fzf tpick must ignore it and take the fallback path, while
# without --no-fzf the fake fzf is used (the control that proves the flag is
# what makes the difference).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "12 -- --no-fzf forces the numbered-list fallback (fzf present)"

# install the fake fzf on PATH so fzf is "available" for this step
FAKEBIN="$(mktemp -d)"
cp "$HERE/lib/fake-fzf.sh" "$FAKEBIN/fzf"
chmod +x "$FAKEBIN/fzf"
export PATH="$FAKEBIN:$PATH"
export FAKE_FZF_PICK       # exported so the fake-fzf child sees it
export FAKE_FZF_EXIT

# a sentinel file the fake fzf appends its argv to when it is invoked
called="$(mktemp)"
export FAKE_FZF_ARGV="$called"

items="$(mktemp)"
printf 'a\talpha\nb\tbeta\n' > "$items"

# --- control: WITHOUT --no-fzf, the fake fzf IS used ----------------------
FAKE_FZF_PICK=a
: > "$called"
out="$("$PP" --prompt pick "$items" </dev/null 2>/dev/null)"; rc=$?
assert_eq 0   "$rc"           "control (no --no-fzf): exit 0 via fake fzf"
assert_eq $'a\talpha' "$out"  "control (no --no-fzf): fake fzf picked a"
# the fake fzf appends one line per argv token, so a non-empty file (with the
# always-forwarded --prompt=) proves it was invoked.
assert_contains "$(cat "$called")" "--prompt=" "control (no --no-fzf): fake fzf was invoked"
rm -f "$called"

# --- --no-fzf forces the fallback: fake fzf must NOT be called ------------
: > "$called"
out="$(printf '1\n' | "$PP" --no-fzf --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 0   "$rc"           "--no-fzf pick 1 -> exit 0"
assert_eq $'a\talpha' "$out"  "--no-fzf pick 1 -> whole line a (fallback, not fzf)"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf: fake fzf NOT invoked"
rm -f "$called"

: > "$called"
out="$(printf '2\n' | "$PP" --no-fzf --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 0   "$rc"           "--no-fzf pick 2 -> exit 0"
assert_eq $'b\tbeta' "$out"   "--no-fzf pick 2 -> whole line b"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf pick 2: fake fzf NOT invoked"
rm -f "$called"

# --- the numbered list is printed to stderr (fallback UI) -----------------
errf="$(mktemp)"
: > "$called"
printf '1\n' | "$PP" --no-fzf --prompt pick "$items" 2>"$errf" >/dev/null
assert_contains "$(cat "$errf")" "1) alpha" "--no-fzf fallback prints '1) alpha'"
assert_contains "$(cat "$errf")" "2) beta"  "--no-fzf fallback prints '2) beta'"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf (stderr check): fake fzf NOT invoked"

# --- out-of-range / empty choice -> cancelled (exit 1) --------------------
: > "$called"
out="$(printf '9\n' | "$PP" --no-fzf --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 1 "$rc" "--no-fzf out-of-range -> exit 1"
assert_eq "" "$out" "--no-fzf out-of-range -> empty output"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf (oor): fake fzf NOT invoked"
rm -f "$called"

: > "$called"
out="$(printf '' | "$PP" --no-fzf --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 1 "$rc" "--no-fzf empty choice -> exit 1"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf (empty): fake fzf NOT invoked"
rm -f "$called"

# --- options the fallback can't serve are rejected under --no-fzf ---------
: > "$called"
out="$("$PP" --no-fzf --multi "$items" </dev/null 2>/dev/null)"; rc=$?
assert_eq 2 "$rc" "--no-fzf --multi -> exit 2"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf --multi: fake fzf NOT invoked"
rm -f "$called"

: > "$called"
out="$("$PP" --no-fzf --popup "$items" </dev/null 2>/dev/null)"; rc=$?
assert_eq 2 "$rc" "--no-fzf --popup -> exit 2"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf --popup: fake fzf NOT invoked"
rm -f "$called"

: > "$called"
out="$("$PP" --no-fzf --reverse "$items" </dev/null 2>/dev/null)"; rc=$?
assert_eq 2 "$rc" "--no-fzf --reverse (extra fzf opt) -> exit 2"
assert_eq 0 "$(wc -l < "$called")" "--no-fzf --reverse: fake fzf NOT invoked"

rm -rf "$FAKEBIN" "$items" "$errf" "$called"
