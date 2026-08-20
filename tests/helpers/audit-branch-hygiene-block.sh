#!/usr/bin/env bash
# T-3095: run the branch-hygiene block from agents/audit/audit.sh in isolation.
#
# The block lives inside a 6000-line script whose top-level run takes a global
# lock ("Another audit is already running — exiting"), so neither the tests nor
# the P-011 verification gate can invoke audit.sh directly: the close path runs
# its own audit and the two race. This extracts the shipped block and evaluates
# it against stub pass/warn/info/fail, so the assertions stay pinned to the real
# source without needing the lock.
#
# Usage: audit-branch-hygiene-block.sh <framework_root> <project_root>
# Emits: PASS|<msg> / INFO|<msg> / WARN|<msg> + EVIDENCE|.. + MITIGATION|..
#        and a trailing COUNTS|pass=N|warn=N|fail=N line.
REPO_ROOT="$1"; PROJECT_ROOT="$2"; FRAMEWORK_ROOT="$REPO_ROOT"
PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
pass() { echo "PASS|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
info() { echo "INFO|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { echo "WARN|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { echo "FAIL|$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
eval "$(sed -n '/^fw_is_linked_worktree() {/,/^}/p' "$REPO_ROOT/lib/paths.sh")"
eval "$(sed -n '/^_bh_lib="\$FRAMEWORK_ROOT\/lib\/branch-hygiene\.sh"$/,/^fi$/p' "$REPO_ROOT/agents/audit/audit.sh")"
echo "COUNTS|pass=$PASS_COUNT|warn=$WARN_COUNT|fail=$FAIL_COUNT"
