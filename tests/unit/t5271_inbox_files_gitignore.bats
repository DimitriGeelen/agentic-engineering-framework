#!/usr/bin/env bats
# T-5271 — the fleet cockpit's /drop page writes operator files (possibly
# sensitive) into <project>/.context/inbox/files/. No project ignored that path,
# so `git add -A .context` could commit a dropped file. fw init writes the rule,
# fw upgrade adds it, and fw doctor / fw audit WARN when the path is not ignored
# or a file under it is tracked (naming it, never untracking it).
# Every test uses a temporary project root, never the real tree.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/inbox-files-gitignore.sh"
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

# A fresh fw init project, with its bootstrap state committed so only what the
# test adds is in play.
_init_proj() {
    local proj="$TEST_TEMP_DIR/$1"
    mkdir -p "$proj"
    git -C "$proj" init -q && git -C "$proj" config gc.auto 0 && git -C "$proj" config gc.autoDetach false  # T-5399: no detached auto-gc racing teardown (T-5343 class)
    timeout 300 "$FRAMEWORK_ROOT/bin/fw" init "$proj" --provider claude --no-first-run >/dev/null 2>&1 || return 1
    echo "$proj"
}

@test "negative control: without the rule a dropped file is committable" {
    p=$(_repo)
    mkdir -p "$p/.context/inbox/files"
    : > "$p/.context/inbox/files/secret.pdf"
    ! git -C "$p" check-ignore -q .context/inbox/files/secret.pdf || false
    run fw_inbox_files_problems "$p"
    [ "$status" -eq 1 ]
    [ "$output" = "not-ignored" ]
}

@test "ensure_ignored ignores dropped files and leaves the rest of the inbox visible" {
    p=$(_repo)
    [ "$(fw_inbox_files_ensure_ignored "$p")" -eq 1 ]
    mkdir -p "$p/.context/inbox/files/sub" "$p/.context/inbox/processed" "$p/.context/episodic/inbox/files"
    for n in files/a.pdf files/sub/b.txt files/.hidden; do
        : > "$p/.context/inbox/$n"
        git -C "$p" check-ignore -q ".context/inbox/$n" || { echo "not ignored: $n"; false; }
    done
    for n in inbox/processed/x.md inbox.yaml episodic/inbox/files/y.yaml; do
        : > "$p/.context/$n"
        ! git -C "$p" check-ignore -q ".context/$n" || { echo "over-ignored: $n"; false; }
    done
    run fw_inbox_files_problems "$p"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ensure_ignored is idempotent and append-only; shares .context/.gitignore with dispatch" {
    p=$(_repo)
    printf 'my-own-rule' > "$p/.context/.gitignore"   # user line, no trailing newline
    [ "$(fw_inbox_files_ensure_ignored "$p")" -eq 1 ]
    grep -qx 'my-own-rule' "$p/.context/.gitignore"
    grep -qx '/inbox/files/' "$p/.context/.gitignore"
    cp "$p/.context/.gitignore" "$TEST_TEMP_DIR/first"
    [ "$(fw_inbox_files_ensure_ignored "$p")" -eq 0 ]
    cmp "$p/.context/.gitignore" "$TEST_TEMP_DIR/first"
    [ "$(grep -c '^/inbox/files/$' "$p/.context/.gitignore")" -eq 1 ]
    [ "$(grep -c 'T-5271' "$p/.context/.gitignore")" -eq 1 ]
}

@test "ensure_ignored --dry-run counts but writes nothing (and creates nothing)" {
    p=$(_repo)
    [ "$(fw_inbox_files_ensure_ignored "$p" --dry-run)" -eq 1 ]
    [ ! -e "$p/.context/.gitignore" ]
    echo 'keep' > "$p/.context/.gitignore"
    [ "$(fw_inbox_files_ensure_ignored "$p" --dry-run)" -eq 1 ]
    [ "$(cat "$p/.context/.gitignore")" = "keep" ]
}

@test "problems names a tracked dropped file even when the rule exists, and never untracks" {
    p=$(_repo)
    mkdir -p "$p/.context/inbox/files"
    echo x > "$p/.context/inbox/files/contract.pdf"
    git -C "$p" add .context/inbox/files/contract.pdf
    fw_inbox_files_ensure_ignored "$p" >/dev/null
    run fw_inbox_files_problems "$p"
    [ "$status" -eq 1 ]
    [ "$output" = "tracked .context/inbox/files/contract.pdf" ]
    git -C "$p" ls-files --error-unmatch .context/inbox/files/contract.pdf >/dev/null
    [ -f "$p/.context/inbox/files/contract.pdf" ]
}

@test "problems is silent outside a git work tree" {
    p="$TEST_TEMP_DIR/nogit"
    mkdir -p "$p/.context"
    run fw_inbox_files_problems "$p"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fw init, fw upgrade, fw doctor and fw audit all call the shared helper" {
    grep -q 'fw_inbox_files_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/init.sh"
    grep -q 'fw_inbox_files_ensure_ignored "\$target_dir"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q 'fw_inbox_files_problems "\$PROJECT_ROOT"' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'fw_inbox_files_problems "\$PROJECT_ROOT"' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "end-to-end: fresh fw init ignores a dropped file" {
    proj=$(_init_proj fresh) || { echo "fw init failed"; false; }
    grep -qx '/inbox/files/' "$proj/.context/.gitignore"
    mkdir -p "$proj/.context/inbox/files"
    : > "$proj/.context/inbox/files/dropped.pdf"
    run git -C "$proj" status --porcelain --untracked-files=all -- .context/inbox/files
    [ -z "$output" ] || { echo "dirty: $output"; false; }
}

