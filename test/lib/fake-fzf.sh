#!/usr/bin/env bash
# test/lib/fake-fzf.sh — a stand-in for fzf used by the tpick test suite.
#
# Installed on PATH as `fzf`, it mimics fzf's selected-lines output: it reads
# `key<TAB>display` items on stdin and writes back the lines whose key is listed
# in $FAKE_FZF_PICK (newline-separated). If $FAKE_FZF_ARGV is set, it also
# appends the argv it was called with to that file, so tests can assert that
# tpick forwarded the right options (--preview, --multi, --header) to fzf.
#
# Exits with ${FAKE_FZF_EXIT:-0} (default 0); a non-zero value lets tests
# simulate fzf being cancelled (Esc/Ctrl-C → 130) or erroring. An empty
# $FAKE_FZF_PICK means "nothing selected" (tpick treats that as
# cancelled).
[[ -n "${FAKE_FZF_ARGV:-}" ]] && printf '%s\n' "$@" >> "$FAKE_FZF_ARGV"
picks="${FAKE_FZF_PICK:-}"
while IFS=$'\t' read -r key disp || [[ -n "$key" ]]; do
  [[ -z "$key" ]] && continue
  if grep -qx -- "$key" <<<"$picks"; then
    printf '%s\t%s\n' "$key" "${disp:-}"
  fi
done
exit "${FAKE_FZF_EXIT:-0}"
