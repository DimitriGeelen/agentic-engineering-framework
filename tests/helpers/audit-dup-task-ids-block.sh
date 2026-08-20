#!/usr/bin/env bash
# T-3107: run the duplicate-task-ID block from agents/audit/audit.sh in isolation.
#
# Same technique as tests/helpers/audit-set-reporting-block.sh and
# audit-branch-hygiene-block.sh: the block lives inside a 6000-line script whose
# top-level run takes a global lock, so the shipped source is EXTRACTED and
# evaluated against stub pass/warn/info/fail. Extracting rather than copying
# keeps the assertions pinned to the file that ships — a copy would keep passing
# forever after audit.sh changed, which is the defect class this rail exists to
# catch.
#
# Usage: audit-dup-task-ids-block.sh <framework_root> <tasks_dir>
#   <tasks_dir> becomes TASKS_DIR, i.e. the LOCAL corpus view. Sibling worktree
#   views are discovered from it by fw_task_view_dirs, exactly as in production.
#
# Set FW_T3107_NO_VIEWS=1 to stub fw_task_view_dirs to emit nothing (the
# zero-view path); FW_T3107_UNDEF_VIEWS=1 to not define it at all.
#
# Emits: PASS|<msg> / WARN|<msg> + EVIDENCE|.. + MITIGATION|.. / FAIL|<msg> + ..
#        and a trailing COUNTS|pass=N|warn=N|fail=N line.
REPO_ROOT="$1"; TASKS_DIR="$2"
PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
pass() { echo "PASS|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
info() { echo "INFO|$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { echo "WARN|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

eval "$(sed -n '/^pass_over() {/,/^}/p' "$REPO_ROOT/agents/audit/audit.sh")"
eval "$(sed -n '/^warn_unenumerable() {/,/^}/p' "$REPO_ROOT/agents/audit/audit.sh")"

if [ "${FW_T3107_UNDEF_VIEWS:-0}" != "1" ]; then
    if [ "${FW_T3107_NO_VIEWS:-0}" = "1" ]; then
        fw_task_view_dirs() { :; }
    else
        eval "$(sed -n '/^fw_task_view_dirs() {/,/^}/p' "$REPO_ROOT/lib/paths.sh")"
    fi
fi

eval "$(sed -n '/^if ! declare -F fw_task_view_dirs/,/^# end duplicate-task-ID scan$/p' \
        "$REPO_ROOT/agents/audit/audit.sh")"
echo "COUNTS|pass=$PASS_COUNT|warn=$WARN_COUNT|fail=$FAIL_COUNT"
