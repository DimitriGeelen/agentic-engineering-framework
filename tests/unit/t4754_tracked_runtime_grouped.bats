#!/usr/bin/env bats
# T-4754 — the T-4701 tracked-runtime notice groups the paths before the single
# `git rm --cached` command. ring20 had 214 tracked files: a flat list and a
# 214-path command were correct but not reviewable. The command stays complete.

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

@test "group_tracked: subdirectory, glob rule and exact name, largest first, ties by label" {
    run fw_working_group_tracked < <(printf '%s\n' \
        .context/working/episodic-gen/a.yaml \
        .context/working/episodic-gen/b.yaml \
        .context/working/episodic-gen/sub/c.yaml \
        .context/working/x.log.1 \
        .context/working/y.log.1 \
        .context/working/decide/T-1.md \
        .context/working/decide/T-2.md \
        .context/working/w.pid \
        .context/working/.budget-status)
    [ "$status" -eq 0 ]
    expected=$(printf '%s\n' \
        '3 x .context/working/episodic-gen/*' \
        '2 x .context/working/*.log.*' \
        '2 x .context/working/decide/*' \
        '1 x .context/working/.budget-status' \
        '1 x .context/working/w.pid')
    [ "$output" = "$expected" ] || { echo "got:"; echo "$output"; false; }
}

@test "group_tracked: empty input prints nothing" {
    run fw_working_group_tracked < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "end-to-end: fw upgrade --dry-run prints grouped counts, then a command that untracks exactly those paths" {
    proj="$TEST_TEMP_DIR/old"
    mkdir -p "$proj"
    git -C "$proj" init -q
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    rm -f "$proj/.context/working/.gitignore"
    w="$proj/.context/working"
    mkdir -p "$w/episodic-gen" "$w/decide"
    for i in 1 2 3; do echo x > "$w/episodic-gen/T-$i.yaml"; done
    for i in 1 2; do echo x > "$w/decide/T-$i.md"; done
    echo 123 > "$w/watchtower.pid"
    echo keep > "$w/happiness.jsonl"
    git -C "$proj" add -f .context/working/episodic-gen .context/working/decide \
        .context/working/watchtower.pid .context/working/happiness.jsonl

    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    out=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g')
    summary=$(printf '%s\n' "$out" | grep -E '^ +[0-9]+ x \.context/working/' | sed 's/^ *//')
    expected=$(printf '%s\n' \
        '3 x .context/working/episodic-gen/*' \
        '2 x .context/working/decide/*' \
        '1 x .context/working/watchtower.pid')
    [ "$summary" = "$expected" ] || { echo "got:"; echo "$summary"; printf '%s\n' "$out" | grep -n -A8 "already tracked"; false; }
    # the summary comes before the command
    sline=$(printf '%s\n' "$out" | grep -n -m1 -E '^ +3 x ' | cut -d: -f1)
    cline=$(printf '%s\n' "$out" | grep -n -m1 -E "^ +git -C .* rm --cached -- \.context/working/" | cut -d: -f1)
    [ -n "$sline" ] && [ -n "$cline" ] && [ "$sline" -lt "$cline" ]
    [[ "$out" == *"untrack all 6 with"* ]]
    cmd=$(printf '%s\n' "$out" | sed -n "${cline}p")
    # dry-run untracked nothing
    [ "$(git -C "$proj" ls-files -- .context/working/episodic-gen .context/working/decide .context/working/watchtower.pid | wc -l)" -eq 6 ]

    eval "$cmd"
    # exactly the six runtime paths left the index; the kept record did not
    [ -z "$(git -C "$proj" ls-files -- .context/working/episodic-gen .context/working/decide .context/working/watchtower.pid)" ]
    git -C "$proj" ls-files --error-unmatch .context/working/happiness.jsonl >/dev/null
    [ -f "$w/episodic-gen/T-1.yaml" ] && [ -f "$w/watchtower.pid" ]
}
