#!/usr/bin/env bash
# test/steps/08-popup.sh — --popup launches `fzf-tmux -p -- <fzf-opts>` inside
# a tmux session, and degrades to inline fzf (with a warning) when not in tmux
# or when fzf-tmux is missing. Without fzf at all it is rejected (exit 2).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "08 — --popup (fzf-tmux -p inside tmux; degrade otherwise)"

assert_empty() {  # assert a file is zero-size (i.e. a recorded argv is absent)
  local f="$1" m="${2:-empty}"
  if [[ ! -s "$f" ]]; then ok "$m"
  else fail "$m: file not empty ($(wc -l < "$f") lines)"; fi
}

BIN_BOTH="$(mktemp -d)"   # fake fzf AND fake fzf-tmux
BIN_FZF="$(mktemp -d)"    # fake fzf only (no fzf-tmux)
cp "$HERE/lib/fake-fzf.sh"      "$BIN_BOTH/fzf"
cp "$HERE/lib/fake-fzf-tmux.sh" "$BIN_BOTH/fzf-tmux"
cp "$HERE/lib/fake-fzf.sh"      "$BIN_FZF/fzf"
chmod +x "$BIN_BOTH/fzf" "$BIN_BOTH/fzf-tmux" "$BIN_FZF/fzf"

export FAKE_FZF_PICK FAKE_FZF_ARGV FAKE_FZF_TMUX_ARGV TMUX
items="$(mktemp)"; printf 'a\talpha\nb\tbeta\n' > "$items"
fzf_argv="$(mktemp)"; tmux_argv="$(mktemp)"; err="$(mktemp)"

# 1) inside tmux + fzf-tmux present -> launch fzf-tmux -p, NOT plain fzf
: > "$fzf_argv"; : > "$tmux_argv"; : > "$err"
TMUX="/tmp/fake"; FAKE_FZF_PICK=a; FAKE_FZF_ARGV="$fzf_argv"; FAKE_FZF_TMUX_ARGV="$tmux_argv"
out="$(PATH="$BIN_BOTH:$PATH" "$PP" --popup --prompt pick "$items" 2>"$err")"; rc=$?
assert_eq 0 "$rc" "in tmux + fzf-tmux: exit 0"
assert_eq $'a\talpha' "$out" "in tmux + fzf-tmux: pick works (whole line)"
tav="$(cat "$tmux_argv")"
assert_contains "$tav" "-p" "fzf-tmux got -p (popup)"
assert_contains "$tav" "--" "fzf-tmux got -- (separator before fzf opts)"
assert_contains "$tav" "--prompt=pick" "fzf-tmux forwarded tpick's --prompt"
assert_contains "$tav" "--delimiter" "fzf-tmux forwarded --delimiter"
assert_empty "$fzf_argv" "plain fzf was NOT called"
assert_empty "$err" "no warning when popup is served"

# 2) outside tmux -> warn + use inline fzf (fzf-tmux not called)
: > "$fzf_argv"; : > "$tmux_argv"; : > "$err"
TMUX=""; FAKE_FZF_PICK=a; FAKE_FZF_ARGV="$fzf_argv"; FAKE_FZF_TMUX_ARGV="$tmux_argv"
out="$(PATH="$BIN_BOTH:$PATH" "$PP" --popup "$items" 2>"$err")"; rc=$?
assert_eq 0 "$rc" "outside tmux: exit 0 (degraded to fzf)"
assert_eq $'a\talpha' "$out" "outside tmux: pick works (whole line)"
assert_contains "$(cat "$err")" "tmux session" "warned about needing a tmux session"
assert_empty "$tmux_argv" "fzf-tmux was NOT called"

# 3) inside tmux but fzf-tmux not installed -> warn + use inline fzf
: > "$fzf_argv"; : > "$tmux_argv"; : > "$err"
TMUX="/tmp/fake"; FAKE_FZF_PICK=a; FAKE_FZF_ARGV="$fzf_argv"; FAKE_FZF_TMUX_ARGV="$tmux_argv"
out="$(PATH="$BIN_FZF:$PATH" "$PP" --popup "$items" 2>"$err")"; rc=$?
assert_eq 0 "$rc" "no fzf-tmux: exit 0 (degraded to fzf)"
assert_eq $'a\talpha' "$out" "no fzf-tmux: pick works (whole line)"
assert_contains "$(cat "$err")" "fzf-tmux" "warned about missing fzf-tmux"

# 4) --popup without fzf at all -> rejected (exit 2), like --multi
rc=0
printf 'a\n' | PATH="/usr/bin:/bin" "$PP" --popup >/dev/null 2>&1 || rc=$?
assert_eq 2 "$rc" "--popup without fzf -> exit 2"

rm -rf "$BIN_BOTH" "$BIN_FZF" "$items" "$fzf_argv" "$tmux_argv" "$err"
