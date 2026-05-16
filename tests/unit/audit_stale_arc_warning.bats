#!/usr/bin/env bats
# T-1855 (T-NEW-7): stale-arc audit warning.
#
# For each arc with status: in-progress, audit WARNs when no commit in the
# last FW_STALE_ARC_DAYS days (default 30) has touched any task with matching
# arc_id: (slug or arc-NNN form). Silent on draft/closed/abandoned arcs and
# on zero-population arcs. WARN-only, never blocks (T-1846 §4 D4, audit exit
# ≤ 1). Symmetric to T-1856 anchor existence check.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || skip "audit.sh not found"
    command -v git >/dev/null 2>&1 || skip "git not on PATH"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.tasks/active" \
             "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.tasks/templates" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" \
             "$TEST_ROOT/.context/audits"

    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    # Initialise a git repo so audit's `git log` works inside the fixture.
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

# --- stale path: in-progress arc with old-only commits → WARN ---

@test "T-1855: in-progress arc with no recent task commits → WARN" {
    cat > "$TEST_ROOT/.context/arcs/stale.yaml" <<'YAML'
id: arc-101
slug: stale
name: "stale arc"
status: in-progress
anchor_task: T-1001
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1001-stub.md" <<'MD'
---
id: T-1001
name: stub
arc_id: stale
---
MD
    cd "$TEST_ROOT"
    git add .
    GIT_AUTHOR_DATE="2025-01-01T00:00:00Z" GIT_COMMITTER_DATE="2025-01-01T00:00:00Z" \
        git commit -q -m "old commit" --date="2025-01-01T00:00:00Z"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"stale"* ]]
    [[ "$output" == *"no task commits"* ]]
}

# --- fresh path: in-progress arc with a recent commit → no WARN ---

@test "T-1855: in-progress arc with recent task commit → pass line emitted" {
    cat > "$TEST_ROOT/.context/arcs/fresh.yaml" <<'YAML'
id: arc-102
slug: fresh
name: "fresh arc"
status: in-progress
anchor_task: T-1002
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1002-stub.md" <<'MD'
---
id: T-1002
name: stub
arc_id: fresh
---
MD
    cd "$TEST_ROOT"
    git add .
    git commit -q -m "fresh commit"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"in-progress arc"*"30 days"* ]] || [[ "$output" == *"fresh"*"30 days"* ]]
    [[ "$output" != *"no task commits"* ]]
}

# --- silent on closed arcs ---

@test "T-1855: closed arc never warns (regardless of commit recency)" {
    cat > "$TEST_ROOT/.context/arcs/done.yaml" <<'YAML'
id: arc-103
slug: done
name: "closed arc"
status: closed
anchor_task: T-1003
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1003-stub.md" <<'MD'
---
id: T-1003
name: stub
arc_id: done
---
MD
    cd "$TEST_ROOT"
    git add .
    GIT_AUTHOR_DATE="2025-01-01T00:00:00Z" GIT_COMMITTER_DATE="2025-01-01T00:00:00Z" \
        git commit -q -m "old commit" --date="2025-01-01T00:00:00Z"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"'done'"*"no task commits"* ]]
}

# --- zero-population arcs skip silently ---

@test "T-1855: in-progress arc with no matching tasks → skip (not WARN)" {
    cat > "$TEST_ROOT/.context/arcs/empty.yaml" <<'YAML'
id: arc-104
slug: empty
name: "empty arc"
status: in-progress
anchor_task: T-1004
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1004-stub.md" <<'MD'
---
id: T-1004
name: stub
---
MD
    cd "$TEST_ROOT"
    git add .
    git commit -q -m "init"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"'empty'"*"no task commits"* ]]
}

# --- arc_id matching: arc-NNN form also recognised ---

@test "T-1855: arc_id given as arc-NNN matches when arc id is arc-NNN" {
    cat > "$TEST_ROOT/.context/arcs/byid.yaml" <<'YAML'
id: arc-105
slug: byid
name: "byid arc"
status: in-progress
anchor_task: T-1005
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1005-stub.md" <<'MD'
---
id: T-1005
name: stub
arc_id: arc-105
---
MD
    cd "$TEST_ROOT"
    git add .
    GIT_AUTHOR_DATE="2025-01-01T00:00:00Z" GIT_COMMITTER_DATE="2025-01-01T00:00:00Z" \
        git commit -q -m "old commit" --date="2025-01-01T00:00:00Z"
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    # arc-NNN form matched → arc treated as having population → stale check fires
    [[ "$output" == *"byid"* ]]
    [[ "$output" == *"no task commits"* ]]
}

# --- threshold configurable ---

@test "T-1855: FW_STALE_ARC_DAYS=3650 makes stale arcs pass (long threshold)" {
    cat > "$TEST_ROOT/.context/arcs/longt.yaml" <<'YAML'
id: arc-106
slug: longt
name: "long threshold arc"
status: in-progress
anchor_task: T-1006
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1006-stub.md" <<'MD'
---
id: T-1006
name: stub
arc_id: longt
---
MD
    cd "$TEST_ROOT"
    git add .
    GIT_AUTHOR_DATE="2025-01-01T00:00:00Z" GIT_COMMITTER_DATE="2025-01-01T00:00:00Z" \
        git commit -q -m "old commit" --date="2025-01-01T00:00:00Z"
    FW_STALE_ARC_DAYS=3650 run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"'longt'"*"no task commits"* ]]
}

# --- sanity ---

@test "T-1855: audit.sh parses cleanly under bash -n" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}
