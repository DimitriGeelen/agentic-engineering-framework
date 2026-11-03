#!/usr/bin/env bats
# T-5052 — the handover commit never claims a commit that did not happen.
#
# 050-email-archive ignores /.context/* and tracks its handovers by force-add.
# A plain `git add` skipped the new handover, the pathspec commit failed, and
# the HANDOVER_PUSH=0 line still said "committed locally only".

load ../test_helper

HANDOVER_SH=""

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
    HANDOVER_SH="$FRAMEWORK_ROOT/agents/handover/handover.sh"

    R="$TEST_TEMP_DIR/repo"
    git init -q "$R"
    git -C "$R" config user.email t@example.invalid
    git -C "$R" config user.name t
    git -C "$R" config core.hooksPath /dev/null
    echo '/.context/*' > "$R/.gitignore"
    git -C "$R" add .gitignore
    git -C "$R" commit -q -m "T-0000: seed"
    mkdir -p "$R/.context/handovers"

    # A stand-in git agent: a plain pathspec commit, as agents/git/git.sh does.
    cat > "$TEST_TEMP_DIR/git-agent.sh" <<'EOF'
#!/bin/bash
shift  # "commit"
exec git -C "$PROJECT_ROOT" commit -q "$@"
EOF
    chmod +x "$TEST_TEMP_DIR/git-agent.sh"

    # The real functions from handover.sh, not copies of their predicates.
    for fn in _push_summary _push_to_remotes _commit_handover_files; do
        awk "/^${fn}\\(\\) \\{/,/^}/" "$HANDOVER_SH" >> "$TEST_TEMP_DIR/fns.sh"
    done
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_commit_then_push() {
    run env PROJECT_ROOT="$R" HANDOVER_DIR="$R/.context/handovers" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        GIT_AGENT="$TEST_TEMP_DIR/git-agent.sh" FW_HANDOVER_PUSH=0 NO_PUSH=false bash -c '
            source "$FRAMEWORK_ROOT/lib/config.sh"
            source "'"$TEST_TEMP_DIR"'/fns.sh"
            _commit_handover_files "T-0000: Session handover S-X" "$HANDOVER_DIR/S-X.md"
            _push_to_remotes'
}

@test "ignored .context/ with tracked handovers: new handover is force-added and committed (T-5052)" {
    echo old > "$R/.context/handovers/S-OLD.md"
    git -C "$R" add -f .context/handovers/S-OLD.md
    git -C "$R" commit -q -m "T-0000: old handover"
    echo new > "$R/.context/handovers/S-X.md"
    _run_commit_then_push
    [ "$status" -eq 0 ]
    git -C "$R" ls-files --error-unmatch .context/handovers/S-X.md
    [[ "$output" != *"COMMIT FAILED"* ]]
    [[ "$output" == *"committed locally only (T-5051)"* ]]
}

@test "ignored .context/ and no tracked handover: COMMIT FAILED, no 'committed locally only' (T-5052)" {
    echo new > "$R/.context/handovers/S-X.md"
    _run_commit_then_push
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMMIT FAILED (T-5052)"* ]]
    [ -z "$(git -C "$R" ls-files .context/handovers/S-X.md)" ]
    [[ "$output" == *"handover was NOT committed"* ]]
    [[ "$output" != *"committed locally only"* ]]
}

@test "commit itself fails: COMMIT FAILED and the push line says so (T-5052)" {
    echo old > "$R/.context/handovers/S-OLD.md"
    git -C "$R" add -f .context/handovers/S-OLD.md
    git -C "$R" commit -q -m "T-0000: old handover"
    echo new > "$R/.context/handovers/S-X.md"
    printf '#!/bin/bash\nexit 1\n' > "$TEST_TEMP_DIR/git-agent.sh"
    _run_commit_then_push
    [[ "$output" == *"COMMIT FAILED (T-5052): the handover commit did not go through"* ]]
    [[ "$output" != *"committed locally only"* ]]
}

@test "not ignored: plain add and commit, as before (T-5052 control)" {
    echo '' > "$R/.gitignore"
    git -C "$R" commit -q -am "T-0000: unignore"
    echo new > "$R/.context/handovers/S-X.md"
    _run_commit_then_push
    [ "$status" -eq 0 ]
    git -C "$R" ls-files --error-unmatch .context/handovers/S-X.md
    [[ "$output" != *"COMMIT FAILED"* ]]
}
