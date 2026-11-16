# tpick — Makefile.
SHELL := /usr/bin/env bash

.PHONY: help test test-01-args test-02-fallback test-03-fzf test-04-multi-no-fzf test-05-preview-arg test-06-stdin test-07-extras test-08-popup test-09-signal test-10-shellcheck test-11-multifield test-12-no-fzf shellcheck clean

help:
	@echo "tpick make targets:"
	@echo "  make test   run every test step"
	@echo "  make test-NN-name   run one step"
	@echo "  make shellcheck   lint the script + tests (needs shellcheck)"

test: test-01-args test-02-fallback test-03-fzf test-04-multi-no-fzf test-05-preview-arg test-06-stdin test-07-extras test-08-popup test-09-signal test-10-shellcheck test-11-multifield test-12-no-fzf
	@echo "all tpick steps run (check output above for PASS/FAIL)"

test-01-args:          ; @bash test/run.sh 01-args
test-02-fallback:      ; @bash test/run.sh 02-fallback
test-03-fzf:           ; @bash test/run.sh 03-fzf
test-04-multi-no-fzf:  ; @bash test/run.sh 04-multi-no-fzf
test-05-preview-arg:   ; @bash test/run.sh 05-preview-arg
test-06-stdin:         ; @bash test/run.sh 06-stdin
test-07-extras:        ; @bash test/run.sh 07-extras
test-08-popup:         ; @bash test/run.sh 08-popup
test-09-signal:        ; @bash test/run.sh 09-signal
test-10-shellcheck:    ; @bash test/run.sh 10-shellcheck
test-11-multifield:    ; @bash test/run.sh 11-multifield
test-12-no-fzf:        ; @bash test/run.sh 12-no-fzf

shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed (try: pip install shellcheck-py)"; exit 1; }
	@shellcheck -x tpick test/run.sh test/lib/*.sh test/steps/*.sh && echo "shellcheck: clean"

clean:
	@rm -rf /tmp/tpick-* 2>/dev/null || true
