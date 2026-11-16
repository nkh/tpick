#!/usr/bin/env bash
# test/lib/fake-fzf-tmux.sh — a stand-in for fzf-tmux used by the --popup test.
#
# Installed on PATH as `fzf-tmux`, it records the argv it was called with to
# $FAKE_FZF_TMUX_ARGV (so tests can assert tpick launched `fzf-tmux -p --
# <fzf-opts>` rather than plain fzf), then mimics fzf's selected-lines output
# exactly like fake-fzf.sh (pick keys from $FAKE_FZF_PICK). Exits with
# ${FAKE_FZF_EXIT:-0}.
[[ -n "${FAKE_FZF_TMUX_ARGV:-}" ]] && printf '%s\n' "$@" >> "$FAKE_FZF_TMUX_ARGV"
picks="${FAKE_FZF_PICK:-}"
while IFS=$'\t' read -r key disp || [[ -n "$key" ]]; do
  [[ -z "$key" ]] && continue
  if grep -qx -- "$key" <<<"$picks"; then
    printf '%s\t%s\n' "$key" "${disp:-}"
  fi
done
exit "${FAKE_FZF_EXIT:-0}"
