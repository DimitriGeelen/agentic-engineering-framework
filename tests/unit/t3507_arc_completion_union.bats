#!/usr/bin/env bats
# T-3507 — the arc-completion-ratio check must UNION constituent_tasks: with live
# membership, not use the live scan as a fallback.
#
# Closes OBS-545. `agents/audit/audit.sh` read the arc's deprecated
# `constituent_tasks:` cache and ran the live scan only `if not items`. The comment
# above that guard claimed a union with the arc_id: scan (T-1875) — and the union
# was real, but it lived INSIDE the fallback branch, so it unioned only with itself.
# Any arc with a non-empty cache had completed/total computed over the cache alone.
#
# MEASURED on the live corpus before the change:
#   orchestrator-rethink      31 of 124 members     (reported "31/31")
#   watchtower-redesign        1 of  70 members     (reported  "1/1")
#   project-shape-resilience   6 of  18 members     (reported  "5/6")
#   174 task-arc relationships invisible to the check.
# After: 122/124, 70/70, 17/18. NO verdict flipped — all three cross the 0.80
# threshold either way — so the defect was latent and its live cost was telling the
# operator "31/31 tasks completed" about an arc with 124 members, inside a WARN they
# are expected to act on.
#
# COUNTERFACTUAL, the thing that makes the union leg meaningful: population 1 below
# carries a NON-EMPTY short constituent_tasks: plus extra tag-only and arc_id:
# members. Pre-fix that arc reported 1/1 (cache only); post-fix it reports 3/3. An
# existing fixture cannot catch this class because every existing fixture either
# omits constituent_tasks: entirely (so the fallback fired and the answer was
# accidentally right) or lists every member (so cache and scan agree).
#
# HARNESS: one audit run in setup_file over a scratch repo carrying all fixture
# arcs, per-population assertions on the captured output — the hermetic shape
# T-2969 arrived at after its per-test runs died on the watchdog. Uses
# --section arc-completion rather than --section structure: it is the section under
# test and it does not drag the framework's own invariant suites in.

setup_file() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || return 0
    command -v git >/dev/null 2>&1 || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    TEST_ROOT="$(mktemp -d)"
    export T3507_TEST_ROOT="$TEST_ROOT"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.tasks/active" \
             "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.tasks/templates" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" \
             "$TEST_ROOT/.context/audits"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    _done() {  # a work-completed task: $1 id, $2 extra frontmatter line
        printf -- '---\nid: %s\nname: stub\nstatus: work-completed\n%s---\nbody\n' \
            "$1" "$2" > "$TEST_ROOT/.tasks/completed/$1-stub.md"
    }

    # ── population 1: NON-EMPTY short cache + members the cache omits ──────────
    # THE UNION LEG. Pre-fix: 1/1. Post-fix: 3/3.
    cat > "$TEST_ROOT/.context/arcs/unionarc.yaml" <<'YAML'
id: arc-301
slug: unionarc
name: "short cache, three real members"
status: in-progress
constituent_tasks: ["T-9001"]
YAML
    # T-9001 is in the cache and carries NO membership field — it proves the union
    # KEEPS the cache rather than replacing it with the scan. A task whose arc_id:
    # was lost must not silently shrink the arc's historical denominator.
    _done T-9001 ""
    _done T-9002 "arc_id: unionarc
"
    _done T-9003 "tags: [arc:unionarc]
"

    # ── population 2: empty cache — the T-1813 path the fallback existed for ───
    cat > "$TEST_ROOT/.context/arcs/emptylist.yaml" <<'YAML'
id: arc-302
slug: emptylist
name: "no cache at all"
status: in-progress
YAML
    _done T-9004 "arc_id: emptylist
"
    _done T-9005 "tags: [arc:emptylist]
"

    # ── population 3: CONTROL — cache already equals scan membership ───────────
    # Must be byte-identical before and after. Without this leg, "the numbers
    # changed" is indistinguishable from "the check changed its mind".
    cat > "$TEST_ROOT/.context/arcs/exactarc.yaml" <<'YAML'
id: arc-303
slug: exactarc
name: "cache matches reality"
status: in-progress
constituent_tasks: ["T-9006"]
YAML
    _done T-9006 "arc_id: exactarc
"

    ( cd "$TEST_ROOT" &&
      git init -q &&
      git config user.email "test@local" &&
      git config user.name "test" &&
      git add . &&
      git commit -q -m "init" )

    local audit_status=0
    env -u _FW_PATHS_DERIVED_BY \
        PROJECT_ROOT="$TEST_ROOT" CONTEXT_DIR="$TEST_ROOT/.context" \
        FW_AUDIT_TIMEOUT=300 \
        bash "$AUDIT" --section arc-completion \
        > "$TEST_ROOT/audit-output.txt" 2>&1 || audit_status=$?
    echo "$audit_status" > "$TEST_ROOT/audit-status.txt"
}

