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
# _extract <label> <file> <sed-range> — pull a shipped construct out of the real
# source and REFUSE to continue if the range matched nothing.
#
# The guard is the point, not the sed. This helper exists so the assertions stay
# pinned to the shipped file, and an unguarded `eval "$(sed ...)"` breaks that
# promise in the quietest possible way: when the construct moves, the range
# matches nothing, eval defines nothing, and the block under test runs with the
# symbol simply absent. It does not error — it takes a different branch and
# emits a plausible-looking verdict.
#
# That is exactly what happened. T-3111 moved fw_is_linked_worktree from
# lib/paths.sh to lib/worktree-identity.sh; the extraction kept pointing at
# lib/paths.sh, the predicate went undefined, and the branch-hygiene block fell
# through to the live path — so `linked worktree: INFO skip` got a WARN and the
# suite went red with no indication that the HARNESS, not the code, had broken.
# An empty extraction is now a hard failure that names the symbol and the file.
_extract() {
    local label="$1" file="$2" range="$3" src
    if [ ! -f "$file" ]; then
        echo "HARNESS-ERROR: $label: no such file: $file" >&2
        exit 3
    fi
    src="$(sed -n "$range" "$file")"
    if [ -z "${src//[[:space:]]/}" ]; then
        echo "HARNESS-ERROR: $label: extraction matched nothing in $file." >&2
        echo "  The construct moved or was renamed. Re-point this extraction —" >&2
        echo "  do NOT let it fall through: the block under test would then run" >&2
        echo "  with '$label' undefined and emit a plausible wrong verdict." >&2
        exit 3
    fi
    printf '%s\n' "$src"
}

# Source overrides exist so the guard above can be tested against a file that
# genuinely does not contain the construct. Without them the only way to prove
# the guard fires is to break the real source, which no test may do.
_IDENTITY_SRC="${T3095_IDENTITY_SRC:-$REPO_ROOT/lib/worktree-identity.sh}"
_AUDIT_SRC="${T3095_AUDIT_SRC:-$REPO_ROOT/agents/audit/audit.sh}"

# _load — extract, CHECK THE EXIT, then eval.
#
# `eval "$(_extract ...)"` does not work and the reason is the whole lesson of
# this task in miniature: `exit 3` inside a command substitution exits the
# SUBSHELL. The parent receives an empty string, evals nothing, and runs on —
# reproducing precisely the silent fall-through the guard was written to stop.
# Measured: the two guard tests below failed with status 0 against that form.
_load() {
    local label="$1" file="$2" range="$3" src
    src="$(_extract "$label" "$file" "$range")" || exit 3
    eval "$src"
}

_load fw_is_linked_worktree "$_IDENTITY_SRC" \
      '/^fw_is_linked_worktree() {/,/^}/p'
_load branch-hygiene-block "$_AUDIT_SRC" \
      '/^_bh_lib="\$FRAMEWORK_ROOT\/lib\/branch-hygiene\.sh"$/,/^fi$/p'
echo "COUNTS|pass=$PASS_COUNT|warn=$WARN_COUNT|fail=$FAIL_COUNT"
