#!/usr/bin/env bats
# T-4196 — fw handover keeps pushing by default (operator ruling 2026-10-13, 1a,
# on 832 OBS-413) but gains an explicit, logged --no-push opt-out, and says what
# it is about to push (branch, commit count, remotes) BEFORE pushing.
#
# Every test drives the real agents/handover/handover.sh --checkpoint (the
# shortest path that commits + pushes) against a throwaway repo with a bare
# remote under $BATS_TEST_TMPDIR. The remote's ref is the assertion — not the
# script's own output — so "pushed" and "did not push" are both observed.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

setup() {
    REMOTE="$BATS_TEST_TMPDIR/remote.git"
    REPO="$BATS_TEST_TMPDIR/p"
    git init -q --bare "$REMOTE"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed" "$REPO/.context/working"
    git -C "$REPO" init -q -b main .
    git -C "$REPO" config user.email "t4196@example.invalid"
    git -C "$REPO" config user.name "T-4196 fixture"
    git -C "$REPO" config core.hooksPath /dev/null
    printf -- '---\nid: T-0001\nname: handover fixture\nstatus: started-work\n---\n' \
        > "$REPO/.tasks/active/T-0001-session-handover-fixture.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "T-0001: base"
    git -C "$REPO" remote add origin "$REMOTE"
    git -C "$REPO" push -q origin main
    # Two local commits the remote does not have yet.
    echo a > "$REPO/a"; git -C "$REPO" add a; git -C "$REPO" commit -qm "T-0001: a"
    echo b > "$REPO/b"; git -C "$REPO" add b; git -C "$REPO" commit -qm "T-0001: b"
    export REPO REMOTE
}

_handover() {
    run env PROJECT_ROOT="$REPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_HANDOVER_PUSH_TIMEOUT=60 NO_COLOR=1 \
        bash "$HANDOVER" --checkpoint --task T-0001 "$@"
}

_remote_head() { git -C "$REMOTE" rev-parse refs/heads/main; }

@test "T-4196: default checkpoint still pushes, and announces branch/count/remotes first" {
    _handover
    [ "$status" -eq 0 ]
    # Pushed: the remote carries local HEAD.
    [ "$(_remote_head)" = "$(git -C "$REPO" rev-parse HEAD)" ]
    # Announced: branch, number of commits (2 + the checkpoint commit = 3), remotes.
    [[ "$output" == *"Pushing branch main: 3 commit(s) not yet on origin -> remotes: origin"* ]]
    # And the announcement precedes the push result.
    local pre="${output%%Pushed to origin*}"
    [[ "$pre" == *"Pushing branch main:"* ]]
}

@test "T-4196: --no-push commits but leaves the remote untouched" {
    local before; before="$(_remote_head)"
    _handover --no-push
    [ "$status" -eq 0 ]
    [ "$(_remote_head)" = "$before" ]
    # The checkpoint commit itself was made locally.
    [[ "$(git -C "$REPO" log -1 --format=%s)" == *"Checkpoint handover"* ]]
    [[ "$output" == *"--no-push"* ]]
    [[ "$output" == *"3 commit(s)"* ]]
}

@test "T-4196: --no-push is logged Tier-2 to the gate-bypass log" {
    _handover --no-push
    [ "$status" -eq 0 ]
    local log="$REPO/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "flag: '--no-push'" "$log"
    grep -q "caller: 'handover.sh'" "$log"
}

@test "T-4196: --help documents --no-push" {
    run bash "$HANDOVER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-push"* ]]
}
