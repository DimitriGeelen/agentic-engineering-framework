#!/usr/bin/env bats
# T-4684 — TermLink worker dirs live under <project>/.context/dispatch/ since
# T-4675 (prompt.md, env.sh, result.jsonl, stderr.log). Only the framework repo's
# root .gitignore ignored them, so a consumer's `git add -A .context` could commit
# a worker's env.sh. `fw init` and `fw upgrade` must write a consumer-side rule,
# and upgrade must WARN (never untrack) when files are already tracked.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/dispatch-gitignore.sh"
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

_worker_files() {
    printf '%s\n' w4684/env.sh w4684/prompt.md w4684/result.jsonl w4684/stderr.log w4684/meta.json
}

@test "negative control: without the rule a worker's env.sh is committable" {
    p=$(_repo)
    mkdir -p "$p/.context/dispatch/w4684"
    : > "$p/.context/dispatch/w4684/env.sh"
    ! git -C "$p" check-ignore -q .context/dispatch/w4684/env.sh || false
}

@test "ensure_ignored ignores every worker file and leaves the rest of .context visible" {
    p=$(_repo)
    [ "$(fw_dispatch_ensure_ignored "$p")" -eq 1 ]
    mkdir -p "$p/.context/dispatch/w4684"
    while IFS= read -r n; do
        : > "$p/.context/dispatch/$n"
        git -C "$p" check-ignore -q ".context/dispatch/$n" || { echo "not ignored: $n"; false; }
    done < <(_worker_files)
    # anchored: a same-named dir elsewhere and sibling records stay tracked
    mkdir -p "$p/.context/episodic/dispatch" "$p/.context/dispatch-notes"
    for n in episodic/dispatch/x.yaml dispatch-notes/a.md bypass-log.yaml; do
        : > "$p/.context/$n"
        ! git -C "$p" check-ignore -q ".context/$n" || { echo "over-ignored: $n"; false; }
    done
}

@test "ensure_ignored is idempotent, append-only; --dry-run writes nothing" {
    p=$(_repo)
    printf 'my-own-rule' > "$p/.context/.gitignore"   # user line, no trailing newline
    [ "$(fw_dispatch_ensure_ignored "$p" --dry-run)" -eq 1 ]
    [ "$(cat "$p/.context/.gitignore")" = "my-own-rule" ]
    [ "$(fw_dispatch_ensure_ignored "$p")" -eq 1 ]
    grep -qx 'my-own-rule' "$p/.context/.gitignore"
    grep -qx '/dispatch/' "$p/.context/.gitignore"
    cp "$p/.context/.gitignore" "$TEST_TEMP_DIR/first"
    [ "$(fw_dispatch_ensure_ignored "$p")" -eq 0 ]
    cmp "$p/.context/.gitignore" "$TEST_TEMP_DIR/first"
}

@test "dispatch_tracked names files a project already committed and never untracks" {
    p=$(_repo)
    mkdir -p "$p/.context/dispatch/w4684"
    : > "$p/.context/dispatch/w4684/env.sh"
    git -C "$p" add .context/dispatch/w4684/env.sh
    fw_dispatch_ensure_ignored "$p" >/dev/null
    run fw_dispatch_tracked "$p"
    [ "$status" -eq 0 ]
    [ "$output" = ".context/dispatch/w4684/env.sh" ]
    git -C "$p" ls-files --error-unmatch .context/dispatch/w4684/env.sh >/dev/null
}

@test "fw init and fw upgrade both call the shared helper" {
    grep -q 'fw_dispatch_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_dispatch_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "end-to-end: fresh fw init ignores a worker's env.sh" {
    proj="$TEST_TEMP_DIR/fresh"
    mkdir -p "$proj"
    git -C "$proj" init -q
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ -f "$proj/.context/.gitignore" ] || { echo "$output" | tail -20; false; }
    mkdir -p "$proj/.context/dispatch/w4684"
    while IFS= read -r n; do : > "$proj/.context/dispatch/$n"; done < <(_worker_files)
    run git -C "$proj" status --porcelain --untracked-files=all -- .context/dispatch
    [ -z "$output" ] || { echo "dirty: $output"; false; }
}

@test "end-to-end: fw upgrade adds the rule and warns about tracked worker files without untracking" {
    proj="$TEST_TEMP_DIR/old"
    mkdir -p "$proj"
    git -C "$proj" init -q
    run timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    # simulate a pre-T-4684 consumer that already committed a worker dir
    rm -f "$proj/.context/.gitignore"
    mkdir -p "$proj/.context/dispatch/w4684"
    echo 'X=1' > "$proj/.context/dispatch/w4684/env.sh"
    git -C "$proj" add .context/dispatch/w4684/env.sh
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"ADDED"*"dispatch worker-dir ignore rule"* ]] || { echo "$output" | tail -40; false; }
    [[ "$output" == *"already tracked"* ]]
    [[ "$output" == *"rm -r --cached -- .context/dispatch"* ]]
    grep -qx '/dispatch/' "$proj/.context/.gitignore"
    git -C "$proj" ls-files --error-unmatch .context/dispatch/w4684/env.sh >/dev/null
    : > "$proj/.context/dispatch/w4684/prompt.md"
    git -C "$proj" check-ignore -q .context/dispatch/w4684/prompt.md
}
