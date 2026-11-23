#!/usr/bin/env bats
# T-5373 — keylock's flock anchors (.context/locks/*.lock) persist by design.
# Only the framework repo's root .gitignore ignored .context/locks/, so a
# consumer saw `.context/locks/T-486.lock` untracked after `fw inception decide`.
# `fw init` and `fw upgrade` must write a consumer-side rule, idempotently, and
# never touch the consumer's top-level .gitignore.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/locks-gitignore.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_repo() {
    local p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.context"
    git -C "$p" init -q
    echo "$p"
}

# Take and release real locks through both keylock implementations.
_make_locks() {
    local p="$1"
    ( export PROJECT_ROOT="$p"
      # shellcheck source=/dev/null
      source "$FRAMEWORK_ROOT/lib/keylock.sh"
      keylock_acquire "T-486" && keylock_release "T-486" )
    python3 -c '
import sys; sys.path.insert(0, sys.argv[1])
import keylock
with keylock.exclusive(keylock.lock_path_for(sys.argv[2] + "/.context/dispatches.jsonl")):
    pass
' "$FRAMEWORK_ROOT/lib" "$p"
    [ -f "$p/.context/locks/T-486.lock" ] || { echo "keylock.sh made no lock"; ls -la "$p/.context/locks" 2>&1; false; }
    [ -f "$p/.context/locks/dispatches.lock" ] || { echo "keylock.py made no lock"; false; }
}

@test "negative control: without the rule a lock file shows in git status" {
    p=$(_repo)
    _make_locks "$p"
    run git -C "$p" status --porcelain --untracked-files=all -- .context/locks
    [ -n "$output" ]
}

@test "ensure_ignored hides lock files, is anchored, idempotent and append-only" {
    p=$(_repo)
    printf 'my-own-rule' > "$p/.context/.gitignore"   # user line, no trailing newline
    [ "$(fw_locks_ensure_ignored "$p" --dry-run)" -eq 1 ]
    [ "$(cat "$p/.context/.gitignore")" = "my-own-rule" ]
    [ "$(fw_locks_ensure_ignored "$p")" -eq 1 ]
    head -1 "$p/.context/.gitignore" | grep -qx 'my-own-rule'
    before=$(md5sum < "$p/.context/.gitignore")
    [ "$(fw_locks_ensure_ignored "$p")" -eq 0 ]
    [ "$(md5sum < "$p/.context/.gitignore")" = "$before" ]
    _make_locks "$p"
    run git -C "$p" status --porcelain --untracked-files=all -- .context/locks
    [ -z "$output" ] || { echo "dirty: $output"; false; }
    mkdir -p "$p/.context/episodic/locks"
    : > "$p/.context/episodic/locks/x.yaml"
    ! git -C "$p" check-ignore -q .context/episodic/locks/x.yaml || { echo "over-ignored"; false; }
    [ ! -e "$p/.gitignore" ]
}

@test "fw init and fw upgrade both call the shared helper" {
    grep -q 'fw_locks_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_locks_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "end-to-end: fresh fw init keeps keylock files out of git status" {
    proj="$TEST_TEMP_DIR/fresh"
    mkdir -p "$proj"
    git -C "$proj" init -q && git -C "$proj" config gc.auto 0  # T-5373: no detached auto-gc racing teardown (T-5343 class)
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    grep -qx '/locks/' "$proj/.context/.gitignore"
    _make_locks "$proj"
    run git -C "$proj" status --porcelain --untracked-files=all -- .context/locks
    [ -z "$output" ] || { echo "dirty: $output"; false; }
}

@test "end-to-end: fw upgrade adds the rule to an old consumer; a second upgrade changes nothing" {
    proj="$TEST_TEMP_DIR/old"
    mkdir -p "$proj"
    git -C "$proj" init -q && git -C "$proj" config gc.auto 0  # T-5373: no detached auto-gc racing teardown (T-5343 class)
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    # simulate a pre-T-5373 consumer: the nested ignore has no locks rule
    grep -vxF '/locks/' "$proj/.context/.gitignore" | grep -vxF "$FW_LOCKS_IGNORE_MARKER" > "$TEST_TEMP_DIR/gi" || true
    cp "$TEST_TEMP_DIR/gi" "$proj/.context/.gitignore"
    _make_locks "$proj"
    run git -C "$proj" status --porcelain --untracked-files=all -- .context/locks
    [ -n "$output" ]
    top_before=$( [ -f "$proj/.gitignore" ] && md5sum < "$proj/.gitignore" || echo none )
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"ADDED"*"lock-file ignore rule"* ]] || { echo "$output" | tail -40; false; }
    run git -C "$proj" status --porcelain --untracked-files=all -- .context/locks
    [ -z "$output" ] || { echo "dirty: $output"; false; }
    before=$(md5sum < "$proj/.context/.gitignore")
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"Lock files (.context/locks/) gitignored"* ]] || { echo "$output" | tail -40; false; }
    [ "$(md5sum < "$proj/.context/.gitignore")" = "$before" ]
    [ "$(grep -cxF '/locks/' "$proj/.context/.gitignore")" -eq 1 ]
    top_after=$( [ -f "$proj/.gitignore" ] && md5sum < "$proj/.gitignore" || echo none )
    [ "$top_before" = "$top_after" ]
}
