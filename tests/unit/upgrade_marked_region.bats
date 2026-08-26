#!/usr/bin/env bats
#
# T-3150 — `fw upgrade` step [1/10] rebuilt a consumer's CLAUDE.md as
# (everything above `## Core Principle`) + (framework governance). What survived
# was decided by where an author happened to put a heading, so a consumer that
# organised its governance coherently — its own completion rules next to the
# framework's completion rules, i.e. BELOW that line — lost them silently on
# every upgrade. Three project-authored sections went that way in one upgrade of
# a live consumer.
#
# The fix replaces the positional contract with a declared one: a
# `<!-- project-owned: begin -->` / `<!-- project-owned: end -->` region survives
# wherever it sits.
#
# WHY THE [control] TEST IS THE LOAD-BEARING ONE
# -----------------------------------------------------------------------------
# Every other test here passes trivially if the fixture never exercised the
# defect — a marked region that happened to land above `## Core Principle` would
# survive the OLD code too, and the suite would report a working fix while
# measuring nothing. The control runs the pre-change positional expression
# against the same fixture and asserts it DROPS the region. It recovers that
# expression from the source comment in lib/upgrade.sh rather than re-typing a
# copy here (the shape tests/unit/verification_extractor_anchoring.bats uses):
# if the comment is ever reworded the recovery fails and the control goes red,
# which is correct — it has lost its reference point.
#
# FIXTURES ONLY. Every consumer below is written by the test.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    # Same $HOME scoping as tests/unit/lib_upgrade.bats (T-2759): step 4c reads
    # $HOME/.local/bin/fw unconditionally, and a real dev host's shim there
    # aborts do_upgrade before the later steps run.
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"

    TEMPLATE="$FRAMEWORK_ROOT/lib/templates/claude-project.md"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Create a consumer project at $1 whose CLAUDE.md is read from stdin.
_mk_consumer() {
    local proj="$1"
    mkdir -p "$proj"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"
    cat > "$proj/CLAUDE.md"
    printf '%s' "$proj"
}

# The framework governance tail, exactly as step [1/10] takes it from the
# template.
_template_governance() {
    sed -n '/^## Core Principle$/,$ p' "$TEMPLATE"
}

# The pre-T-3150 header expression, recovered from its source comment.
_old_header_expr() {
    grep "The previous form was" "$FRAMEWORK_ROOT/lib/upgrade.sh" \
        | sed -E "s/.*\`(sed -n [^\`]*)\`.*/\1/"
}

# A consumer that put its own governance BELOW `## Core Principle`, inside a
# marked region — the shape that lost content on every upgrade.
_consumer_region_below() {
    cat <<'EOF'
# CLAUDE.md

## Project Overview

**Project:** fixture-consumer

## Tech Stack and Conventions

PROJECT_HEADER_MARKER_LINE

## Core Principle

**Nothing gets done without a task.** (stale copy of framework governance)

## Some Stale Framework Section

This paragraph is framework governance and is expected to be replaced.

<!-- project-owned: begin -->
## Project Completion Rules

REGION_ONE_PAYLOAD — deploy to staging before any close.
<!-- project-owned: end -->
EOF
}

# ─────────────────────────────────────────────────────────────────────────────

