#!/usr/bin/env bats
# T-4821: fw upgrade step [1/10] (CLAUDE.md governance refresh) must not hand
# consumers duplicated guidance, must be a no-op on a second run, and must not leave
# a CLAUDE.md.bak that is identical to CLAUDE.md.
#
# Origin: 055 field tests on be.21 and be.37 — the Work Proposal Rule carried two
# "check context budget" bullets after upgrade, and an identical CLAUDE.md.bak was
# left behind. Root cause: T-4226 added the `checkpoint.sh budget` bullet to
# lib/templates/claude-project.md beside the old `checkpoint.sh status` one instead
# of replacing it; the refresh copies the template verbatim.
#
# Same harness shape as t4232 (do_upgrade against a synthetic consumer).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"

    TEMPLATE="$FRAMEWORK_ROOT/lib/templates/claude-project.md"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.agentic-framework/lib/templates"
    printf 'project_name: proj\nversion: 1.5.0\n' > "$PROJ/.framework.yaml"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# A stock consumer one template revision behind: the vendored template and the
# consumer's CLAUDE.md both lack the current Work Proposal budget bullet.
stock_consumer_behind() {
    grep -v 'check context budget' "$TEMPLATE" \
        > "$PROJ/.agentic-framework/lib/templates/claude-project.md"
    sed 's/__PROJECT_NAME__/proj/g' "$PROJ/.agentic-framework/lib/templates/claude-project.md" \
        > "$PROJ/CLAUDE.md"
}

@test "T-4821: no template section repeats a bold-led bullet" {
    # Within one ## / ### section, two bullets opening with the same **lead** are the
    # T-4226 shape: a rule added beside its predecessor instead of replacing it.
    local dups
    dups=$(sed -n '/^## Core Principle$/,$ p' "$TEMPLATE" | awk '
        /^##/ { delete seen; next }
        match($0, /^- \*\*[^*]+\*\*/) {
            lead = substr($0, RSTART, RLENGTH)
            if (lead in seen) print NR ": " lead
            seen[lead] = 1
        }')
    [ -z "$dups" ] || { echo "duplicate bullets: $dups"; false; }
}

@test "T-4821: refresh yields exactly one Work Proposal budget bullet" {
    stock_consumer_behind
    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Governance sections refreshed"* ]]
    [ "$(grep -c 'check context budget' "$PROJ/CLAUDE.md")" -eq 1 ]
}

@test "T-4821: a second refresh changes no byte and writes no backup" {
    stock_consumer_behind
    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    rm -f "$PROJ/CLAUDE.md.bak"
    cp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/after1.md"

    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Already up to date"* ]]
    cmp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/after1.md"
    [ ! -e "$PROJ/CLAUDE.md.bak" ]
}

@test "T-4821: a CLAUDE.md.bak identical to CLAUDE.md does not survive a run" {
    stock_consumer_behind
    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    cp "$PROJ/CLAUDE.md" "$PROJ/CLAUDE.md.bak"

    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [ ! -e "$PROJ/CLAUDE.md.bak" ]
}

@test "T-4821: a backup that differs from CLAUDE.md is kept" {
    stock_consumer_behind
    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [ -e "$PROJ/CLAUDE.md.bak" ]
    ! cmp -s "$PROJ/CLAUDE.md" "$PROJ/CLAUDE.md.bak" || false
    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [ -e "$PROJ/CLAUDE.md.bak" ]
}
