#!/usr/bin/env bats
# T-3073: C-001 research-artefact rail covers inceptions being DECIDED, not only
# inceptions being WORKED.
#
# Before this task the set was `workflow_type == "inception" and status ==
# "started-work"`. An inception carrying a substantive `## Recommendation` has
# finished researching — it is asking the operator for a go/no-go — and nothing
# forces a status change to file one, so five of the six pending decisions
# measured on 2026-08-18 sat at `status: captured`, invisible to the rail built
# to catch exactly them.
#
# Every assertion here is two-sided (A3, L-616): a known-missing fixture IS
# reported AND a known-satisfied fixture is NOT. Two empty sets are equal, so a
# passing test over an empty set proves nothing.
#
# Mutation control (A5): reverting active-task-scan.py's Loop 5 guard to
# `status == "started-work"` must turn the recommendation-bearing tests red
# while leaving the started-work regression test green.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTIVE_SCAN="$FRAMEWORK_ROOT/agents/audit/active-task-scan.py"

setup() {
    export TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/reports"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# IDs the scan reports as type=missing.
_missing_ids() {
    python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps([i['id'] for i in d['research']['issues'] if i['type']=='missing']))"
}

# One field out of the research block.
_field() {
    python3 -c "import sys,json; print(json.load(sys.stdin)['research']['$1'])"
}

# Reason recorded against a given task id (empty when not reported).
_reason_for() {
    python3 -c "import sys,json; d=json.load(sys.stdin); print(next((i.get('reason','') for i in d['research']['issues'] if i['id']=='$1'), ''))"
}

# A captured inception carrying a real verdict, plus the template's own commented
# example block — the comment must not be what makes it qualify.
_write_recommending_inception() {
    local id="$1" status="$2" path="$3"
    cat > "$path" << EOF
---
id: $id
name: "Recommending inception"
description: "An inception that has finished researching and wants a decision"
status: $status
workflow_type: inception
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-10T00:00:00Z
---
# $id

## Context

Explored the thing.

## Recommendation

<!-- **Recommendation:** GO / NO-GO / DEFER  (template placeholder, must not count) -->

**Recommendation:** DEFER
**Rationale:** The dependency is unresolved until the upstream ships.
**Evidence:**
- Upstream issue still open

## Updates

### 2026-08-01T00:00:00Z — created
EOF
}

# A captured inception with NOTHING but the template's commented placeholder.
_write_template_only_inception() {
    local id="$1" path="$2"
    cat > "$path" << EOF
---
id: $id
name: "Freshly captured inception"
description: "Nobody has worked this yet and it makes no recommendation"
status: captured
workflow_type: inception
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-01T00:00:00Z
---
# $id

## Context

Not started.

## Recommendation

<!--
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence)
-->

## Updates

### 2026-08-01T00:00:00Z — created
EOF
}

@test "T-3073 A1/A3: captured inception WITH a recommendation and NO artefact IS reported" {
    _write_recommending_inception "T-9101" "captured" "$TEST_DIR/active/T-9101-recommending.md"

    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _missing_ids)
    [[ "$ids" == *"T-9101"* ]]
}

@test "T-3073 A3: positive control — same fixture WITH an artefact is NOT reported" {
    _write_recommending_inception "T-9102" "captured" "$TEST_DIR/active/T-9102-recommending.md"
    echo "# research" > "$TEST_DIR/reports/T-9102-the-research.md"

    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _missing_ids)
    [[ "$ids" != *"T-9102"* ]]
    # And the satisfied case is genuinely in the widened set, not merely absent:
    # it counts toward the awaiting-decision population.
    [ "$(echo "$output" | _field inception_recommendation)" -eq 1 ]
}

@test "T-3073 A2: captured inception with only the template comment stays silent" {
    _write_template_only_inception "T-9103" "$TEST_DIR/active/T-9103-fresh.md"

    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _missing_ids)
    [[ "$ids" != *"T-9103"* ]]
    [ "$(echo "$output" | _field inception_recommendation)" -eq 0 ]
    [ "$(echo "$output" | _field inception_active)" -eq 0 ]
}

@test "T-3073: started-work inception without artefact is still reported (no regression)" {
    cat > "$TEST_DIR/active/T-9104-worked.md" << 'EOF'
---
id: T-9104
name: "Worked inception"
description: "Being worked, no recommendation filed yet"
status: started-work
workflow_type: inception
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-10T00:00:00Z
---
# T-9104

## Context

Mid-exploration.

## Updates

### 2026-08-01T00:00:00Z — created
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _missing_ids)
    [[ "$ids" == *"T-9104"* ]]
    [ "$(echo "$output" | _reason_for T-9104)" = "started-work" ]
}

@test "T-3073 A4: the two populations are counted and labelled separately" {
    # 1 started-work missing, 1 awaiting-decision missing, 1 awaiting-decision satisfied.
    cat > "$TEST_DIR/active/T-9105-worked.md" << 'EOF'
---
id: T-9105
name: "Worked inception"
description: "Being worked, no artefact"
status: started-work
workflow_type: inception
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-10T00:00:00Z
---
# T-9105

## Context

Mid-exploration.

## Updates

### 2026-08-01T00:00:00Z — created
EOF
    _write_recommending_inception "T-9106" "captured" "$TEST_DIR/active/T-9106-deciding.md"
    _write_recommending_inception "T-9107" "captured" "$TEST_DIR/active/T-9107-deciding-ok.md"
    echo "# research" > "$TEST_DIR/reports/T-9107-the-research.md"

    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]

    [ "$(echo "$output" | _field inception_active)" -eq 1 ]
    [ "$(echo "$output" | _field inception_recommendation)" -eq 2 ]
    [ "$(echo "$output" | _field c001_missing_started)" -eq 1 ]
    [ "$(echo "$output" | _field c001_missing_recommendation)" -eq 1 ]
    [ "$(echo "$output" | _field c001_missing)" -eq 2 ]

    # Each reported task carries the population it came from.
    [ "$(echo "$output" | _reason_for T-9105)" = "started-work" ]
    [ "$(echo "$output" | _reason_for T-9106)" = "recommendation" ]
}

