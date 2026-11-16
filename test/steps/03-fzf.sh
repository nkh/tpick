#!/usr/bin/env bash
# test/steps/03-fzf.sh — the fzf code path, driven by a fake fzf on PATH.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "03 — fzf path (fake fzf on PATH)"

# install the fake fzf on PATH
FAKEBIN="$(mktemp -d)"
cp "$HERE/lib/fake-fzf.sh" "$FAKEBIN/fzf"
chmod +x "$FAKEBIN/fzf"
export PATH="$FAKEBIN:$PATH"
export FAKE_FZF_PICK      # exported so the fake-fzf child sees it
export FAKE_FZF_EXIT      #   "   (lets a test make the fake fzf exit non-zero)

items="$(mktemp)"
printf 'a\talpha\nb\tbeta\nc\tgamma\n' > "$items"

# single selection
FAKE_FZF_PICK=a; out="$("$PP" --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "fzf single -> exit 0"
assert_eq $'a\talpha' "$out" "fzf single -> whole line a"

# multi selection (two whole lines)
FAKE_FZF_PICK=$'a\nc'; out="$("$PP" --multi --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "fzf multi -> exit 0"
assert_eq $'a\talpha\nc\tgamma' "$out" "fzf multi -> whole lines a and c"

# bare-key items (no display) come back normalized to key<TAB>key
bare="$(mktemp)"; printf 'x\ny\n' > "$bare"
FAKE_FZF_PICK=y; out="$("$PP" --prompt pick "$bare" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "bare-key item -> exit 0"
assert_eq $'y\ty' "$out" "bare-key item -> whole line y"

# cancelled (empty pick) -> exit 1, empty output
FAKE_FZF_PICK=; out="$("$PP" --prompt pick "$items" 2>/dev/null)"; rc=$?
assert_eq 1 "$rc" "fzf cancelled -> exit 1"
assert_eq "" "$out" "fzf cancelled -> empty output"

# fzf returns non-zero (user pressed Esc/Ctrl-C): exit 1 and do NOT fall
# through to the numbered-list fallback (no "N) ..." lines on stderr).
FAKE_FZF_PICK=a FAKE_FZF_EXIT=130
errf="$(mktemp)"
out="$("$PP" --prompt pick "$items" 2>"$errf")"; rc=$?
assert_eq 1 "$rc" "fzf non-zero (cancel) -> exit 1"
assert_eq "" "$out" "fzf cancel -> empty output"
assert_not_contains "$(cat "$errf")" ") alpha" "fzf cancel does NOT show numbered fallback"
rm -f "$errf"

rm -rf "$FAKEBIN" "$items" "$bare"
