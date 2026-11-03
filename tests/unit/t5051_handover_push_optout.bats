#!/usr/bin/env bats
# T-5051 — project-level opt-out for the handover push.
#
# On 050-email-archive a push to the remote deploys production, and pre-compact.sh
# always runs handover.sh --commit (it cannot pass --no-push). HANDOVER_PUSH=0
# (env FW_HANDOVER_PUSH=0 or .framework.yaml) makes _push_to_remotes, the only
# push site on every --commit path, commit-only with one plain line.

load ../test_helper

HANDOVER_SH=""

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
    HANDOVER_SH="$FRAMEWORK_ROOT/agents/handover/handover.sh"
    unset FW_HANDOVER_PUSH

    git init -q --bare "$TEST_TEMP_DIR/remote.git"
    git init -q "$TEST_TEMP_DIR/repo"
    git -C "$TEST_TEMP_DIR/repo" config user.email t@example.invalid
    git -C "$TEST_TEMP_DIR/repo" config user.name t
    git -C "$TEST_TEMP_DIR/repo" config core.hooksPath /dev/null
    echo a > "$TEST_TEMP_DIR/repo/a.txt"
    git -C "$TEST_TEMP_DIR/repo" add a.txt
    git -C "$TEST_TEMP_DIR/repo" commit -q -m "T-0000: seed"
    git -C "$TEST_TEMP_DIR/repo" remote add origin "$TEST_TEMP_DIR/remote.git"

    # Extract the two push functions from handover.sh and run them against the
    # temp repo — the real code, not a copy of its predicate.
    awk '/^_push_summary\(\) \{/,/^}/' "$HANDOVER_SH" > "$TEST_TEMP_DIR/fns.sh"
    awk '/^_push_to_remotes\(\) \{/,/^}/' "$HANDOVER_SH" >> "$TEST_TEMP_DIR/fns.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_push() {
    # $@: extra env assignments
    run env "$@" PROJECT_ROOT="$TEST_TEMP_DIR/repo" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_HANDOVER_PUSH_TIMEOUT=30 NO_PUSH=false bash -c '
            source "$FRAMEWORK_ROOT/lib/config.sh"
            source "'"$TEST_TEMP_DIR"'/fns.sh"
            _push_to_remotes'
}

_remote_heads() {
    git -C "$TEST_TEMP_DIR/remote.git" for-each-ref --format='%(refname)' refs/heads | wc -l
}

@test "HANDOVER_PUSH is registered in lib/config.sh with default 1 (T-5051)" {
    grep -q '"HANDOVER_PUSH|1|' "$FRAMEWORK_ROOT/lib/config.sh"
}

@test "FW_HANDOVER_PUSH=0: nothing reaches the remote, one skip line printed (T-5051)" {
    _run_push FW_HANDOVER_PUSH=0
    [ "$status" -eq 0 ]
    [[ "$output" == *"Push skipped: HANDOVER_PUSH=0 for this project — committed locally only (T-5051)"* ]]
    [[ "$output" != *"Pushing to remotes"* ]]
    [ "$(grep -c 'Push skipped' <<<"$output")" -eq 1 ]
    [ "$(_remote_heads)" -eq 0 ]
}

@test ".framework.yaml HANDOVER_PUSH: 0 also skips the push (T-5051)" {
    echo "HANDOVER_PUSH: 0" > "$TEST_TEMP_DIR/repo/.framework.yaml"
    _run_push
    [ "$status" -eq 0 ]
    [[ "$output" == *"Push skipped: HANDOVER_PUSH=0"* ]]
    [ "$(_remote_heads)" -eq 0 ]
}

@test "key unset: push as today, remote receives HEAD (T-5051 control)" {
    _run_push
    [ "$status" -eq 0 ]
    [[ "$output" != *"Push skipped"* ]]
    [[ "$output" == *"Pushed to origin"* ]]
    [ "$(_remote_heads)" -eq 1 ]
    [ "$(git -C "$TEST_TEMP_DIR/remote.git" rev-parse HEAD 2>/dev/null || git -C "$TEST_TEMP_DIR/remote.git" for-each-ref --format='%(objectname)' refs/heads)" \
      = "$(git -C "$TEST_TEMP_DIR/repo" rev-parse HEAD)" ]
}

@test "every --commit path reaches git push only via _push_to_remotes (T-5051)" {
    # Exactly one `git ... push` call site in handover.sh, inside _push_to_remotes.
    [ "$(grep -cE 'git -C "\$PROJECT_ROOT" push' "$HANDOVER_SH")" -eq 1 ]
    awk '/^_push_to_remotes\(\) \{/,/^}/' "$HANDOVER_SH" | grep -qE 'git -C "\$PROJECT_ROOT" push'
}
