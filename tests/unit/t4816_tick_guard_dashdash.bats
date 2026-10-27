#!/usr/bin/env bats
# T-4816: the Human-AC tick guard (check-human-ac-tick, via lib/shell_write_scan.py)
# refused the read-only `git log --oneline -1 -- "$f"` as "an expanded argument may be
# --output". git's setup_revisions() cuts argv at the first bare `--`, so every word
# after it is a pathspec and cannot become --output. Field report: ring20 be.37 field
# test C addendum (msg 1df20c21).
#
# Words BEFORE the `--` are still judged, and a `--` that a value-taking log option
# (-L, --decorate-refs[-exclude]) consumes as its value does not end the options.
# An unresolvable expansion is refused only when the command names a guarded path.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-human-ac-tick.sh"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.context/working"
    printf -- '---\nid: T-9999\n---\n### Human\n- [ ] [REVIEW] x\n' > "$TEST_ROOT/.tasks/active/T-9999-test.md"
    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_HUMAN_AC_TICK AI_AGENT
}

teardown() { rm -rf "$TEST_ROOT" 2>/dev/null; }

run_hook_bash() {
    local input
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$TEST_ROOT")
    run bash "$HOOK_SH" <<< "$input"
}

assert_allowed() {
    run_hook_bash "$1"
    echo "cmd: $1"; echo "$output"
    [ "$status" -eq 0 ]
}

assert_refused() {
    run_hook_bash "$1"
    echo "cmd: $1"; echo "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SHELL WRITE TO A TASK FILE BLOCKED"* ]]
}

@test "T-4816: field repro — git log -- \"\$f\" on a .tasks path is allowed" {
    assert_allowed 'f=$(ls .tasks/active/T-*.md | head -1); git log --oneline -1 -- "$f"'
    assert_allowed 'git log --oneline -1 -- "$f"'
    assert_allowed 'git diff HEAD -- $f .tasks/active/T-9999-test.md'
    assert_allowed 'git show --stat HEAD -- "${f}"'
    assert_allowed "git log '--' \"\$f\" .tasks/active/T-9999-test.md"
    # after --, a literal --output=… is a pathspec (git writes nothing)
    assert_allowed 'git log -- --output=.tasks/active/T-9999-test.md'
}

@test "T-4816: an expansion BEFORE -- is still refused" {
    assert_refused 'git show --stat $c -- .tasks/active/T-9999-test.md'
    assert_refused 'git diff $c~1 HEAD .tasks/active/T-9999-test.md'
    assert_refused 'git log $o -- .tasks/active/T-9999-test.md'
}

@test "T-4816: a real --output to a .tasks path is still refused, before --" {
    assert_refused 'git diff --output=.tasks/active/T-9999-test.md HEAD -- x'
    assert_refused 'git log -p --output .tasks/active/T-9999-test.md -- "$f"'
}

@test "T-4816: a -- consumed as the value of -L / --decorate-refs does not end options" {
    assert_refused 'git log -L -- $o .tasks/active/T-9999-test.md'
    assert_refused 'git log --decorate-refs -- $o .tasks/active/T-9999-test.md'
}