@test "T-3073 A1: a started-work inception is never double-counted as awaiting-decision" {
    _write_recommending_inception "T-9108" "started-work" "$TEST_DIR/active/T-9108-both.md"

    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | _field inception_active)" -eq 1 ]
    [ "$(echo "$output" | _field inception_recommendation)" -eq 0 ]
    [ "$(echo "$output" | _field c001_missing)" -eq 1 ]
    [ "$(echo "$output" | _reason_for T-9108)" = "started-work" ]
}

@test "T-3073: non-inception task with a recommendation is not in the set" {
    cat > "$TEST_DIR/active/T-9109-build.md" << 'EOF'
---
id: T-9109
name: "Build task with a recommendation"
description: "Partial-complete build tasks carry a Recommendation too"
status: started-work
workflow_type: build
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-10T00:00:00Z
---
# T-9109

## Recommendation

**Recommendation:** GO
**Rationale:** Agent ACs are done.

## Updates

### 2026-08-01T00:00:00Z — created
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [ "$status" -eq 0 ]
    ids=$(echo "$output" | _missing_ids)
    [[ "$ids" != *"T-9109"* ]]
    [ "$(echo "$output" | _field inception_recommendation)" -eq 0 ]
}

# ── Audit-surface tests (A4) ────────────────────────────────────────────────
#
# These run `fw audit --section oe-research` against a synthetic PROJECT_ROOT,
# never the live repo — the section writes an audit YAML, and pointing it at
# /opt/... would mutate real state on every test run.
#
# Assertions are scoped to the C-001 line itself. A bare
# `[[ "$output" == *"WARN"*"..."* ]]` passes against almost any verdict, because a
# ~40-line audit run has usually already printed a WARN somewhere above — that
# exact weakness was found by mutation testing on T-3064.

_setup_audit_project() {
    export AUDIT_ROOT="$(mktemp -d)"
    mkdir -p "$AUDIT_ROOT/.tasks/active" "$AUDIT_ROOT/.tasks/completed" \
             "$AUDIT_ROOT/docs/reports" "$AUDIT_ROOT/.context/working"
}

_run_oe_research() {
    run env PROJECT_ROOT="$AUDIT_ROOT" "$FRAMEWORK_ROOT/bin/fw" audit --section oe-research
    # Strip ANSI so assertions can anchor on the literal line.
    CLEAN=$(printf '%s\n' "$output" | sed -e 's/\x1b\[[0-9;]*m//g')
}

@test "T-3073 A4: audit labels an awaiting-decision miss as such, on its own line" {
    _setup_audit_project
    _write_recommending_inception "T-9201" "captured" "$AUDIT_ROOT/.tasks/active/T-9201-deciding.md"

    _run_oe_research
    # The finding line names the task AND its population.
    echo "$CLEAN" | grep -qE '^\[WARN\] C-001: Inception T-9201 \(recommendation\) has no research artifact'
    # The breakdown line separates the two populations rather than merging them.
    echo "$CLEAN" | grep -qE '^\[INFO\] C-001 population breakdown: 0/0 started-work missing an artefact, 1/1 awaiting-decision missing an artefact$'
    # Hygiene, not a blocker (constraint 1): C-001 never escalates to FAIL.
    if echo "$CLEAN" | grep -qE '^\[FAIL\].*C-001'; then false; fi
    rm -rf "$AUDIT_ROOT"
}

@test "T-3073 A4: audit labels a started-work miss as such, on its own line" {
    _setup_audit_project
    cat > "$AUDIT_ROOT/.tasks/active/T-9202-worked.md" << 'EOF'
---
id: T-9202
name: "Worked inception"
description: "Being worked, no artefact on disk yet"
status: started-work
workflow_type: inception
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-10T00:00:00Z
---
# T-9202

## Updates

### 2026-08-01T00:00:00Z — created
EOF
    _run_oe_research
    echo "$CLEAN" | grep -qE '^\[WARN\] C-001: Inception T-9202 \(started-work\) has no research artifact'
    echo "$CLEAN" | grep -qE '^\[INFO\] C-001 population breakdown: 1/1 started-work missing an artefact, 0/0 awaiting-decision missing an artefact$'
    rm -rf "$AUDIT_ROOT"
}

@test "T-3073 A3/A4: clean corpus passes with both population sizes named" {
    _setup_audit_project
    _write_recommending_inception "T-9203" "captured" "$AUDIT_ROOT/.tasks/active/T-9203-deciding.md"
    echo "# research" > "$AUDIT_ROOT/docs/reports/T-9203-the-research.md"

    _run_oe_research
    echo "$CLEAN" | grep -qE '^\[PASS\] C-001: All inceptions have research artifacts — 0 started-work, 1 awaiting decision$'
    if echo "$CLEAN" | grep -qE '^\[WARN\] C-001: Inception T-9203'; then false; fi
    rm -rf "$AUDIT_ROOT"
}
