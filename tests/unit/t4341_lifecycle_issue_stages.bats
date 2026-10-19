#!/usr/bin/env bats
# T-4341: `fw issues lifecycle` posts in-progress (started-work) and fixed-on-bleeding-edge
# (work-completed) on a task's linked GitHub issue, through the one outward verb.
#   - idempotent per stage; no github_issue: → nothing; FW_ISSUES_LIFECYCLE=0 → nothing;
#   - a gh/GitHub failure exits 0, prints one WARN and records lifecycle-pending.jsonl;
#   - update-task.sh calls it on both transitions.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ORIGIN="$TEST_TEMP_DIR/gh-mirror.git"
    REPO="$TEST_TEMP_DIR/repo"
    git init -q --bare -b bleeding-edge "$ORIGIN"
    mkdir -p "$REPO/.tasks/active"
    git -C "$REPO" init -q -b bleeding-edge
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    git -C "$REPO" remote add github "$ORIGIN"
    printf -- '---\nid: T-100\nstatus: started-work\ngithub_issue: 7\n---\n# T-100\n\n## Verification\n\nbash -n lib/x.sh\nbats tests/unit/t100_fix.bats\n' \
        > "$REPO/.tasks/active/T-100-fix.md"
    printf -- '---\nid: T-101\nstatus: started-work\n---\n# T-101\n' > "$REPO/.tasks/active/T-101-nolink.md"
    echo x > "$REPO/f"; git -C "$REPO" add -A; git -C "$REPO" commit -qm "T-100: fix it"
    git -C "$REPO" push -q github bleeding-edge
    COMMIT="$(git -C "$REPO" rev-parse HEAD)"

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    GH_LOG="$TEST_TEMP_DIR/gh.log"
    cat > "$STUB_BIN/gh" <<EOS
#!/bin/sh
echo "\$*" >> "$GH_LOG"
[ -n "\$FAKE_GH_FAIL" ] && exit 1
case "\$1 \$2" in
  "api user") echo maint ;;
  "label list") echo '[]' ;;
  "issue view") echo '{"comments":[]}' ;;
  "issue comment") cat >> "$GH_LOG.bodies"; echo https://github.com/x/y/issues/7#issuecomment-1 ;;
esac
exit 0
EOS
    chmod +x "$STUB_BIN/gh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_lc() {  # _lc <task> <event>
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" FW_ISSUES_GIT_REMOTE=github \
        python3 "$FRAMEWORK_ROOT/lib/issues.py" lifecycle "$1" --event "$2" 2>&1
}
_comments() { grep -c "^issue comment" "$GH_LOG" 2>/dev/null || true; }

@test "started posts in-progress once, second run posts nothing" {
    cd "$REPO"
    _lc T-100 started
    [ "$status" -eq 0 ]
    [[ "$output" == *"posted in-progress on #7"* ]]
    _lc T-100 started
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(_comments)" = "1" ]
}

@test "closed posts fixed-on-bleeding-edge with the commit and the first test runner line" {
    cd "$REPO"
    _lc T-100 closed
    [ "$status" -eq 0 ]
    [[ "$output" == *"posted fixed-on-bleeding-edge on #7"* ]]
    grep -q "$COMMIT" "$GH_LOG.bodies"
    grep -q 'bats tests/unit/t100_fix.bats' "$GH_LOG.bodies"
}

@test "closed with no test runner line falls back to the documented command" {
    cd "$REPO"
    printf -- '---\nid: T-100\nstatus: work-completed\ngithub_issue: 7\n---\n# T-100\n\n## Verification\n\ntrue\n' \
        > "$REPO/.tasks/active/T-100-fix.md"
    _lc T-100 closed
    [ "$status" -eq 0 ]
    grep -q 'bin/fw doctor' "$GH_LOG.bodies"
}

@test "no github_issue: nothing is posted" {
    cd "$REPO"
    _lc T-101 started
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$GH_LOG" ]
}

@test "FW_ISSUES_LIFECYCLE=0 disables it" {
    cd "$REPO"
    run env FW_ISSUES_LIFECYCLE=0 PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" \
        python3 "$FRAMEWORK_ROOT/lib/issues.py" lifecycle T-100 --event started
    [ "$status" -eq 0 ]
    [ ! -e "$GH_LOG" ]
}

@test "a gh failure exits 0, prints one WARN and records the retry" {
    cd "$REPO"
    run env FAKE_GH_FAIL=1 PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" FW_ISSUES_GIT_REMOTE=github \
        python3 "$FRAMEWORK_ROOT/lib/issues.py" lifecycle T-100 --event started 2>&1
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c '^WARN')" = "1" ]
    grep -q '"stage": "in-progress"' "$REPO/.context/issues/lifecycle-pending.jsonl"
}

@test "closed with the commit not on the mirror is recorded, not raised" {
    cd "$REPO"
    echo y > f; git commit -qam "T-100: more"   # local only
    git -C "$REPO" push -q --delete github bleeding-edge 2>/dev/null || true
    git -C "$REPO" push -q github "$COMMIT:refs/heads/bleeding-edge"
    _lc T-100 closed
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
    grep -q 'fixed-on-bleeding-edge' "$REPO/.context/issues/lifecycle-pending.jsonl"
}

@test "update-task.sh calls the lifecycle verb on both transitions, guarded" {
    grep -q 'issues.py" \\' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q 'lifecycle "\$TASK_ID" --event "\$_lc_event" || true' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q 'started-work) _lc_event=started' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q 'work-completed) _lc_event=closed' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}
