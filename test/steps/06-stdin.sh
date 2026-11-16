#!/usr/bin/env bash
# test/steps/06-stdin.sh — items read from stdin (the Unix-idiomatic default).
# Exercises the fzf path (fake fzf) and the numbered-list fallback's stdin
# reading. The fallback's interactive /dev/tty choice is not asserted here — it
# needs a controlling terminal and would block on a real one; the numbered-list
# rendering itself is already covered by step 02.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "06 — items from stdin"

# ---- fzf path: pipe items in, fake fzf picks ----
FAKEBIN="$(mktemp -d)"
cp "$HERE/lib/fake-fzf.sh" "$FAKEBIN/fzf"
chmod +x "$FAKEBIN/fzf"
export PATH="$FAKEBIN:$PATH"
export FAKE_FZF_PICK

# key<TAB>display piped in
FAKE_FZF_PICK=a; out="$(printf 'a\talpha\nb\tbeta\n' | "$PP" --prompt pick 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "stdin + fzf single -> exit 0"
assert_eq $'a\talpha' "$out" "stdin + fzf single -> whole line a"

# bare keys piped in
FAKE_FZF_PICK=y; out="$(printf 'x\ny\n' | "$PP" --prompt pick 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "stdin bare-key -> exit 0"
assert_eq $'y\ty' "$out" "stdin bare-key -> whole line y"

# multi-select from stdin
FAKE_FZF_PICK=$'a\nc'; out="$(printf 'a\talpha\nb\tbeta\nc\tgamma\n' | "$PP" --multi --prompt pick 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "stdin + fzf multi -> exit 0"
assert_eq $'a\talpha\nc\tgamma' "$out" "stdin + fzf multi -> whole lines a and c"

# explicit "-" reads stdin
FAKE_FZF_PICK=a; out="$(printf 'a\talpha\n' | "$PP" - 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "'-' reads stdin -> exit 0"
assert_eq $'a\talpha' "$out" "'-' reads stdin -> whole line a"

rm -rf "$FAKEBIN"

# ---- numbered-list fallback (no fzf): stdin is read there too ----
export PATH=/usr/bin:/bin
if command -v fzf >/dev/null 2>&1; then
  ok "SKIP: fzf present on minimal PATH (unexpected); fallback stdin cases not run"
  exit 0
fi

out="$(printf '' | "$PP" --prompt pick 2>/dev/null)"; rc=$?
assert_eq 1 "$rc" "stdin fallback: empty items -> exit 1"
assert_eq "" "$out" "stdin fallback: empty items -> empty output"
