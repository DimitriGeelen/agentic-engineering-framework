#!/usr/bin/env bats
# T-2969 — a draft arc whose constituent tasks are ALL work-completed has no
# path to closure ('fw arc close' requires in-progress — lib/arc.sh:665) and,
# before this task, nothing reported it. The stale-arc check (T-1855) is
# silent on draft arcs BY DESIGN — draft-with-no-activity is backlog, not
# stall, a different question over a different population. This test pins
# the new draft-complete WARN across the three populations that distinguish
# it from that always-answers trap: complete (WARN), incomplete (silent),
# and zero-population (silent — 0/0 is vacuously "all complete" and would
# fire on every empty draft otherwise).
#
# COUNTERFACTUAL (measured by running this same suite against the pre-T-2969
# audit.sh, i.e. `git stash` of the agents/audit/audit.sh change):
#   All three fixtures — complete, incomplete, empty — produced ZERO output
#   matching "is draft with all". No draft-arc-completion check existed at
#   all, so the complete-population leg (the one this task exists to fix)
#   went red for the right reason (feature absent), and the other two legs
#   were vacuously green (nothing to warn about because nothing warned about
#   anything). That vacuous-green shape is exactly why this suite pins all
#   three populations together rather than just the positive case — a
#   suite of the positive leg alone cannot distinguish "correctly silent"
#   from "silent because the whole check is missing".

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || skip "audit.sh not found"
    command -v git >/dev/null 2>&1 || skip "git not on PATH"
    command -v python3 >/dev/null 2>&1 || skip "python3 not on PATH"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.tasks/active" \
             "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.tasks/templates" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" \
             "$TEST_ROOT/.context/audits"

    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    cd "$TEST_ROOT"
    git init -q
    git config user.email "test@local"
    git config user.name "test"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    export FW_AUDIT_TIMEOUT=120
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# --- population 1: all constituents work-completed → WARN ---

@test "T-2969: draft arc with all constituents work-completed → WARN" {
    cat > "$TEST_ROOT/.context/arcs/complete.yaml" <<'YAML'
id: arc-201
slug: complete
name: "all done, still draft"
status: draft
anchor_task: T-2001
YAML
    cat > "$TEST_ROOT/.tasks/completed/T-2001-stub.md" <<'MD'
---
id: T-2001
name: stub
arc_id: complete
---
MD
    cat > "$TEST_ROOT/.tasks/completed/T-2002-stub.md" <<'MD'
---
id: T-2002
name: stub
arc_id: complete
---
MD
    cd "$TEST_ROOT"
    git add .
    git commit -q -m "init"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"'complete'"*"draft with all"* ]]
    [[ "$output" == *"2 constituent"* ]]
    [[ "$output" == *"fw arc start complete"* ]]
}

# --- population 2: some constituents still active → no WARN ---

@test "T-2969: draft arc with an unfinished constituent → no WARN" {
    cat > "$TEST_ROOT/.context/arcs/incomplete.yaml" <<'YAML'
id: arc-202
slug: incomplete
name: "one still open"
status: draft
anchor_task: T-2003
YAML
    cat > "$TEST_ROOT/.tasks/completed/T-2003-stub.md" <<'MD'
---
id: T-2003
name: stub
arc_id: incomplete
---
MD
    cat > "$TEST_ROOT/.tasks/active/T-2004-stub.md" <<'MD'
---
id: T-2004
name: stub
arc_id: incomplete
---
MD
    cd "$TEST_ROOT"
    git add .
    git commit -q -m "init"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"'incomplete'"*"draft with all"* ]]
}

# --- population 3: zero constituents → no WARN (not vacuously "all complete") ---

@test "T-2969: draft arc with zero constituents → no WARN" {
    cat > "$TEST_ROOT/.context/arcs/empty.yaml" <<'YAML'
id: arc-203
slug: emptydraft
name: "nothing assigned yet"
status: draft
anchor_task: T-2005
YAML
    cat > "$TEST_ROOT/.tasks/active/T-2005-stub.md" <<'MD'
---
id: T-2005
name: stub
---
MD
    cd "$TEST_ROOT"
    git add .
    git commit -q -m "init"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"'emptydraft'"*"draft with all"* ]]
}

# --- in-progress arcs are out of scope for this check (stale-arc owns them) ---

@test "T-2969: in-progress arc with all constituents complete → no draft-complete WARN" {
    cat > "$TEST_ROOT/.context/arcs/inprog.yaml" <<'YAML'
id: arc-204
slug: inprog
name: "in progress, all done"
status: in-progress
anchor_task: T-2006
YAML
    cat > "$TEST_ROOT/.tasks/completed/T-2006-stub.md" <<'MD'
---
id: T-2006
name: stub
arc_id: inprog
---
MD
    cd "$TEST_ROOT"
    git add .
    git commit -q -m "init"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"'inprog'"*"draft with all"* ]]
}

# --- sanity ---

@test "T-2969: audit.sh parses cleanly under bash -n" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}
