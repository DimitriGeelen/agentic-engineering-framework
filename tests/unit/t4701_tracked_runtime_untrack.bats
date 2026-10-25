#!/usr/bin/env bats
# T-4701 — an ignore rule does not untrack a file a consumer already committed.
# TermLink (their T-3566) had .context/working/.session-silent-scanner.log
# tracked at 551 MB. fw upgrade must name every tracked runtime path with the
# exact `git rm --cached -- <paths>` command, in --dry-run as well as apply,
# and must never untrack anything itself.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/vec-index-gitignore.sh"
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/working-gitignore.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_repo() {
    local p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.context/working"
    git -C "$p" init -q
    echo "$p"
}

@test "tracked_runtime finds a tracked runtime file before any ignore rule is written (dry-run view)" {
    p=$(_repo)
    echo x > "$p/.context/working/.session-silent-scanner.log"
    git -C "$p" add .context/working/.session-silent-scanner.log
    [ ! -e "$p/.context/working/.gitignore" ]
    run fw_working_tracked_runtime "$p"
    [ "$status" -eq 0 ]
    [ "$output" = ".context/working/.session-silent-scanner.log" ]
}

@test "tracked_runtime covers the vector-index rules too" {
    p=$(_repo)
    : > "$p/.context/working/fw-vec-index.db"
    git -C "$p" add .context/working/fw-vec-index.db
    run fw_working_tracked_runtime "$p"
    [ "$output" = ".context/working/fw-vec-index.db" ]
}

@test "tracked_runtime leaves kept records alone and prints nothing for a clean repo" {
    p=$(_repo)
    run fw_working_tracked_runtime "$p"
    [ -z "$output" ]
    while IFS= read -r n; do
        [ "$n" = observations ] && continue
        : > "$p/.context/working/$n"
        git -C "$p" add -- ".context/working/$n"
    done < <(fw_working_keep_tracked)
    run fw_working_tracked_runtime "$p"
    [ -z "$output" ] || { echo "kept record flagged: $output"; false; }
}

@test "end-to-end: fw upgrade names the tracked file and the exact command, dry-run and apply, never untracks" {
    proj="$TEST_TEMP_DIR/old"
    mkdir -p "$proj"
    git -C "$proj" init -q
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    # simulate a consumer that committed the log before the ignore rule existed
    rm -f "$proj/.context/working/.gitignore"
    echo big > "$proj/.context/working/.session-silent-scanner.log"
    git -C "$proj" add .context/working/.session-silent-scanner.log

    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"already tracked"* ]] || { echo "$output" | grep -n "working" ; false; }
    [[ "$output" == *"        .context/working/.session-silent-scanner.log"* ]]
    [[ "$output" == *"git -C \"$proj\" rm --cached -- .context/working/.session-silent-scanner.log"* ]]

    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    cmd=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^ +git -C .* rm --cached -- \.context/working/" | head -1)
    [ -n "$cmd" ] || { echo "$output" | tail -40; false; }
    # still tracked: upgrade never untracks
    git -C "$proj" ls-files --error-unmatch .context/working/.session-silent-scanner.log >/dev/null

    # the printed command, run as printed, untracks it and keeps the file on disk
    eval "$cmd"
    ! git -C "$proj" ls-files --error-unmatch .context/working/.session-silent-scanner.log >/dev/null 2>&1 || false
    [ -f "$proj/.context/working/.session-silent-scanner.log" ]
    git -C "$proj" check-ignore -q .context/working/.session-silent-scanner.log

    # once clean, upgrade says nothing about tracked runtime files
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" != *"under .context/working are already tracked"* ]]
}
