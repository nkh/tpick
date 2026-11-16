#!/usr/bin/env bash
# test/steps/05-preview-arg.sh — tpick forwards --preview/--multi/--header
# to fzf (verified via the fake fzf's argv recording).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "05 — preview/multi/header forwarded to fzf"

FAKEBIN="$(mktemp -d)"
cp "$HERE/lib/fake-fzf.sh" "$FAKEBIN/fzf"
chmod +x "$FAKEBIN/fzf"
export PATH="$FAKEBIN:$PATH"

items="$(mktemp)"; printf 'a\talpha\nb\tbeta\n' > "$items"
argv="$(mktemp)"

# --preview is forwarded with a preview-window
FAKE_FZF_PICK=a FAKE_FZF_ARGV="$argv" "$PP" --preview 'cat {1}.txt' "$items" >/dev/null 2>&1
av="$(cat "$argv")"
assert_contains "$av" "--preview" "fzf got --preview"
assert_contains "$av" "cat {1}.txt" "fzf got the preview template"
assert_contains "$av" "--preview-window" "fzf got --preview-window"
assert_contains "$av" "--delimiter" "fzf got --delimiter (key/display split)"
assert_contains "$av" "--with-nth" "fzf got --with-nth (display column)"
assert_contains "$av" "2.." "default --nth forwards 2.. (fields 2 onward)"

# --nth overrides the displayed fields
: > "$argv"
FAKE_FZF_PICK=a FAKE_FZF_ARGV="$argv" "$PP" --nth 1,2 "$items" >/dev/null 2>&1
assert_contains "$(cat "$argv")" "1,2" "--nth 1,2 is forwarded to fzf"

# --multi is forwarded
: > "$argv"
FAKE_FZF_PICK=a FAKE_FZF_ARGV="$argv" "$PP" --multi "$items" >/dev/null 2>&1
assert_contains "$(cat "$argv")" "--multi" "fzf got --multi"

# --header is forwarded
: > "$argv"
FAKE_FZF_PICK=a FAKE_FZF_ARGV="$argv" "$PP" --header "mark some" "$items" >/dev/null 2>&1
assert_contains "$(cat "$argv")" "--header" "fzf got --header"
assert_contains "$(cat "$argv")" "mark some" "fzf got the header text"

# without --preview, no --preview flag is sent
: > "$argv"
FAKE_FZF_PICK=a FAKE_FZF_ARGV="$argv" "$PP" "$items" >/dev/null 2>&1
assert_not_contains "$(cat "$argv")" "--preview" "no --preview flag when none requested"

rm -rf "$FAKEBIN" "$items" "$argv"
