#!/usr/bin/env bats
# T-4692: fw upgrade must name the files it left for the consumer to commit.
# Origin: T-4684 made upgrade create .context/.gitignore, and the summary never
# said it needed committing (TermLink field report).
#
# Surfaces under test:
#   lib/upgrade_commit_list.py snapshot|report  (before/after dirty-path diff,
#                               filtered to the T-4697 write journal)
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

@test "_t4692_emit_commit_list reports journalled paths and removes snapshot + journal; silent without them" {
    export FRAMEWORK_ROOT="$FW_ROOT"
    BOLD=""; NC=""; YELLOW=""; GREEN=""; CYAN=""
    source "$FW_ROOT/lib/upgrade.sh"
    local wrote="$BATS_TEST_TMPDIR/wrote.log"
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo new > "$REPO/created.txt"
    echo created.txt > "$wrote"
    run _t4692_emit_commit_list "$REPO" "$BEFORE" "$wrote"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       created.txt"* ]]
    [ ! -e "$BEFORE" ] && [ ! -e "$wrote" ]
    run _t4692_emit_commit_list "$REPO" ""
    [ "$status" -eq 0 ] && [ -z "$output" ]
    # no journal: nothing is listed (T-4697 — never offer an unrecorded path)
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo more > "$REPO/created2.txt"
    run _t4692_emit_commit_list "$REPO" "$BEFORE" ""
    [ "$status" -eq 0 ] && [ -z "$output" ]
    [ ! -e "$BEFORE" ]
}

# ── T-4697: only paths the upgrade journalled are listed ─────────────────────
# ring20 be.9: a busy checkout's other writers (cron, hooks, live agents) changed
# files during the upgrade window and the before/after diff listed them as the
# upgrade's own, inside the git add line.

@test "T-4697 report: a changed path the journal does not name is not listed" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo "dispatch/" > "$REPO/.context/.gitignore"
    echo foreign >> "$REPO/tracked.txt"
    mkdir -p "$REPO/.context/infra" && echo x > "$REPO/.context/infra/pg-ha-health.yaml"
    printf '%s\n' .context/.gitignore > "$BATS_TEST_TMPDIR/wrote"
    run python3 "$HELPER" report "$REPO" "$BEFORE" "$BATS_TEST_TMPDIR/wrote"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       .context/.gitignore"* ]]
    [[ "$output" != *"tracked.txt"* ]]
    [[ "$output" != *"pg-ha-health"* ]]
}

@test "T-4697 report: directory entries cover their files; absolute entries resolve; journalled but unchanged is not listed" {
    mkdir -p "$REPO/.agentic-framework/lib"
    echo old > "$REPO/.agentic-framework/lib/keep.sh"
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo a > "$REPO/.agentic-framework/lib/a.sh"
    echo b > "$REPO/abs.txt"
    printf '%s\n' .agentic-framework/ "$REPO/abs.txt" predirty.txt > "$BATS_TEST_TMPDIR/wrote"
    run python3 "$HELPER" report "$REPO" "$BEFORE" "$BATS_TEST_TMPDIR/wrote"
    [[ "$output" == *"vendored  .agentic-framework/ (1 file(s))"* ]]
    [[ "$output" == *"new       abs.txt"* ]]
    [[ "$output" != *"predirty.txt"* ]]
}

@test "T-4697 report: an empty journal lists nothing" {
    python3 "$HELPER" snapshot "$REPO" > "$BEFORE"
    echo x > "$REPO/created.txt"
    : > "$BATS_TEST_TMPDIR/wrote"
    run python3 "$HELPER" report "$REPO" "$BEFORE" "$BATS_TEST_TMPDIR/wrote"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "T-4697 live fw upgrade with a background writer: the writer's files are not listed, the upgrade's are" {
    local home="$BATS_TEST_TMPDIR/home" stop="$BATS_TEST_TMPDIR/stop" ran="$BATS_TEST_TMPDIR/ran"
    mkdir -p "$home" "$REPO/.context/infra"
    printf 'project_name: consumer\nprovider: claude\n' > "$REPO/.framework.yaml"
    git -C "$REPO" add .framework.yaml
    git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm pin
    # Another process on the same checkout: rewrites a clean tracked file and an
    # untracked state file for as long as the upgrade runs.
    ( i=0; while [ ! -e "$stop" ]; do
        i=$((i + 1)); echo "tick $i" > "$REPO/tracked.txt"
        echo "tick $i" > "$REPO/.context/infra/pg-ha-health.yaml"; : > "$ran"; sleep 0.05
      done ) &
    local writer=$!
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT HOME="$home" FW_VERB_TELEMETRY=0 \
        bash -c "cd '$REPO' && '$FW_ROOT/bin/fw' upgrade '$REPO'"
    touch "$stop"; wait "$writer" || true
    [ "$status" -eq 0 ]
    [ -e "$ran" ]
    # the writer really changed both files inside the window
    git -C "$REPO" status --porcelain -uall > "$BATS_TEST_TMPDIR/st"
    grep -q ' tracked.txt$' "$BATS_TEST_TMPDIR/st"
    grep -q 'pg-ha-health.yaml$' "$BATS_TEST_TMPDIR/st"
    # ...and the summary names the upgrade's own files, not the writer's
    [[ "$output" == *"Files this upgrade created or changed"* ]]
    [[ "$output" == *"new       CLAUDE.md"* ]]
    [[ "$output" == *"new       .claude/settings.json"* ]]
    [[ "$output" == *"modified  .framework.yaml"* ]]
    printf '%s\n' "$output" | grep -F 'git add -- ' > "$BATS_TEST_TMPDIR/add"
    [ "$(wc -l < "$BATS_TEST_TMPDIR/add")" -eq 1 ]
    ! grep -qE 'tracked\.txt|pg-ha-health' "$BATS_TEST_TMPDIR/add" || false
    [[ "$output" != *"pg-ha-health"* ]]
    [[ "$output" != *"modified  tracked.txt"* ]]
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

@test "do_upgrade wiring: snapshot before the first step, would-create at every create site, report in the summary block" {
    local src="$FW_ROOT/lib/upgrade.sh"
    local snap step1 report recall
    snap=$(grep -n '^ *_t4717_commit_list_snapshot "\$target_dir"' "$src" | head -1 | cut -d: -f1)
    step1=$(grep -n 'T-1912: pre-step-1 version-ahead precheck' "$src" | head -1 | cut -d: -f1)
    [ -n "$snap" ] && [ -n "$step1" ] && [ "$snap" -lt "$step1" ]
    # T-4724: under the change counters, before Next steps (was: after every notice).
    report=$(grep -n '_t4692_emit_commit_list "\$target_dir"' "$src" | cut -d: -f1)
    applied=$(grep -n 'echo "  \$changes change(s) applied"' "$src" | cut -d: -f1)
    next=$(grep -n 'echo -e "\${BOLD}Next steps:\${NC}"' "$src" | head -1 | cut -d: -f1)
    [ -n "$report" ] && [ -n "$applied" ] && [ -n "$next" ]
    [ "$(printf '%s\n' "$report" | wc -l)" -eq 1 ]
    [ "$report" -gt "$applied" ] && [ "$report" -lt "$next" ]
    for f in 'CLAUDE.md' '.claude/settings.json' '.mcp.json' '.context/working/.gitignore' '.context/.gitignore'; do
        grep -qF "_t4692_would+=(\"$f\")" "$src" || { echo "missing would-create: $f"; false; }
    done
}