teardown_file() {
    [ -n "${T3507_TEST_ROOT:-}" ] && rm -rf "$T3507_TEST_ROOT" 2>/dev/null
}

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/agents/audit/audit.sh" ] || skip "audit.sh not found"
    command -v git >/dev/null 2>&1 || skip "git not on PATH"
    command -v python3 >/dev/null 2>&1 || skip "python3 not on PATH"
    [ -n "${T3507_TEST_ROOT:-}" ] || skip "setup_file did not run"
    [ -f "$T3507_TEST_ROOT/audit-output.txt" ] || skip "setup_file audit did not produce output"
    OUTPUT_FILE="$T3507_TEST_ROOT/audit-output.txt"
    AUDIT_STATUS="$(cat "$T3507_TEST_ROOT/audit-status.txt" 2>/dev/null)"
}

# ── the run happened at all (vacuity guard) ─────────────────────────────────

@test "t3507: scratch audit ran to completion (no watchdog kill, no lock contention)" {
    # 124 = watchdog TERM, 75 = lock contention. Every 'must not contain'
    # assertion below would pass vacuously against an audit that never ran.
    [ "$AUDIT_STATUS" != "124" ]
    [ "$AUDIT_STATUS" != "75" ]
    run grep -cE "Arc 'arc-30[123]'" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 3 ]
}

# ── THE UNION LEG ───────────────────────────────────────────────────────────

@test "t3507: a non-empty cache is UNIONED with live membership, not used alone" {
    # Pre-fix this line read "1/1" — the cache alone. This assertion is the
    # counterfactual: it fails against the fallback implementation.
    run grep -F "Arc 'arc-301': 3/3" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
}

@test "t3507: the cache is kept, not replaced — a stored task with no arc_id still counts" {
    # T-9001 is listed in constituent_tasks: and carries no membership field. If
    # the fix had REPLACED the cache with the scan instead of unioning, the
    # denominator would be 2 and this arc's history would have silently shrunk.
    run grep -F "Arc 'arc-301': 3/3" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
    run grep -F "Arc 'arc-301': 2/2" "$OUTPUT_FILE"
    [ "$status" -ne 0 ]
}

# ── the path the fallback was originally added for must not regress ─────────

@test "t3507: an empty cache still finds tag and arc_id members (T-1813)" {
    run grep -F "Arc 'arc-302': 2/2" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
}

# ── THE CONTROL LEG ─────────────────────────────────────────────────────────

@test "t3507: an arc whose cache already matches its membership is unchanged" {
    # Identical before and after. This is what separates "fixed the denominator"
    # from "changed how the ratio is computed".
    run grep -F "Arc 'arc-303': 1/1" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
}

# ── degradation is announced, never silent ──────────────────────────────────

@test "t3507: the canonical helper loaded — no DEGRADED banner on a healthy tree" {
    # The banner exists for the import-failure path. Its ABSENCE here is what
    # proves the delegation actually works rather than silently falling back.
    run grep -F "Arc-completion membership DEGRADED" "$OUTPUT_FILE"
    [ "$status" -ne 0 ]
}

@test "t3507: the degraded banner is wired and names the consequence" {
    # Asserted on the source: the failure path cannot be triggered from a healthy
    # fixture, and an unreachable warning is indistinguishable from a missing one.
    run grep -F "Arc-completion membership DEGRADED to constituent_tasks: only" \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
    run grep -F "may under-count" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

# ── the fallback guard must not come back ───────────────────────────────────

@test "t3507: the scan is no longer gated on an empty cache" {
    run grep -nE '^if not items and arc_slug:' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -ne 0 ]
}

@test "t3507: membership is delegated, not re-derived inline" {
    run grep -F "from arc_membership import scan_tasks_by_arc_membership" \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

@test "t3507: the corpus is walked once per run, not once per arc" {
    # The index is built before the loop and looked up per arc. Deleting the
    # fallback guard without this would have fired a full 3,484-file walk for each
    # of ~20 arcs — the O(arcs x tasks) trap T-3503 removed from `fw bvp arcs`.
    run grep -F 'ARC_MEMBERSHIP_MAP="$(mktemp)"' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
    run grep -F 'rm -f "$ARC_MEMBERSHIP_MAP"' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}
