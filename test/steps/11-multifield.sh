#!/usr/bin/env bash
# test/steps/11-multifield.sh — items with more than two TAB-separated fields.
#
# tpick is field-agnostic: it returns the WHOLE line (all fields), shows
# fields from the second onward, and lets the preview template reference any
# field ({1}, {2}, {3}, …). The caller extracts the key (first field) itself.
# This step exercises the fzf path (fake fzf) and the numbered-list fallback.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "11 — multifield items (more than two TAB fields)"

# ---- fzf path: fake fzf on PATH ----
FAKEBIN="$(mktemp -d)"
cp "$HERE/lib/fake-fzf.sh" "$FAKEBIN/fzf"
chmod +x "$FAKEBIN/fzf"
export PATH="$FAKEBIN:$PATH"
export FAKE_FZF_PICK

items="$(mktemp)"
# three fields: key / list display / a preview-only note
printf 'v1.2.3\trelease 1.2.3\ttagged 2024-01-15\nv1.3.0\trelease 1.3.0\ttagged 2024-03-20\n' > "$items"

# the whole 3-field line comes back (not just field 1)
FAKE_FZF_PICK=v1.3.0; out="$("$PP" --prompt rel "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "multifield fzf single -> exit 0"
assert_eq $'v1.3.0\trelease 1.3.0\ttagged 2024-03-20' "$out" "multifield -> whole line returned"

# the caller extracts the key (field 1) from the returned line itself
key="${out%%$'\t'*}"
assert_eq "v1.3.0" "$key" "caller extracts field 1 as the key"
# and may read later fields too
note="${out#*$'\t'}"; note="${note#*$'\t'}"
assert_eq "tagged 2024-03-20" "$note" "caller may read field 3 from the line"

# multi-select returns two whole 3-field lines
FAKE_FZF_PICK=$'v1.2.3\nv1.3.0'; out="$("$PP" --multi --prompt rel "$items" 2>/dev/null)"; rc=$?
assert_eq 0 "$rc" "multifield multi -> exit 0"
assert_eq $'v1.2.3\trelease 1.2.3\ttagged 2024-01-15\nv1.3.0\trelease 1.3.0\ttagged 2024-03-20' "$out" \
  "multifield multi -> two whole lines"

# the preview template may reference {3} (and {1}); tpick forwards it as-is
argv="$(mktemp)"
FAKE_FZF_PICK=v1.3.0 FAKE_FZF_ARGV="$argv" "$PP" --preview 'echo {1} {3}' "$items" >/dev/null 2>&1
av="$(cat "$argv")"
assert_contains "$av" "--preview" "multifield: --preview forwarded"
assert_contains "$av" "{1} {3}" "multifield: {3} reaches fzf in the template"

# --nth controls which fields fzf DISPLAYS (does not affect what comes back)
: > "$argv"
FAKE_FZF_PICK=v1.3.0 FAKE_FZF_ARGV="$argv" "$PP" --nth 2,3 "$items" >/dev/null 2>&1
assert_contains "$(cat "$argv")" "2,3" "--nth 2,3 forwarded (display both columns)"

rm -rf "$FAKEBIN" "$items" "$argv"

# ---- numbered-list fallback (no fzf): multifield lines come back whole ----
export PATH=/usr/bin:/bin
if command -v fzf >/dev/null 2>&1; then
  ok "SKIP: fzf present on minimal PATH (unexpected); multifield fallback not run"
  exit 0
fi

items="$(mktemp)"
printf 'a\tbeta\tone\nb\tgamma\ttwo\n' > "$items"
errf="$(mktemp)"

# pick 1 -> the whole 3-field line
out="$(printf '1\n' | "$PP" --prompt pick "$items" 2>"$errf")"; rc=$?
assert_eq 0 "$rc" "multifield fallback pick 1 -> exit 0"
assert_eq $'a\tbeta\tone' "$out" "multifield fallback -> whole line returned"
# the fallback shows fields 2..end (the display) in its numbered list
assert_contains "$(cat "$errf")" "beta" "fallback shows field 2"
assert_contains "$(cat "$errf")" "one" "fallback shows field 3 (fields 2..end)"

rm -f "$items" "$errf"
