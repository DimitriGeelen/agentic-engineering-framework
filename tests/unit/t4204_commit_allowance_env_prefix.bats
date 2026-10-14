#!/usr/bin/env bats
# T-4204 — the null-focus / partial-complete commit allowance must not admit a
# leading env assignment that steers which fw runs. `PROJECT_ROOT=/x
# .agentic-framework/bin/fw git commit` was ADMITTED by is_commit_checkpoint_command:
# the T-1908 stripper removed PROJECT_ROOT (not on its denylist), the remainder
# judged the launcher against the hook's real roots, and the commit went through.
# At run time fw receives the overridden PROJECT_ROOT. cmd_classify.py already
# refuses the same command, so the two surfaces disagreed.
#
# Fix: the commit clause accepts only leading assignments on a four-name allow-list
# — the documented commit-time bypass prefixes, each exactly `=1`:
# FW_SWITCH_FOCUS (T-3454 contract), FW_ALLOW_STALE_INDEX, FW_ALLOW_MASTER_COMMIT,
# FW_ALLOW_WORKTREE_CORPUS_COMMIT. Anything else is refused.
#
# Probes run the SHIPPED predicate (sourced) and the SHIPPED hook (stdin JSON,
# null focus). `! cmd` is inert in bats (L-628): every refusal is an explicit compare.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB_SC="$ROOT/agents/context/lib/safe-commands.sh"
    HOOK="$ROOT/agents/context/check-active-task.sh"
    GATE="$ROOT/agents/context/budget-gate.sh"
    export ROOT LIB_SC HOOK GATE

    WORK="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$WORK/.context/working" "$WORK/.agentic-framework/bin" \
             "$WORK/.tasks/active" "$WORK/.tasks/completed" "$BATS_TEST_TMPDIR/x/bin"
    printf '#!/bin/bash\necho planted\n' > "$BATS_TEST_TMPDIR/x/bin/fw"
    chmod +x "$BATS_TEST_TMPDIR/x/bin/fw"
    printf 'current_task: null\n' > "$WORK/.context/working/focus.yaml"
    printf '{"level":"critical","tokens":290000,"timestamp":%s,"source":"test"}' \
        "$(date +%s)" > "$WORK/.context/working/.budget-status"
    export WORK
}

# shell_admit <command> — the shell commit allowance, judged the way the hook does:
# FRAMEWORK_ROOT is this checkout, PROJECT_ROOT the project, payload cwd the project.
shell_admit() {
    FRAMEWORK_ROOT="$ROOT" PROJECT_ROOT="$WORK" _FW_PAYLOAD_CWD="$WORK" CMD="$1" bash -c '
        source "$LIB_SC"
        if is_commit_checkpoint_command "$CMD"; then echo ADMIT; else echo REFUSE; fi'
}

# classify_admit <command> — the budget classifier, same roots.
classify_admit() {
    python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
from cmd_classify import classify
ok, _ = classify(sys.argv[2], cwd=sys.argv[3], framework_root=sys.argv[4], project_root=sys.argv[5])
print("ADMIT" if ok else "REFUSE")' "$ROOT/lib" "$1" "$WORK" "$ROOT" "$WORK"
}

# hook_admit <command> — the shipped check-active-task.sh at null focus.
hook_admit() {
    local json
    json="$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$WORK")"
    if printf '%s' "$json" | PROJECT_ROOT="$WORK" FRAMEWORK_ROOT="$ROOT" \
        CLAUDE_PROJECT_DIR="$WORK" bash "$HOOK" >/dev/null 2>&1; then
        printf 'ADMIT'
    else
        printf 'REFUSE'
    fi
}

# ── The measured admit (pre-fix) and its refusal (post-fix) ─────────────────

@test "steering assignment PROJECT_ROOT= before the project launcher is refused" {
    [ "$(shell_admit "PROJECT_ROOT=$BATS_TEST_TMPDIR/x .agentic-framework/bin/fw git commit -m x")" = REFUSE ]
}

