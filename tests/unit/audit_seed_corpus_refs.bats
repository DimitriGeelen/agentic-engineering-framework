#!/usr/bin/env bats
# T-2980 (arc-017, onboarding-curriculum): seed → corpus-map reference resolution.
#
# The onboarding seeds route to corpus maps instead of embedding their content
# (arc-017's design principle). Each `## For the Operator` section ends with
# `fw corpus explain <id>` — a command the framework tells a first-time operator
# to run. If that id stops resolving, they get a tool error in their first hour.
#
# FAIL rather than WARN, unlike the anchor_task sibling in
# audit_anchor_task_existence.bats: the seeds are copied into every project by
# `fw init`, so a dangling reference ships to new installs and is discovered one
# confused operator at a time. Deterministic, operator-facing, one-line fix.
#
# The last test is the one that matters most over time: it checks the audit's
# regex against the REAL seeds in this repo, not against the fixture syntax this
# file happens to write. A scan that silently stops matching the seeds' actual
# wording would leave every other test in here green.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || skip "audit.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/lib/seeds/tasks/greenfield" \
             "$TEST_ROOT/.context/designer/projects/aef-real-map" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" \
             "$TEST_ROOT/.context/audits" "$TEST_ROOT/.tasks/active" \
             "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.tasks/templates"

    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    export FW_AUDIT_TIMEOUT=120
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# --- happy path: reference resolves ---

@test "T-2980: seed referencing an existing map → PASS with the count" {
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-001-x.md" <<'MD'
## For the Operator
**Go deeper:** `fw corpus explain aef-real-map` — what this step is really doing.
MD
    run "$AUDIT" --section structure
    [[ "$output" == *"All 1 onboarding-seed corpus references resolve"* ]]
}

# --- failure path: reference dangles ---

@test "T-2980: seed referencing a missing map → FAIL naming file and id" {
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-001-x.md" <<'MD'
## For the Operator
**Go deeper:** `fw corpus explain aef-ghost-map` — this map does not exist.
MD
    run "$AUDIT" --section structure
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"aef-ghost-map"* ]]
    [[ "$output" == *"T-001-x.md"* ]]
}

@test "T-2980: a dangling reference is FAIL tier, not WARN — audit exits 2" {
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-001-x.md" <<'MD'
**Go deeper:** `fw corpus explain aef-ghost-map` — dangling.
MD
    run "$AUDIT" --section structure
    # The tier IS the behaviour under test: WARN would exit <=1 and the seed
    # would keep shipping to new installs with nothing blocking it.
    [ "$status" -eq 2 ]
}

@test "T-2980: FAIL message offers both ways out, not just 'it is broken'" {
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-001-x.md" <<'MD'
**Go deeper:** `fw corpus explain aef-ghost-map` — dangling.
MD
    run "$AUDIT" --section structure
    # Stale reference vs genuinely-missing map are different repairs, and the
    # reader cannot tell which they have from the failure alone.
    [[ "$output" == *"stale"* ]]
    [[ "$output" == *"missing"* ]]
}

# --- mix: only the dangling one is reported ---

@test "T-2980: valid + dangling → only the dangling one fails" {
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-001-good.md" <<'MD'
**Go deeper:** `fw corpus explain aef-real-map` — resolves fine.
MD
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-002-bad.md" <<'MD'
**Go deeper:** `fw corpus explain aef-ghost-map` — dangling.
MD
    run "$AUDIT" --section structure
    [[ "$output" == *"aef-ghost-map"* ]]
    [[ "$output" != *"aef-real-map"*"not in the store"* ]]
}

# --- silent when there is nothing to check ---

@test "T-2980: no seed references → no PASS line (nothing was checked)" {
    cat > "$TEST_ROOT/lib/seeds/tasks/greenfield/T-001-x.md" <<'MD'
## For the Operator
Nothing routes anywhere from here.
MD
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"onboarding-seed corpus references"* ]]
}

# --- the check that guards the other checks ---

@test "T-2980: the audit regex matches the syntax the REAL seeds use" {
    real_seeds="$FRAMEWORK_ROOT/lib/seeds/tasks"
    [ -d "$real_seeds" ] || skip "no seed directory in this checkout"

    # Every seed file that mentions 'corpus explain' at all must yield at least
    # one id under the audit's own pattern. If a future seed writes the
    # reference in a form the scan cannot parse, that file goes unchecked while
    # every fixture-based test above stays green — this is the only test that
    # would notice.
    unmatched=""
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if ! grep -qoE "corpus explain [a-z0-9][a-z0-9-]*" "$f"; then
            unmatched="$unmatched $f"
        fi
    done <<< "$(grep -rl --include='*.md' "corpus explain" "$real_seeds" 2>/dev/null)"

    [ -z "$unmatched" ] || {
        echo "seed(s) mention 'corpus explain' in a form the audit scan misses:$unmatched"
        false
    }
}

@test "T-2980: every real seed reference resolves in this checkout" {
    real_seeds="$FRAMEWORK_ROOT/lib/seeds/tasks"
    store="$FRAMEWORK_ROOT/.context/designer/projects"
    [ -d "$real_seeds" ] || skip "no seed directory in this checkout"
    [ -d "$store" ] || skip "no designer store in this checkout"

    missing=""
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        id="${ref##* }"
        [ -d "$store/$id" ] || missing="$missing $id"
    done <<< "$(grep -rhoE --include='*.md' "corpus explain [a-z0-9][a-z0-9-]*" "$real_seeds" 2>/dev/null)"

    [ -z "$missing" ] || {
        echo "seed reference(s) do not resolve:$missing"
        false
    }
}
