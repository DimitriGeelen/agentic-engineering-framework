#!/usr/bin/env bats
# T-4833: the consumer CLAUDE.md template must carry the Worktree Policy (opt-in only),
# and fw upgrade's governance refresh must deliver it once, idempotently.
#
# Origin: 055 (their T-649) made 27 worktree branches in 8 days with no operator
# instruction because lib/templates/claude-project.md never mentioned worktrees.

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

# Stock consumer one revision behind: template minus the Worktree Policy section.
stock_consumer_without_policy() {
    awk '/^## Worktree Policy/ {skip=1; next} /^## / {skip=0} !skip' "$TEMPLATE" \
        > "$PROJ/.agentic-framework/lib/templates/claude-project.md"
    sed 's/__PROJECT_NAME__/proj/g' "$PROJ/.agentic-framework/lib/templates/claude-project.md" \
        > "$PROJ/CLAUDE.md"
}

@test "T-4833: template carries the Worktree Policy section and its key rules" {
    grep -q '^## Worktree Policy — OPT-IN ONLY' "$TEMPLATE"
    grep -q 'explicitly instructed one, in this session, in their own words' "$TEMPLATE"
    grep -q 'It would be cleaner in isolation' "$TEMPLATE"
    grep -q 'the dispatch protocol says to' "$TEMPLATE"
    grep -q 'Main checkout. No worktree.' "$TEMPLATE"
    grep -q 'Serialise it in the main checkout' "$TEMPLATE"
    grep -q 'MAY \*\*suggest\*\* a worktree, once' "$TEMPLATE"
    grep -q 'never straight onto the release branch' "$TEMPLATE"
}

@test "T-4833: the section sits in the governance region fw upgrade refreshes" {
    local pol core
    pol=$(grep -n '^## Worktree Policy' "$TEMPLATE" | cut -d: -f1)
    core=$(grep -n '^## Core Principle$' "$TEMPLATE" | cut -d: -f1)
    [ "$pol" -gt "$core" ]
}

@test "T-4833: fw init output carries the Worktree Policy" {
    sed 's/__PROJECT_NAME__/proj/g' "$TEMPLATE" > "$TEST_TEMP_DIR/out.md"
    [ "$(grep -c '^## Worktree Policy' "$TEST_TEMP_DIR/out.md")" -eq 1 ]
}

@test "T-4833: upgrade delivers the policy once, keeps project sections, and is idempotent" {
    stock_consumer_without_policy
    printf '\n<!-- marker-line-T4833 -->\n' > "$TEST_TEMP_DIR/extra"
    sed -i '/^## Project-Specific Rules$/r '"$TEST_TEMP_DIR/extra" "$PROJ/CLAUDE.md"
    ! grep -q 'Worktree Policy' "$PROJ/CLAUDE.md" || false

    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^## Worktree Policy' "$PROJ/CLAUDE.md")" -eq 1 ]
    grep -q 'marker-line-T4833' "$PROJ/CLAUDE.md"
    grep -q '^\*\*Project:\*\* proj' "$PROJ/CLAUDE.md"

    rm -f "$PROJ/CLAUDE.md.bak"
    cp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/after1.md"
    run do_upgrade "$PROJ"
    [ "$status" -eq 0 ]
    cmp "$PROJ/CLAUDE.md" "$TEST_TEMP_DIR/after1.md"
    [ "$(grep -c '^## Worktree Policy' "$PROJ/CLAUDE.md")" -eq 1 ]
}
