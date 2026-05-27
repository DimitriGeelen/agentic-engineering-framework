#!/usr/bin/env bats
# T-2058 — Pin audit.sh revert-chain suppression. Origin: 3 historical commits
# (b5b52783, 3e8f23c8, 1fe4aace) referencing task files T-1906/T-1907 that were
# deliberately deleted via T-1687's revert chain ("revert T-1906/T-1907
# fake-prevention chain"). Audit was emitting a "references non-existent task"
# WARN for each of the 3 commits even though the orphan was intentional.
#
# Rule: when a commit references a missing task file, audit looks for a later
# commit message matching /revert.*T-NNNN/ (case-insensitive). If found, the
# WARN is suppressed — the deletion was an explicit decision in history, not a
# governance gap.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-revert-chain"
    mkdir -p "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/audits" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"

    # Stand up a tiny git repo with controlled history
    git -C "$TEST_PROJECT" init -q
    git -C "$TEST_PROJECT" config user.email test@test
    git -C "$TEST_PROJECT" config user.name test
    cd "$TEST_PROJECT"
    echo seed > seed.txt
    git -C "$TEST_PROJECT" add seed.txt
    git -C "$TEST_PROJECT" commit -q -m "T-001: seed"
    # Reference task file for T-001 (so seed commit is not itself an orphan)
    cat > .tasks/active/T-001-seed.md <<'EOF'
---
id: T-001
name: seed
status: started-work
---
EOF
    git -C "$TEST_PROJECT" add .tasks/active/T-001-seed.md
    git -C "$TEST_PROJECT" commit -q -m "T-001: register task file"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_traceability_audit() {
    run "$FRAMEWORK_ROOT/bin/fw" audit --section traceability
}

@test "genuine orphan reference still WARNs" {
    # Commit references T-999 but task file never existed and no revert commit
    echo body > genuine.txt
    git -C "$TEST_PROJECT" add genuine.txt
    git -C "$TEST_PROJECT" commit -q -m "T-999: genuine orphan reference"

    _run_traceability_audit
    [[ "$output" == *"references non-existent task T-999"* ]]
}

@test "revert-chain orphan is suppressed" {
    # Commit references T-888 and a LATER commit explicitly reverts it
    echo body > rc.txt
    git -C "$TEST_PROJECT" add rc.txt
    git -C "$TEST_PROJECT" commit -q -m "T-888: feature about to be reverted"
    echo deleted > deleted.txt
    git -C "$TEST_PROJECT" add deleted.txt
    git -C "$TEST_PROJECT" commit -q -m "T-001: revert T-888 fake-prevention chain"

    _run_traceability_audit
    [[ "$output" != *"references non-existent task T-888"* ]]
}

@test "both classes co-existing — only the revert-chain one is suppressed" {
    # Genuine orphan
    echo body > g.txt
    git -C "$TEST_PROJECT" add g.txt
    git -C "$TEST_PROJECT" commit -q -m "T-777: another genuine orphan"
    # Reverted task
    echo body > r.txt
    git -C "$TEST_PROJECT" add r.txt
    git -C "$TEST_PROJECT" commit -q -m "T-666: task that gets reverted"
    echo gone > gone.txt
    git -C "$TEST_PROJECT" add gone.txt
    git -C "$TEST_PROJECT" commit -q -m "T-001: revert T-666 spike"

    _run_traceability_audit
    [[ "$output" == *"references non-existent task T-777"* ]]
    [[ "$output" != *"references non-existent task T-666"* ]]
}

@test "T-NNNN appearing inside an unrelated commit subject is not a false revert" {
    # A non-revert commit that happens to mention T-555 must NOT suppress the WARN
    echo body > x.txt
    git -C "$TEST_PROJECT" add x.txt
    git -C "$TEST_PROJECT" commit -q -m "T-555: original work"
    echo body > y.txt
    git -C "$TEST_PROJECT" add y.txt
    # Mentions T-555 but does NOT contain the word 'revert' near it
    git -C "$TEST_PROJECT" commit -q -m "T-001: follow-up referencing T-555 by name"

    _run_traceability_audit
    [[ "$output" == *"references non-existent task T-555"* ]]
}
