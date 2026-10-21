#!/usr/bin/env bats
# Unit tests for agents/handover/handover.sh
# Origin: T-923, T-944 (isolation fix)
#
# T-4522: every test runs handover.sh against a throwaway fixture project, not
# the framework repo. Against the live repo each run walks ~3,600 task files
# with a fork per file (~75 s on a many-core host); eight runs hung the file to
# the 900 s cap on a clean 4-vCPU machine, and each one also rewrote the shared
# checkout's .context/handovers/LATEST.md under any session using it. Each call
# is bounded by `timeout` so a regression reads as a failure, not a hang.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"
HANDOVER_TIMEOUT="${HANDOVER_TEST_TIMEOUT:-120}"

setup() {
    REPO="$BATS_TEST_TMPDIR/proj"
    HANDOVER_DIR="$REPO/.context/handovers"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed" \
        "$REPO/.context/working" "$REPO/.context/project" "$HANDOVER_DIR"
    git -C "$REPO" init -q .
    git -C "$REPO" config user.email "test@example.invalid"
    git -C "$REPO" config user.name "T-4522 fixture"
    git -C "$REPO" config core.hooksPath /dev/null
    printf -- '---\nid: T-012\nname: "Handover fixture task"\nstatus: started-work\nworkflow_type: build\nhorizon: now\nowner: agent\n---\n# T-012\n' \
        > "$REPO/.tasks/active/T-012-handover-fixture.md"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "T-012: fixture base"

    LIVE_LATEST="$(readlink "$FRAMEWORK_ROOT/.context/handovers/LATEST.md" 2>/dev/null || true)"
    export REPO HANDOVER_DIR LIVE_LATEST
}

teardown() {
    # The point of the fixture: the framework's own handover pointer is untouched.
    [ "$(readlink "$FRAMEWORK_ROOT/.context/handovers/LATEST.md" 2>/dev/null || true)" = "$LIVE_LATEST" ]
}

# _handover ARGS... — run handover.sh against the fixture, bounded.
_handover() {
    run env PROJECT_ROOT="$REPO" timeout "$HANDOVER_TIMEOUT" "$HANDOVER" "$@" </dev/null
    if [ "$status" -eq 124 ]; then
        echo "handover.sh $* exceeded ${HANDOVER_TIMEOUT}s on a one-task fixture (T-4522)" >&2
        return 1
    fi
}

# --- Help ---

@test "handover --help shows usage" {
    run "$HANDOVER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"handover"* ]]
    [[ "$output" == *"--commit"* ]]
    [[ "$output" == *"--checkpoint"* ]]
}

@test "handover -h shows usage" {
    run "$HANDOVER" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"handover"* ]]
}

# --- Handover generation ---

@test "handover generates session document" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Handover"* ]]
    [[ "$output" == *"Session"* ]] || [[ "$output" == *"S-"* ]]
}

@test "handover creates file in the project's handovers directory" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    [ -L "$HANDOVER_DIR/LATEST.md" ]
    [ -f "$HANDOVER_DIR/LATEST.md" ]
}

@test "handover output mentions session ID" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"S-"* ]]
}

@test "handover generates valid frontmatter" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    head -1 "$HANDOVER_DIR/LATEST.md" | grep -q "^---"
}

@test "handover includes Where We Are section" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    grep -q "## Where We Are" "$HANDOVER_DIR/LATEST.md"
}

@test "handover includes Suggested First Action" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    grep -q "## Suggested First Action" "$HANDOVER_DIR/LATEST.md"
}

# --- Task flag ---

@test "handover accepts --task flag" {
    _handover --no-commit --task T-012
    [ "$status" -eq 0 ]
}

# --- Checkpoint mode ---

@test "handover --checkpoint does not replace LATEST.md" {
    _handover --no-commit
    [ "$status" -eq 0 ]
    local before
    before="$(readlink "$HANDOVER_DIR/LATEST.md")"

    _handover --checkpoint --no-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Checkpoint"* ]] || [[ "$output" == *"checkpoint"* ]]
    [ "$(readlink "$HANDOVER_DIR/LATEST.md")" = "$before" ]
}
