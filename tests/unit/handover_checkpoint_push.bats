#!/usr/bin/env bats
# T-2588 — `handover.sh --checkpoint` must push the checkpoint commit, not
# just commit it locally. Checkpoint commits accumulate mid-session; if the
# session dies before a later normal handover, or the budget gate blocks a
# subsequent push (T-2587), the checkpoint commit — the exact state a
# checkpoint exists to protect — was stranded unpushed.

load ../test_helper

HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT

    BARE_REMOTE="$TEST_TEMP_DIR/remote.git"
    git init -q --bare "$BARE_REMOTE"

    PROJECT_ROOT="$TEST_TEMP_DIR/project"
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/handovers" "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"

    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "t2588@test.local"
    git -C "$PROJECT_ROOT" config user.name "T-2588 test"
    git -C "$PROJECT_ROOT" remote add origin "$BARE_REMOTE"
    echo "init" > "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" -c commit.gpgsign=false commit -q -m "init"
    git -C "$PROJECT_ROOT" push -q origin HEAD:refs/heads/master
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariant: checkpoint auto-commit branch calls the push helper ----

@test "handover.sh checkpoint auto-commit branch calls _push_to_remotes (T-2588)" {
    awk '/CHECKPOINT_MODE.*=.*true.*\]/{flag=1} flag; /^exit 0$/{if(flag){exit}}' "$HANDOVER" \
        | grep -q '_push_to_remotes'
}

@test "handover.sh defines a shared _push_to_remotes function (T-2588)" {
    grep -q '^_push_to_remotes()' "$HANDOVER"
}

@test "handover.sh parses (bash -n) (T-2588)" {
    bash -n "$HANDOVER"
}

# ---- Behavioural: checkpoint leaves zero unpushed commits ----

@test "checkpoint commit is pushed to origin — remote HEAD matches local HEAD (T-2588)" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$HANDOVER' --checkpoint --task T-000 --session S-TEST-2588"
    [ "$status" -eq 0 ]

    local_head=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    remote_head=$(git -C "$BARE_REMOTE" rev-parse master 2>/dev/null || git -C "$BARE_REMOTE" rev-parse HEAD)
    [ "$local_head" = "$remote_head" ]
}

@test "checkpoint push reports success to output (T-2588)" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$HANDOVER' --checkpoint --task T-000 --session S-TEST-2588B"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pushing to remotes"* ]]
    [[ "$output" == *"Pushed to origin"* ]]
}
