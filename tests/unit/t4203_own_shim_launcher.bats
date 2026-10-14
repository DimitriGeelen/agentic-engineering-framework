#!/usr/bin/env bats
# T-4203 — a consumer's TRACKED `bin/fw` shim (a regular file that execs
# `.agentic-framework/bin/fw`, which CLAUDE.md tells the consumer's agent to type)
# is the project's own launcher. Before this fix, only FRAMEWORK_ROOT/bin/fw and
# PROJECT_ROOT/.agentic-framework/bin/fw counted, so `bin/fw git commit` from the
# project cwd was refused by the null-focus commit allowance and `bin/fw handover
# --commit` was refused at critical budget (055 field report item 7).
#
# Rule under test (safe-commands.sh _fw_project_shim_real, cmd_classify.py
# _project_shim_real): PROJECT_ROOT/bin/fw is own only when it is a REGULAR FILE
# whose realpath lies under realpath(PROJECT_ROOT). Refusals are pinned too: an
# escaping symlink, a directory, a planted absolute launcher, a relative launcher
# with the wrong payload cwd, no payload cwd, and an earlier `cd` in the command.
#
# Three surfaces are exercised: the shell predicate (is_commit_checkpoint_command),
# the Python classifier (lib/cmd_classify.py), and the shipped hooks end to end
# (budget-gate.sh at critical, check-active-task.sh at null focus).
# `! cmd` is inert in bats (L-628): every refusal is an explicit compare.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB_SC="$ROOT/agents/context/lib/safe-commands.sh"
    GATE="$ROOT/agents/context/budget-gate.sh"
    HOOK="$ROOT/agents/context/check-active-task.sh"
    export ROOT LIB_SC GATE HOOK

    WORK="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$WORK/.context/working" "$WORK/bin" "$WORK/.agentic-framework/bin" \
             "$WORK/.tasks/active" "$WORK/.tasks/completed" \
             "$BATS_TEST_TMPDIR/x/bin"
    printf '#!/bin/bash\nexec "$(dirname "$0")/../.agentic-framework/bin/fw" "$@"\n' > "$WORK/bin/fw"
    chmod +x "$WORK/bin/fw"
    printf '#!/bin/bash\necho planted\n' > "$BATS_TEST_TMPDIR/x/bin/fw"
    chmod +x "$BATS_TEST_TMPDIR/x/bin/fw"
    printf '{"level":"critical","tokens":290000,"timestamp":%s,"source":"test"}' \
        "$(date +%s)" > "$WORK/.context/working/.budget-status"
    printf 'current_task: null\n' > "$WORK/.context/working/focus.yaml"
    export WORK
}

# shell_admit <project-root> <payload-cwd> <command>
# Runs the shell allowance in a fresh bash, as the hook does: FRAMEWORK_ROOT is this
# checkout, PROJECT_ROOT the project under test. Prints ADMIT or REFUSE.
shell_admit() {
    FRAMEWORK_ROOT="$ROOT" PROJECT_ROOT="$1" _FW_PAYLOAD_CWD="$2" CMD="$3" bash -c '
        source "$LIB_SC"
        if is_commit_checkpoint_command "$CMD"; then echo ADMIT; else echo REFUSE; fi'
}

# classify_admit <project-root> <cwd> <command>
# The budget classifier, judged in-process against the same roots.
classify_admit() {
    python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
from cmd_classify import classify
ok, _ = classify(sys.argv[2], cwd=sys.argv[3], framework_root=sys.argv[4], project_root=sys.argv[5])
print("ADMIT" if ok else "REFUSE")' "$ROOT/lib" "$3" "$2" "$ROOT" "$1"
}