@test "end-to-end: fw upgrade --dry-run reports WOULD ADD and writes nothing; upgrade adds it; re-run is OK" {
    proj=$(_init_proj old) || { echo "fw init failed"; false; }
    # simulate a pre-T-5271 project: dispatch rule present, inbox rule absent
    grep -vx '/inbox/files/' "$proj/.context/.gitignore" | grep -v 'T-5271' > "$TEST_TEMP_DIR/gi"
    cp "$TEST_TEMP_DIR/gi" "$proj/.context/.gitignore"
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"WOULD ADD"*"dropped-files ignore rule"* ]] || { echo "$output" | tail -40; false; }
    ! grep -qx '/inbox/files/' "$proj/.context/.gitignore" || false
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"ADDED"*"dropped-files ignore rule"* ]] || { echo "$output" | tail -40; false; }
    grep -qx '/dispatch/' "$proj/.context/.gitignore"
    [ "$(grep -c '^/inbox/files/$' "$proj/.context/.gitignore")" -eq 1 ]
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"Dropped files (.context/inbox/files/) gitignored"* ]] || { echo "$output" | tail -40; false; }
    [ "$(grep -c '^/inbox/files/$' "$proj/.context/.gitignore")" -eq 1 ]
}

@test "end-to-end: fw upgrade names an already-tracked dropped file and does not untrack it" {
    proj=$(_init_proj tracked) || { echo "fw init failed"; false; }
    mkdir -p "$proj/.context/inbox/files"
    echo x > "$proj/.context/inbox/files/payslip.pdf"
    git -C "$proj" add -f .context/inbox/files/payslip.pdf
    run timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$proj"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    [[ "$output" == *"already tracked"* ]] || { echo "$output" | tail -40; false; }
    [[ "$output" == *"rm --cached -- .context/inbox/files/payslip.pdf"* ]]
    git -C "$proj" ls-files --error-unmatch .context/inbox/files/payslip.pdf >/dev/null
}

@test "end-to-end: fw doctor WARNs for not-ignored and for tracked, OK when clean" {
    proj=$(_init_proj doc) || { echo "fw init failed"; false; }
    run bash -c "cd '$proj' && PROJECT_ROOT='$proj' timeout 600 '$FRAMEWORK_ROOT/bin/fw' doctor 2>&1"
    [[ "$output" == *"Dropped files (.context/inbox/files/) gitignored, none tracked"* ]] || { echo "$output" | grep -i dropped; false; }
    # not ignored
    grep -vx '/inbox/files/' "$proj/.context/.gitignore" > "$TEST_TEMP_DIR/gi"
    cp "$TEST_TEMP_DIR/gi" "$proj/.context/.gitignore"
    run bash -c "cd '$proj' && PROJECT_ROOT='$proj' timeout 600 '$FRAMEWORK_ROOT/bin/fw' doctor 2>&1"
    [[ "$output" == *"WARN"*"Dropped files can be committed: .context/inbox/files/ is not gitignored"* ]] || { echo "$output" | grep -i dropped; false; }
    # tracked (rule restored)
    fw_inbox_files_ensure_ignored "$proj" >/dev/null
    mkdir -p "$proj/.context/inbox/files"
    echo x > "$proj/.context/inbox/files/id-scan.png"
    git -C "$proj" add -f .context/inbox/files/id-scan.png
    run bash -c "cd '$proj' && PROJECT_ROOT='$proj' timeout 600 '$FRAMEWORK_ROOT/bin/fw' doctor 2>&1"
    [[ "$output" == *"WARN"*"Dropped files TRACKED by git: 1 under .context/inbox/files/"* ]] || { echo "$output" | grep -i dropped; false; }
    [[ "$output" == *".context/inbox/files/id-scan.png"* ]]
    [[ "$output" == *"git rm --cached <path>"* ]]
    [[ "$output" != *"is not gitignored"* ]]
    git -C "$proj" ls-files --error-unmatch .context/inbox/files/id-scan.png >/dev/null
}

@test "end-to-end: fw audit WARNs for not-ignored and names a tracked file with git rm --cached" {
    proj=$(_init_proj aud) || { echo "fw init failed"; false; }
    grep -vx '/inbox/files/' "$proj/.context/.gitignore" > "$TEST_TEMP_DIR/gi"
    cp "$TEST_TEMP_DIR/gi" "$proj/.context/.gitignore"
    mkdir -p "$proj/.context/inbox/files"
    echo x > "$proj/.context/inbox/files/bank.csv"
    git -C "$proj" add .context/inbox/files/bank.csv
    run bash -c "cd '$proj' && PROJECT_ROOT='$proj' timeout 900 '$FRAMEWORK_ROOT/bin/fw' audit --section structure 2>&1"
    [[ "$output" == *"Dropped files can be committed: .context/inbox/files/ is not gitignored"* ]] || { echo "$output" | grep -i -A2 dropped; false; }
    [[ "$output" == *"Dropped files TRACKED by git: 1 under .context/inbox/files/"* ]] || { echo "$output" | grep -i -A2 dropped; false; }
    [[ "$output" == *"git rm --cached .context/inbox/files/bank.csv"* ]] || { echo "$output" | grep -i -A3 dropped; false; }
    git -C "$proj" ls-files --error-unmatch .context/inbox/files/bank.csv >/dev/null
}
