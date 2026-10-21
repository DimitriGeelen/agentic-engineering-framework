#!/usr/bin/env bats
# T-3798 — handover.sh must not commit or push when HANDOVER_DIR lies outside
# the git repo at PROJECT_ROOT. Origin: handover_digest.bats pointed
# HANDOVER_DIR at a fixture but left PROJECT_ROOT on the real repo; the commit
# failed (pathspec outside the repo) and _push_to_remotes still pushed the real
# repo's HEAD to origin, twice, from inside the unit suite.
#
# Each behavioural leg leaves one LOCAL, UNPUSHED commit in the fixture repo, so
# a push of any kind is visible as origin's master moving.

load ../test_helper

HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1 NTFY_ENABLED=0
    export FRAMEWORK_ROOT

    BARE_REMOTE="$TEST_TEMP_DIR/remote.git"
    git init -q --bare "$BARE_REMOTE"

    PROJECT_ROOT="$TEST_TEMP_DIR/project"
    guard_project_root
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/handovers" "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"

    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "t3798@test.local"
    git -C "$PROJECT_ROOT" config user.name "T-3798 test"
    git -C "$PROJECT_ROOT" remote add origin "$BARE_REMOTE"
    echo "init" > "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" -c commit.gpgsign=false commit -q -m "init"
    git -C "$PROJECT_ROOT" push -q origin HEAD:refs/heads/master

    # The unpushed commit a stray push would publish.
    echo "local" > "$PROJECT_ROOT/local.txt"
    git -C "$PROJECT_ROOT" add local.txt
    git -C "$PROJECT_ROOT" -c commit.gpgsign=false commit -q -m "T-000: local only"

    REMOTE_BEFORE=$(git -C "$BARE_REMOTE" rev-parse master)
    OUTSIDE_DIR="$TEST_TEMP_DIR/outside-handovers"
    mkdir -p "$OUTSIDE_DIR"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "normal handover with HANDOVER_DIR outside PROJECT_ROOT pushes nothing (T-3798)" {
    run bash -c "HANDOVER_DIR='$OUTSIDE_DIR' '$HANDOVER' --session S-T3798-A"
    [ "$status" -eq 0 ]
    [ "$(git -C "$BARE_REMOTE" rev-parse master)" = "$REMOTE_BEFORE" ]
    [[ "$output" == *"Skipping auto-commit and push (T-3798)"* ]]
    [ -f "$OUTSIDE_DIR/S-T3798-A.md" ]
}

@test "checkpoint handover with HANDOVER_DIR outside PROJECT_ROOT pushes nothing (T-3798)" {
    run bash -c "HANDOVER_DIR='$OUTSIDE_DIR' '$HANDOVER' --checkpoint --task T-000 --session S-T3798-B"
    [ "$status" -eq 0 ]
    [ "$(git -C "$BARE_REMOTE" rev-parse master)" = "$REMOTE_BEFORE" ]
    [[ "$output" == *"Skipping auto-commit and push (T-3798)"* ]]
}

@test "control: HANDOVER_DIR inside PROJECT_ROOT still commits and pushes (T-3798)" {
    run bash -c "'$HANDOVER' --session S-T3798-C"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Skipping auto-commit and push"* ]]
    [ "$(git -C "$BARE_REMOTE" rev-parse master)" = "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" ]
    [ "$(git -C "$BARE_REMOTE" rev-parse master)" != "$REMOTE_BEFORE" ]
}
