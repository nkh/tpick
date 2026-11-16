#!/usr/bin/env bash
# test/steps/09-signal.sh — a SIGTERM while tpick is blocked (reading
# items from a held-open pipe) removes the temp file and exits 143 (128+15),
# via the TERM cleanup trap. Verifies item 8 (signal-safe cleanup).
#
# We test SIGTERM as the representative signal. The script also traps INT and
# HUP, but SIGINT is not exercised here: bash defers a trapped SIGINT while a
# `read` builtin is blocked on a non-terminal fd, so `kill -INT` would not
# interrupt it (a real Ctrl-C reaches tpick via fzf — which catches INT
# and exits, firing the EXIT trap — or via the tty). SIGKILL can never be
# caught, so `kill -9` is the one case where a temp file can leak; that is
# unavoidable by design.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/lib/assert.sh"
PP="$(cd "$HERE/.." && pwd)/tpick"

plan() { printf '\n== %s ==\n' "$1"; }
plan "09 — signal-safe temp-file cleanup"

norm_count() { find "$1" -maxdepth 1 -type f -name 'tmp.*' | wc -l | tr -d ' '; }

# Run tpick with a controlled TMPDIR (so we can see whether the temp file
# leaked) and no fzf on PATH. Items come from a held-open FIFO: tpick
# reads one line into the temp file, then blocks on the next read — so the temp
# file exists when we send the signal.
td="$(mktemp -d)"; fifo="$td/in"; mkfifo "$fifo"
TMUX="" TMPDIR="$td" PATH="/usr/bin:/bin" "$PP" < "$fifo" >/dev/null 2>&1 & pid=$!
exec 3>"$fifo"                # open writer: tpick's read-open completes
printf 'a\talpha\n' >&3       # one item -> temp file gets a line; next read blocks
nf=0
for _ in $(seq 1 20); do      # wait (up to 2s) for the temp file to appear
  nf="$(norm_count "$td")"; [[ "$nf" -ge 1 ]] && break
  sleep 0.1
done
assert_eq 1 "$nf" "temp file exists while tpick is blocked"
kill -TERM "$pid"; wait "$pid" 2>/dev/null; rc=$?
exec 3>&-
assert_eq 143 "$rc" "SIGTERM -> exit 143 (128+15)"
for _ in $(seq 1 20); do      # wait (up to 2s) for the temp file to be removed
  nf="$(norm_count "$td")"; [[ "$nf" -eq 0 ]] && break
  sleep 0.1
done
assert_eq 0 "$nf" "temp file removed on SIGTERM (no leak)"
rm -rf "$td"
