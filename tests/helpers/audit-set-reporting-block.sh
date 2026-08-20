#!/usr/bin/env bash
# T-3105: exercise the verdict-over-a-set emitters from agents/audit/audit.sh
# in isolation.
#
# Same technique as tests/helpers/audit-branch-hygiene-block.sh: the functions
# live inside a 6000-line script whose top-level run takes a global lock, so the
# shipped definitions are EXTRACTED from the real source and evaluated against
# stub pass/warn/info/fail. Extracting rather than copying keeps the assertions
# pinned to the file that ships — a copy would keep passing forever after
# audit.sh changed, which is the defect class this rail exists to catch.
#
# Usage: audit-set-reporting-block.sh <framework_root> <fn> [args...]
#   fn is 'pass_over' or 'warn_unenumerable'; args are passed through verbatim.
# Emits: PASS|<msg> / WARN|<msg> + EVIDENCE|.. + MITIGATION|..
#        and a trailing COUNTS|pass=N|warn=N|fail=N line.
REPO_ROOT="$1"; shift
PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
pass() { echo "PASS|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
info() { echo "INFO|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { echo "WARN|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
eval "$(sed -n '/^pass_over() {/,/^}/p' "$REPO_ROOT/agents/audit/audit.sh")"
eval "$(sed -n '/^warn_unenumerable() {/,/^}/p' "$REPO_ROOT/agents/audit/audit.sh")"
"$@"
echo "COUNTS|pass=$PASS_COUNT|warn=$WARN_COUNT|fail=$FAIL_COUNT"
