#!/usr/bin/env bats
#
# T-4859: ring20-dashboard security review of be.46 (msg 72cf84a0, finding 3).
# lib/shell_write_scan.py:_mentions counted a relative `…/T-NNNN*.md` word as a guarded
# mention only when its directory normalised to `.`/`..`. A target the text CAN resolve
# (cwd known) was already refused, so `cd .tasks && echo x > active/T-1.md` never was a
# hole. The hole was everything gated on the MENTION instead: inline code, unresolvable
# targets, run from a cwd inside .tasks (the Bash tool keeps cwd between calls):
#
#     cwd=.tasks:  python3 -c 'open("active/T-1-x.md","w").write("x")'
#
# Fix: a cwd inside .tasks is an implicit mention, and a relative T-NNNN*.md word whose
# prefix is not provably outside .tasks from the known cwd counts as a mention.
# Every case goes through the real hook under CLAUDECODE=1 against a temp project.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/docs/reports" "$TEST_ROOT/.context/working"
    printf -- '---\nid: T-1\n---\n### Human\n- [ ] [REVIEW] x\n' > "$TEST_ROOT/.tasks/active/T-1-x.md"
    : > "$TEST_ROOT/docs/reports/T-4123-x.md"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() { rm -rf "$TEST_ROOT" 2>/dev/null; }

# run_hook_bash CMD [CWD relative to TEST_ROOT]
run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT${2:+/$2}")
    run bash "$HOOK_SH" <<< "$input"
}

assert_refused() {
    run_hook_bash "$@"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

assert_allowed() {
    run_hook_bash "$@"
    [ "$status" -eq 0 ]
}

# ── the reviewer's shapes with a resolvable target (refused before the fix too) ──

@test "cd .tasks then redirect to active/T-NNNN.md is refused" {
    assert_refused "cd .tasks && echo x > active/T-1-x.md"
}

@test "cd .tasks/active then sed -i on the bare name is refused" {
    assert_refused "cd .tasks/active && sed -i s/a/b/ T-1-x.md"
}

@test "cwd .tasks: redirect to active/T-NNNN.md is refused" {
    assert_refused "echo x > active/T-1-x.md" ".tasks"
}

# ── the real hole: mention-gated writes with a non-dot relative prefix ─────────

@test "cwd .tasks: inline python writing active/T-NNNN.md is refused" {
    assert_refused "python3 -c 'open(\"active/T-1-x.md\",\"w\").write(\"x\")'" ".tasks"
}

@test "cwd .tasks/active: sed -i on an unresolvable target is refused" {
    assert_refused 'sed -i s/a/b/ "$F"' ".tasks/active"
}

@test "cwd .tasks/active: inline perl naming no task file is refused" {
    assert_refused "perl -e 'open(F,\">>x.md\")'" ".tasks/active"
}

@test "cwd project root: inline python on sub/T-NNNN.md, sub a symlink into .tasks, is refused" {
    ln -s .tasks/active "$TEST_ROOT/sub"
    assert_refused "python3 -c 'open(\"sub/T-1-x.md\",\"w\")'"
}

@test "cwd project root: cd into a symlink to .tasks then sed -i on \$F is refused" {
    ln -s .tasks "$TEST_ROOT/t"
    assert_refused 'cd t/active && sed -i s/a/b/ "$F"'
}

@test "inline python on \$D/T-NNNN.md (directory built at run time) is refused" {
    assert_refused "sed -i s/a/b/ \"\$D/T-1-x.md\""
}

@test "cwd project root: inline python on plain-dir sub/T-NNNN.md passes (provably outside)" {
    mkdir -p "$TEST_ROOT/sub"
    assert_allowed "python3 -c 'open(\"sub/T-1-x.md\",\"w\")'"
}

@test "cd /abs/root && inline python on docs/reports/T-NNNN-*.md passes" {
    assert_allowed "cd $TEST_ROOT && python3 -c 'open(\"docs/reports/T-4123-x.md\",\"w\")'"
}

@test "cwd .tasks: sed -i on \$_ after naming active/T-NNNN.md is refused" {
    assert_refused 'ls active/T-1-x.md; sed -i s/a/b/ "$_"' ".tasks"
}

# ── still allowed ──────────────────────────────────────────────────────────────

@test "cwd inside .tasks: cat / grep / sed -n / head on a task file pass" {
    assert_allowed "cat T-1-x.md" ".tasks/active"
    assert_allowed "grep -n Human T-1-x.md" ".tasks/active"
    assert_allowed "sed -n 1,5p T-1-x.md" ".tasks/active"
    assert_allowed "head -3 active/T-1-x.md" ".tasks"
}

@test "C-001 artefact docs/reports/T-NNNN-*.md stays writable from the root" {
    assert_allowed "python3 -c 'open(\"docs/reports/T-4123-x.md\",\"w\").write(\"x\")'"
    assert_allowed "echo x > docs/reports/T-4123-x.md"
}

@test "dispatch prompt .context/working/dispatch-T-NNNN-prompt.md stays writable" {
    assert_allowed "python3 -c 'open(\".context/working/dispatch-T-4123-prompt.md\",\"a\")'"
}

@test "cwd outside .tasks: inline code with no task-file word passes" {
    assert_allowed "python3 -c 'print(1)'" "docs/reports"
}