# gate <command> [payload-cwd] — the shipped budget gate, stdin JSON contract.
gate() {
    local json
    json=$(python3 -c 'import json,sys
d={"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}
if len(sys.argv)>2: d["cwd"]=sys.argv[2]
print(json.dumps(d))' "$@")
    output=$(printf '%s' "$json" | PROJECT_ROOT="$WORK" bash "$GATE" 2>&1)
    return $?
}

# hook_admit <command> <payload-cwd> — the shipped check-active-task.sh at null focus.
hook_admit() {
    local json
    json="$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "$2")"
    if printf '%s' "$json" | PROJECT_ROOT="$WORK" FRAMEWORK_ROOT="$ROOT" \
        CLAUDE_PROJECT_DIR="$WORK" bash "$HOOK" >/dev/null 2>&1; then
        printf 'ADMIT'
    else
        printf 'REFUSE'
    fi
}

# ── Positive cases: the project's own shim is admitted ──────────────────────

@test "shell: regular-file project shim, relative launcher, project cwd admitted" {
    [ "$(shell_admit "$WORK" "$WORK" 'bin/fw git commit -m x')" = ADMIT ]
}

@test "shell: regular-file project shim, absolute launcher admitted" {
    [ "$(shell_admit "$WORK" "$WORK" "$WORK/bin/fw git commit -m x")" = ADMIT ]
}

@test "shell: symlink inside the project to .agentic-framework/bin/fw admitted" {
    rm "$WORK/bin/fw"
    ln -s ../.agentic-framework/bin/fw "$WORK/bin/fw"
    [ "$(shell_admit "$WORK" "$WORK" 'bin/fw git commit -m x')" = ADMIT ]
}

@test "classifier: project shim admits bin/fw handover and bin/fw git commit" {
    [ "$(classify_admit "$WORK" "$WORK" 'bin/fw handover --commit')" = ADMIT ]
    [ "$(classify_admit "$WORK" "$WORK" 'bin/fw git commit -m x')" = ADMIT ]
}

@test "budget gate at critical: bin/fw handover --commit and bin/fw git commit admitted" {
    run gate "bin/fw handover --commit" "$WORK"
    [ "$status" -eq 0 ]
    run gate "bin/fw git commit -m x" "$WORK"
    [ "$status" -eq 0 ]
}

@test "hook at null focus: bin/fw git commit with project shim admitted" {
    [ "$(hook_admit 'bin/fw git commit -m "TT-9: x"' "$WORK")" = ADMIT ]
}

# ── Refusals: every case that the old rule also refused stays refused ───────

@test "shell: shim symlink escaping the project refused" {
    rm "$WORK/bin/fw"
    ln -s "$BATS_TEST_TMPDIR/x/bin/fw" "$WORK/bin/fw"
    [ "$(shell_admit "$WORK" "$WORK" 'bin/fw git commit -m x')" = REFUSE ]
}

@test "classifier: shim symlink escaping the project refused" {
    rm "$WORK/bin/fw"
    ln -s "$BATS_TEST_TMPDIR/x/bin/fw" "$WORK/bin/fw"
    [ "$(classify_admit "$WORK" "$WORK" 'bin/fw handover --commit')" = REFUSE ]
}

@test "shell: bin/fw that is a directory is not a launcher" {
    local d="$BATS_TEST_TMPDIR/dirshim"
    mkdir -p "$d/bin/fw" "$d/.context/working" "$d/.agentic-framework/bin"
    [ "$(shell_admit "$d" "$d" 'bin/fw git commit -m x')" = REFUSE ]
}

@test "classifier: bin/fw that is a directory is not a launcher" {
    local d="$BATS_TEST_TMPDIR/dirshim"
    mkdir -p "$d/bin/fw"
    [ "$(classify_admit "$d" "$d" 'bin/fw handover --commit')" = REFUSE ]
}

@test "shell: relative shim launcher with payload cwd elsewhere refused" {
    [ "$(shell_admit "$WORK" "$BATS_TEST_TMPDIR/x" 'bin/fw git commit -m x')" = REFUSE ]
}

@test "classifier: relative shim launcher with payload cwd elsewhere refused" {
    [ "$(classify_admit "$WORK" "$BATS_TEST_TMPDIR/x" 'bin/fw handover --commit')" = REFUSE ]
}

@test "shell: relative shim launcher with no payload cwd refused" {
    [ "$(shell_admit "$WORK" "" 'bin/fw git commit -m x')" = REFUSE ]
}

@test "classifier: relative shim launcher with no cwd refused" {
    [ "$(classify_admit "$WORK" "" 'bin/fw handover --commit')" = REFUSE ]
}

@test "shell: earlier cd to a planted directory refused" {
    [ "$(shell_admit "$WORK" "$WORK" "cd $BATS_TEST_TMPDIR/x && bin/fw git commit -m x")" = REFUSE ]
}

@test "classifier: earlier cd to a planted directory refused" {
    [ "$(classify_admit "$WORK" "$WORK" "cd $BATS_TEST_TMPDIR/x && bin/fw handover --commit")" = REFUSE ]
}

@test "shell: planted absolute launcher outside the project refused" {
    [ "$(shell_admit "$WORK" "$WORK" "$BATS_TEST_TMPDIR/x/bin/fw git commit -m x")" = REFUSE ]
}

@test "classifier: planted absolute launcher outside the project refused" {
    [ "$(classify_admit "$WORK" "$WORK" "$BATS_TEST_TMPDIR/x/bin/fw handover --commit")" = REFUSE ]
}

@test "budget gate at critical: planted absolute launcher still refused" {
    run gate "$BATS_TEST_TMPDIR/x/bin/fw handover --commit" "$WORK"
    [ "$status" -eq 2 ]
}

@test "budget gate at critical: escaping shim symlink still refused" {
    rm "$WORK/bin/fw"
    ln -s "$BATS_TEST_TMPDIR/x/bin/fw" "$WORK/bin/fw"
    run gate "bin/fw handover --commit" "$WORK"
    [ "$status" -eq 2 ]
}
