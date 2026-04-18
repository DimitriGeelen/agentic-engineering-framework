#!/usr/bin/env bats
# Regression test for T-1317: verification gate must cd to PROJECT_ROOT
# before eval'ing commands so relative paths resolve correctly regardless
# of caller CWD (Watchtower launches from FRAMEWORK_ROOT).
#
# Origin: pickup from email-archive (T-1044) via T-1316 inception.

load ../test_helper

@test "verification gate runs verification commands from PROJECT_ROOT cwd" {
    PROJECT="$(create_test_project)"
    # Sentinel file at PROJECT_ROOT — verification will use a relative path.
    echo "sentinel" > "$PROJECT/sentinel.txt"

    # Build a task with a relative-path verification command.
    TASK="$(create_test_task "$PROJECT" T-998 verify-cwd)"
    # Rewrite Verification block with a relative-path command and a trailing
    # `## Decisions` heading so the parser bounds the section correctly.
    python3 - "$TASK" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace(
    '## Verification\n\necho "ok"',
    '## Verification\n\ntest -f sentinel.txt\n\n## Decisions\n\nNone.',
)
p.write_text(text)
PY
    # Pre-check the AC.
    sed -i 's/- \[ \] Test criterion/- [x] Test criterion/' "$TASK"

    # Run update-task from a directory that is NOT PROJECT_ROOT to prove the
    # fix: pre-bug, this would have searched for sentinel.txt in the caller's
    # CWD. Post-fix, the verification subshell cds to PROJECT_ROOT first.
    cd /tmp
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-998 --status work-completed
    [ "$status" = 0 ]
    [[ "$output" == *"PASS: test -f sentinel.txt"* ]]
    [[ "$output" == *"Verification: 1/1 passed"* ]]
}

@test "verification gate fails when relative-path target does not exist (negative)" {
    PROJECT="$(create_test_project)"
    TASK="$(create_test_task "$PROJECT" T-997 missing-file)"
    python3 - "$TASK" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace(
    '## Verification\n\necho "ok"',
    '## Verification\n\ntest -f does-not-exist.txt\n\n## Decisions\n\nNone.',
)
p.write_text(text)
PY
    sed -i 's/- \[ \] Test criterion/- [x] Test criterion/' "$TASK"

    cd /tmp
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-997 --status work-completed
    # Should NOT exit 0 — verification gate should block.
    [ "$status" != 0 ]
    [[ "$output" == *"FAIL: test -f does-not-exist.txt"* ]]
}
