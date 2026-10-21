#!/usr/bin/env bats
# T-4159: a task-file NAME anchored outside .tasks/ is not a guarded mention.
#
# check-human-ac-tick refused shell writes to docs/reports/T-NNNN-*.md (the C-001
# artefact convention) and .context/working/dispatch-T-NNNN-prompt.md, because
# MENTION_RE matched any `T-\d+…\.md` word. Writes to those files are allowed now;
# a bare task-file name (the `cd .tasks/active && … T-1.md` case), a `.tasks/` path
# and the tick ledger are still refused. Driven through the hook, as an agent meets it.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working" "$TEST_ROOT/docs/reports"
    printf -- '---\nid: T-1\n---\n### Human\n- [ ] [REVIEW] x\n' > "$TEST_ROOT/.tasks/active/T-1.md"
    : > "$TEST_ROOT/docs/reports/T-4123-x.md"
    : > "$TEST_ROOT/.context/working/dispatch-T-4123-prompt.md"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

assert_refused() {
    run_hook_bash "$1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

assert_allowed() {
    run_hook_bash "$1"
    [ "$status" -eq 0 ]
}

# ── allowed: the name is anchored in a directory that is not .tasks ──────────

@test "inline python writing docs/reports/T-NNNN-*.md is allowed" {
    assert_allowed "python3 -c 'open(\"docs/reports/T-4123-x.md\",\"w\").write(\"x\")'"
}

@test "python heredoc writing docs/reports/T-NNNN-*.md is allowed" {
    assert_allowed "python3 - <<'EOF'
open('docs/reports/T-4123-brief.md', 'w').write('x')
EOF"
}

@test "script handed a docs/reports/T-NNNN-*.md path is allowed" {
    assert_allowed "python3 tools/gen.py --out docs/reports/T-4123-x.md"
}

@test "inline python on .context/working/dispatch-T-NNNN-prompt.md is allowed" {
    assert_allowed "python3 -c 'p=\".context/working/dispatch-T-4123-prompt.md\"; open(p,\"a\")'"
}

# ── still refused ────────────────────────────────────────────────────────────

@test "sed -i on a .tasks/active task file is refused" {
    assert_refused "sed -i s/a/b/ .tasks/active/T-1.md"
}

@test "cd .tasks/active then sed -i on the bare name is refused" {
    assert_refused "cd .tasks/active && sed -i s/a/b/ T-1.md"
}

@test "inline python naming a bare task-file name is refused" {
    assert_refused "python3 -c 'open(\"T-1.md\",\"w\")'"
}

@test "inline python naming ./ or ../ before a task-file name is refused" {
    assert_refused "python3 -c 'open(\"./T-1.md\",\"w\")'"
    assert_refused "python3 -c 'open(\"docs/../T-1.md\",\"w\")'"
}

@test "write to the tick ledger is refused" {
    assert_refused "echo x > .context/working/human-ac-ticks.jsonl"
}
