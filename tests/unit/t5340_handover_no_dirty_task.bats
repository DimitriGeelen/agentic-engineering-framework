#!/usr/bin/env bats
# T-5340 — the handover auto-commit must not leave the handover task file dirty.
#
# commit.sh bumps `last_update:` AFTER a pathspec-scoped commit (T-3090 order),
# so the bump is never in the commit and the task file stays modified. The
# handover commits with a pathspec, so every handover left its task dirty.
# Fix: FW_COMMIT_SKIP_TASK_BUMP=1 skips that bump; handover.sh sets it on its
# own commit only.
#
# Hermetic: throwaway repos under $BATS_TEST_TMPDIR, hooks off, no push.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"
HANDOVER_SH="$FRAMEWORK_ROOT/agents/handover/handover.sh"
TASK_REL=".tasks/active/T-5340-fixture.md"

setup() {
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/.tasks/active" "$REPO/.context/handovers"
    git -C "$REPO" init -q .
    git -C "$REPO" config user.email "test@example.invalid"
    git -C "$REPO" config user.name "T-5340 fixture"
    git -C "$REPO" config core.hooksPath /dev/null
    printf -- '---\nid: T-5340\nstatus: started-work\nlast_update: 2000-01-01T00:00:00Z\n---\n# T-5340\n' \
        > "$REPO/$TASK_REL"
    echo base > "$REPO/.context/handovers/LATEST.md"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "T-0000: base"
    echo "new handover" > "$REPO/.context/handovers/LATEST.md"
    export REPO
}

_task_status() {
    git -C "$REPO" status --porcelain -- "$TASK_REL"
}

@test "opt-out: pathspec commit leaves the task file clean" {
    run env PROJECT_ROOT="$REPO" TASKS_DIR="$REPO/.tasks" FW_COMMIT_SKIP_TASK_BUMP=1 \
        bash "$GIT_AGENT" commit -m "T-5340: handover" -- .context/handovers/LATEST.md
    [ "$status" -eq 0 ]
    # positive control: the intended file IS in the commit
    [ "$(git -C "$REPO" show --pretty=format: --name-only HEAD | grep -v '^$')" = ".context/handovers/LATEST.md" ]
    [ -z "$(_task_status)" ]
    grep -q '^last_update: 2000-01-01T00:00:00Z$' "$REPO/$TASK_REL"
}

@test "control: without the opt-out the task file is bumped as before" {
    run env -u FW_COMMIT_SKIP_TASK_BUMP PROJECT_ROOT="$REPO" TASKS_DIR="$REPO/.tasks" \
        bash "$GIT_AGENT" commit -m "T-5340: handover" -- .context/handovers/LATEST.md
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" show --pretty=format: --name-only HEAD | grep -v '^$')" = ".context/handovers/LATEST.md" ]
    [ -n "$(_task_status)" ]
    run grep -q '^last_update: 2000-01-01T00:00:00Z$' "$REPO/$TASK_REL"
    [ "$status" -ne 0 ]
}

@test "handover call site: _commit_handover_files sets the opt-out and leaves the task clean" {
    # Extract the real function from handover.sh and drive it against the sandbox.
    fn="$BATS_TEST_TMPDIR/fn.sh"
    awk '/^_commit_handover_files\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$HANDOVER_SH" > "$fn"
    grep -q 'FW_COMMIT_SKIP_TASK_BUMP=1 "\$GIT_AGENT" commit' "$fn"
    run bash -c '
        RED= NC=
        PROJECT_ROOT="$1"; HANDOVER_DIR="$1/.context/handovers"; GIT_AGENT="$2"
        export TASKS_DIR="$1/.tasks"
        unset FW_COMMIT_SKIP_TASK_BUMP
        source "$3"
        cd "$1"
        _commit_handover_files "T-5340: Session handover" .context/handovers/LATEST.md
        echo "STATUS=$HANDOVER_COMMIT_STATUS"
    ' _ "$REPO" "$GIT_AGENT" "$fn"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STATUS=ok"* ]]
    [ "$(git -C "$REPO" log -1 --pretty=%s)" = "T-5340: Session handover" ]
    [ -z "$(_task_status)" ]
}
