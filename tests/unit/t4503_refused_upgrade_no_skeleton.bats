#!/usr/bin/env bats
# T-4503: a fw upgrade refused at step 1 (T-3150 unmatched project-owned marker)
# must leave the consumer byte-identical — the step-0 directory skeleton used to
# be created before that refusal. Pattern: t4498_refused_upgrade_no_self_vendor.bats.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4503-XXXXXX)"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    export FW_VERSION="$(cat "$FRAMEWORK_ROOT/VERSION" 2>/dev/null || echo 1.0.0)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ"
    printf 'project_name: proj\nversion: %s\n' "$FW_VERSION" > "$PROJ/.framework.yaml"
    printf '# CLAUDE.md\n<!-- project-owned: begin -->\n\n## Core Principle\n' > "$PROJ/CLAUDE.md"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_tree_hash() {
    ( cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
        if [ -f "$p" ]; then printf '%s %s\n' "$(sha256sum < "$p" | cut -d' ' -f1)" "$p"
        else printf 'dir %s\n' "$p"; fi
      done ) | sha256sum | cut -d' ' -f1
}

@test "T-4503: marker-refused upgrade leaves the consumer tree byte-identical" {
    local before; before=$(_tree_hash "$PROJ")
    run do_upgrade "$PROJ" --no-self-vendor
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    [ "$(_tree_hash "$PROJ")" = "$before" ]
    [ ! -d "$PROJ/.context" ]
    [ ! -d "$PROJ/.tasks" ]
}

@test "T-4503: CONTROL — an accepted upgrade still creates the skeleton" {
    printf '# CLAUDE.md\n' > "$PROJ/CLAUDE.md"
    run do_upgrade "$PROJ" --no-self-vendor
    [ -d "$PROJ/.context/project" ]
    [ -d "$PROJ/.tasks/templates" ]
}
