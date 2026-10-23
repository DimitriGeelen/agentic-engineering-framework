#!/usr/bin/env bats
# T-4692: fw upgrade must name the files it left for the consumer to commit.
# Origin: T-4684 made upgrade create .context/.gitignore, and the summary never
# said it needed committing (TermLink field report).
#
# Surfaces under test:
#   lib/upgrade_commit_list.py snapshot|report  (before/after dirty-path diff)
#   _t4692_emit_commit_list / _t4692_emit_would_create  (lib/upgrade.sh)
#   do_upgrade wiring: snapshot taken before the first mutation; report last.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    HELPER="$FW_ROOT/lib/upgrade_commit_list.py"
    REPO="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$REPO/.context"
    git -C "$REPO" init -q
    echo tracked > "$REPO/tracked.txt"
    echo pre > "$REPO/predirty.txt"
    git -C "$REPO" add tracked.txt predirty.txt
    git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm base
    BEFORE="$BATS_TEST_TMPDIR/before.snap"
}

@test "clean tree before and after: report prints nothing" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a file the upgrade creates is listed as new, with one git add line" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo "dispatch/" > "$REPO/.context/.gitignore"
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       .context/.gitignore"* ]]
    [ "$(printf '%s\n' "$output" | grep -c 'git add -- ')" -eq 1 ]
    [[ "$output" == *"git add -- .context/.gitignore"* ]]
}

@test "a tracked file the upgrade modifies is listed as modified" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo changed >> "$REPO/tracked.txt"
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [[ "$output" == *"modified  tracked.txt"* ]]
}

@test "a path dirty before and untouched by the upgrade is NOT listed" {
    echo operator-edit >> "$REPO/predirty.txt"
    echo scratch > "$REPO/scratch.txt"
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [ -z "$output" ]
}

@test "a path dirty before AND changed by the upgrade IS listed" {
    echo operator-edit >> "$REPO/predirty.txt"
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo upgrade-edit >> "$REPO/predirty.txt"
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [[ "$output" == *"modified  predirty.txt"* ]]
}

@test "vendored .agentic-framework files collapse into one entry" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    mkdir -p "$REPO/.agentic-framework/lib"
    for f in a b c; do echo "$f" > "$REPO/.agentic-framework/lib/$f.sh"; done
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [[ "$output" == *"vendored  .agentic-framework/ (3 file(s))"* ]]
    [[ "$output" == *"git add -- .agentic-framework/"* ]]
    [[ "$output" != *"lib/a.sh"* ]]
}

@test "paths with spaces are quoted in the git add line" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo x > "$REPO/with space.txt"
    run python3 "$HELPER" report "$REPO" "$BEFORE"
    [[ "$output" == *"git add -- 'with space.txt'"* ]]
}

@test "non-git target: snapshot and report print nothing, exit 0" {
    local plain="$BATS_TEST_TMPDIR/plain"
    mkdir -p "$plain"
    run python3 "$HELPER" snapshot "$plain"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    : > "$BEFORE"
    echo x > "$plain/new.txt"
    run python3 "$HELPER" report "$plain" "$BEFORE"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "_t4692_emit_commit_list reports and removes the snapshot; silent with no snapshot" {
    export FRAMEWORK_ROOT="$FW_ROOT"
    BOLD=""; NC=""; YELLOW=""; GREEN=""; CYAN=""
    source "$FW_ROOT/lib/upgrade.sh"
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo new > "$REPO/created.txt"
    run _t4692_emit_commit_list "$REPO" "$BEFORE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       created.txt"* ]]
    [ ! -e "$BEFORE" ]
    run _t4692_emit_commit_list "$REPO" ""
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "_t4692_emit_would_create lists each path once; silent when empty" {
    export FRAMEWORK_ROOT="$FW_ROOT"
    BOLD=""; NC=""; YELLOW=""; GREEN=""; CYAN=""
    source "$FW_ROOT/lib/upgrade.sh"
    run _t4692_emit_would_create .context/working/.gitignore .context/working/.gitignore .context/.gitignore
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'new       .context/working/.gitignore')" -eq 1 ]
    [[ "$output" == *"new       .context/.gitignore"* ]]
    run _t4692_emit_would_create
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "do_upgrade wiring: snapshot before the first step, would-create at every create site, report at the end" {
    local src="$FW_ROOT/lib/upgrade.sh"
    local snap step1 report recall
    snap=$(grep -n 'upgrade_commit_list.py" *\\$' "$src" | head -1 | cut -d: -f1)
    step1=$(grep -n 'T-1912: pre-step-1 version-ahead precheck' "$src" | head -1 | cut -d: -f1)
    [ -n "$snap" ] && [ -n "$step1" ] && [ "$snap" -lt "$step1" ]
    report=$(grep -n '_t4692_emit_commit_list "\$target_dir"' "$src" | cut -d: -f1)
    recall=$(grep -n '_t4069_stale_wrapper_notice "\$target_dir"$' "$src" | cut -d: -f1)
    [ -n "$report" ] && [ "$report" -gt "$recall" ]
    for f in 'CLAUDE.md' '.claude/settings.json' '.mcp.json' '.context/working/.gitignore' '.context/.gitignore'; do
        grep -qF "_t4692_would+=(\"$f\")" "$src" || { echo "missing would-create: $f"; false; }
    done
}
