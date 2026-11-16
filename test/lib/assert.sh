#!/usr/bin/env bash
# test/lib/assert.sh — minimal assertion helpers for tpick tests.
ASSERTS_PASSED=0
ASSERTS_FAILED=0
ok()   { printf 'PASS  %s\n' "$1"; ASSERTS_PASSED=$((ASSERTS_PASSED+1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; ASSERTS_FAILED=$((ASSERTS_FAILED+1)); }
assert_eq() {
  local e="$1" g="$2" m="${3:-}"
  if [[ "$e" == "$g" ]]; then ok "${m:+$m: }==$e"
  else fail "${m:+$m: }expected [$e] got [$g]"; fi
}
assert_contains() {
  local h="$1" n="$2" m="${3:-contains $2}"
  if [[ "$h" == *"$n"* ]]; then ok "$m"
  else fail "$m: [$n] not found"; fi
}
assert_not_contains() {
  local h="$1" n="$2" m="${3:-absent $2}"
  if [[ "$h" != *"$n"* ]]; then ok "$m"
  else fail "$m: [$n] unexpectedly present"; fi
}
_atexit() {
  printf '\n-- %d passed, %d failed --\n' "$ASSERTS_PASSED" "$ASSERTS_FAILED"
  [[ "$ASSERTS_FAILED" -eq 0 ]]
}
trap _atexit EXIT