@test "T-3150: a marked region BELOW ## Core Principle survives the rebuild" {
    local proj="$TEST_TEMP_DIR/below"
    _consumer_region_below | _mk_consumer "$proj" >/dev/null

    run do_upgrade "$proj"
    [ "$status" -eq 0 ]

    local out
    out=$(cat "$proj/CLAUDE.md")
    # The project's own section survived, verbatim, markers included.
    [[ "$out" == *"REGION_ONE_PAYLOAD"* ]]
    [[ "$out" == *"## Project Completion Rules"* ]]
    [[ "$out" == *"<!-- project-owned: begin -->"* ]]
    [[ "$out" == *"<!-- project-owned: end -->"* ]]
    # The header still survives, and framework governance was refreshed.
    [[ "$out" == *"PROJECT_HEADER_MARKER_LINE"* ]]
    [[ "$out" == *"Four Constitutional Directives"* ]]
    # The unmarked stale governance section was replaced, as before.
    [[ "$out" != *"## Some Stale Framework Section"* ]]
    # Region sits AFTER governance, not spliced into it.
    local gov_line region_line
    gov_line=$(grep -n '^## Core Principle$' "$proj/CLAUDE.md" | head -1 | cut -d: -f1)
    region_line=$(grep -n 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md" | head -1 | cut -d: -f1)
    [ "$region_line" -gt "$gov_line" ]
}

@test "T-3150 [control]: the pre-change positional form DROPS that region, so the fixture discriminates" {
    local proj="$TEST_TEMP_DIR/control"
    _consumer_region_below | _mk_consumer "$proj" >/dev/null
    cp "$proj/CLAUDE.md" "$TEST_TEMP_DIR/pristine.md"

    local old_expr
    old_expr=$(_old_header_expr)
    [[ "$old_expr" == sed\ -n\ * ]]

    # Reproduce the pre-T-3150 rebuild: recovered header expression applied to
    # the consumer, then the template's governance tail appended.
    local old_header old_rebuild
    old_header=$(eval "$old_expr \"\$TEST_TEMP_DIR/pristine.md\"")
    old_rebuild=$(printf '%s\n%s\n' "$old_header" "$(_template_governance)")

    # The expression ran and produced the header it was supposed to produce...
    [[ "$old_rebuild" == *"PROJECT_HEADER_MARKER_LINE"* ]]
    [[ "$old_rebuild" == *"Four Constitutional Directives"* ]]
    # ...and silently lost the project's marked region. This is the defect.
    [[ "$old_rebuild" != *"REGION_ONE_PAYLOAD"* ]]
    [[ "$old_rebuild" != *"## Project Completion Rules"* ]]

    # And the new code keeps it on the same fixture.
    run do_upgrade "$proj"
    [ "$status" -eq 0 ]
    grep -q 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md"
}

@test "T-3150: BOTH marked regions survive — the second is not dropped" {
    local proj="$TEST_TEMP_DIR/two"
    _mk_consumer "$proj" >/dev/null <<'EOF'
# CLAUDE.md

## Project Overview

**Project:** fixture-consumer

## Core Principle

stale governance

<!-- project-owned: begin -->
## First Project Section

REGION_ONE_PAYLOAD
<!-- project-owned: end -->

## Another Stale Framework Section

replaced

<!-- project-owned: begin -->
## Second Project Section

REGION_TWO_PAYLOAD
<!-- project-owned: end -->
EOF

    run do_upgrade "$proj"
    [ "$status" -eq 0 ]

    local out
    out=$(cat "$proj/CLAUDE.md")
    [[ "$out" == *"REGION_ONE_PAYLOAD"* ]]
    [[ "$out" == *"REGION_TWO_PAYLOAD"* ]]
    [[ "$out" != *"## Another Stale Framework Section"* ]]
    # File order preserved.
    local one two
    one=$(grep -n 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md" | head -1 | cut -d: -f1)
    two=$(grep -n 'REGION_TWO_PAYLOAD' "$proj/CLAUDE.md" | head -1 | cut -d: -f1)
    [ "$one" -lt "$two" ]
    # Exactly two regions — nothing duplicated.
    [ "$(grep -c '^<!-- project-owned: begin -->$' "$proj/CLAUDE.md")" -eq 2 ]
    [ "$(grep -c '^<!-- project-owned: end -->$' "$proj/CLAUDE.md")" -eq 2 ]
}

@test "T-3150: no markers => byte-identical to the pre-change positional rebuild" {
    local proj="$TEST_TEMP_DIR/nomarkers"
    _mk_consumer "$proj" >/dev/null <<'EOF'
# CLAUDE.md

## Project Overview

**Project:** fixture-consumer

PROJECT_HEADER_MARKER_LINE

## Core Principle

stale governance

## Some Stale Framework Section

replaced
EOF
    cp "$proj/CLAUDE.md" "$TEST_TEMP_DIR/pristine-nomarkers.md"

    run do_upgrade "$proj"
    [ "$status" -eq 0 ]

    # Expected == what the pre-change code would have written, computed from the
    # recovered expression rather than asserted by eye.
    local old_expr old_header
    old_expr=$(_old_header_expr)
    old_header=$(eval "$old_expr \"\$TEST_TEMP_DIR/pristine-nomarkers.md\"")
    printf '%s\n%s\n' "$old_header" "$(_template_governance)" > "$TEST_TEMP_DIR/expected.md"

    diff -u "$TEST_TEMP_DIR/expected.md" "$proj/CLAUDE.md"
}

@test "T-3150: an UNCLOSED marker refuses the rewrite and names file and line" {
    local proj="$TEST_TEMP_DIR/unclosed"
    _mk_consumer "$proj" >/dev/null <<'EOF'
# CLAUDE.md

## Project Overview

**Project:** fixture-consumer

## Core Principle

stale governance

<!-- project-owned: begin -->
## Project Completion Rules

REGION_ONE_PAYLOAD
EOF
    local before
    before=$(md5sum < "$proj/CLAUDE.md")

    run do_upgrade "$proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unmatched project-owned marker"* ]]
    [[ "$output" == *"$proj/CLAUDE.md"* ]]
    # The unmatched begin is on line 11 of the fixture above.
    [[ "$output" == *"line 11"* ]]

    # Nothing was rewritten, and no .bak was left behind.
    [ "$(md5sum < "$proj/CLAUDE.md")" = "$before" ]
    [ ! -f "$proj/CLAUDE.md.bak" ]
}