@test "steering assignment PROJECT_ROOT= is refused by the classifier too (parity)" {
    [ "$(classify_admit "PROJECT_ROOT=$BATS_TEST_TMPDIR/x .agentic-framework/bin/fw git commit -m x")" = REFUSE ]
}

@test "steering assignment PROJECT_ROOT= is refused by the budget gate at critical" {
    local json
    json=$(python3 -c 'import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' \
        "PROJECT_ROOT=$BATS_TEST_TMPDIR/x .agentic-framework/bin/fw git commit -m x" "$WORK")
    run bash -c "printf '%s' '$json' | PROJECT_ROOT='$WORK' bash '$GATE' >/dev/null 2>&1"
    [ "$status" -eq 2 ]
}

@test "hook at null focus refuses PROJECT_ROOT= steering prefix" {
    [ "$(hook_admit "PROJECT_ROOT=$BATS_TEST_TMPDIR/x .agentic-framework/bin/fw git commit -m \"TT-9: x\"")" = REFUSE ]
}

# ── Other steering names, and mixtures, stay refused ────────────────────────

@test "FRAMEWORK_ROOT, PATH and an unlisted FW_ name are refused as a prefix" {
    for c in "FRAMEWORK_ROOT=$BATS_TEST_TMPDIR/x git commit -m x" \
             "PATH=$BATS_TEST_TMPDIR/x git commit -m x" \
             "FW_ALLOW_X=1 git commit -m x" \
             "FOO=1 git commit -m x"; do
        [ "$(shell_admit "$c")" = REFUSE ] || { echo "admitted: $c"; false; }
    done
}

@test "an allow-listed name with any value other than 1 is refused" {
    [ "$(shell_admit "FW_SWITCH_FOCUS=0 git commit -m x")" = REFUSE ]
    [ "$(shell_admit "FW_ALLOW_STALE_INDEX=yes git commit -m x")" = REFUSE ]
}

@test "an allow-listed prefix does not launder a steering prefix alongside it" {
    [ "$(shell_admit "FW_SWITCH_FOCUS=1 PROJECT_ROOT=$BATS_TEST_TMPDIR/x git commit -m x")" = REFUSE ]
    [ "$(shell_admit "PROJECT_ROOT=$BATS_TEST_TMPDIR/x FW_SWITCH_FOCUS=1 git commit -m x")" = REFUSE ]
}

@test "a steering prefix placed after time is refused" {
    [ "$(shell_admit "time PROJECT_ROOT=$BATS_TEST_TMPDIR/x git commit -m x")" = REFUSE ]
}

# ── The documented commit-time bypass prefixes still admit ──────────────────

@test "documented prefixes admit as before, in the shell predicate" {
    for c in "FW_SWITCH_FOCUS=1 git commit -m x" \
             "FW_ALLOW_STALE_INDEX=1 git commit -m x" \
             "FW_ALLOW_MASTER_COMMIT=1 git commit -m x" \
             "FW_ALLOW_WORKTREE_CORPUS_COMMIT=1 git commit -m x" \
             "FW_SWITCH_FOCUS=1 time git commit -m x" \
             "time git commit -m x" \
             "git commit -m x"; do
        [ "$(shell_admit "$c")" = ADMIT ] || { echo "refused: $c"; false; }
    done
}

@test "FW_SWITCH_FOCUS=1 on the project's own launcher still admits" {
    [ "$(shell_admit "FW_SWITCH_FOCUS=1 .agentic-framework/bin/fw git commit -m x")" = ADMIT ]
}

@test "documented prefix FW_SWITCH_FOCUS=1 admitted through the null-focus hook" {
    [ "$(hook_admit 'FW_SWITCH_FOCUS=1 git commit -m "TT-9: x"')" = ADMIT ]
}

@test "documented prefix FW_ALLOW_STALE_INDEX=1 admitted through the null-focus hook" {
    [ "$(hook_admit 'FW_ALLOW_STALE_INDEX=1 git commit -m "TT-9: x"')" = ADMIT ]
}

@test "plain git commit is still admitted through the null-focus hook" {
    [ "$(hook_admit 'git commit -m "TT-9: x"')" = ADMIT ]
}