@test "T-3150: a stray end marker also refuses rather than guessing" {
    local proj="$TEST_TEMP_DIR/stray-end"
    _mk_consumer "$proj" >/dev/null <<'EOF'
# CLAUDE.md

## Core Principle

stale governance

## Project Completion Rules

REGION_ONE_PAYLOAD
<!-- project-owned: end -->
EOF

    run do_upgrade "$proj"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unmatched project-owned marker"* ]]
    [[ "$output" == *"line 10"* ]]
    grep -q 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md"
}

@test "T-3150: running upgrade twice is idempotent — no duplication, second run is a no-op" {
    local proj="$TEST_TEMP_DIR/idem"
    _consumer_region_below | _mk_consumer "$proj" >/dev/null

    run do_upgrade "$proj"
    [ "$status" -eq 0 ]
    cp "$proj/CLAUDE.md" "$TEST_TEMP_DIR/after-first.md"

    run do_upgrade "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Already up to date"* ]]

    diff -u "$TEST_TEMP_DIR/after-first.md" "$proj/CLAUDE.md"
    [ "$(grep -c '^<!-- project-owned: begin -->$' "$proj/CLAUDE.md")" -eq 1 ]
    [ "$(grep -c 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md")" -eq 1 ]
}

@test "T-3150: a region ABOVE ## Core Principle is kept once, not duplicated" {
    local proj="$TEST_TEMP_DIR/above"
    _mk_consumer "$proj" >/dev/null <<'EOF'
# CLAUDE.md

## Project Overview

**Project:** fixture-consumer

<!-- project-owned: begin -->
## Project Completion Rules

REGION_ONE_PAYLOAD
<!-- project-owned: end -->

## Core Principle

stale governance
EOF

    run do_upgrade "$proj"
    [ "$status" -eq 0 ]

    grep -q 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md"
    [ "$(grep -c 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md")" -eq 1 ]
    [ "$(grep -c '^<!-- project-owned: begin -->$' "$proj/CLAUDE.md")" -eq 1 ]
    # Still above governance — it was in the header and stayed there.
    local gov_line region_line
    gov_line=$(grep -n '^## Core Principle$' "$proj/CLAUDE.md" | head -1 | cut -d: -f1)
    region_line=$(grep -n 'REGION_ONE_PAYLOAD' "$proj/CLAUDE.md" | head -1 | cut -d: -f1)
    [ "$region_line" -lt "$gov_line" ]
}
