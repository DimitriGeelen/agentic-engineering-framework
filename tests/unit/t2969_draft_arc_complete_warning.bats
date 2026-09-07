#!/usr/bin/env bats
# T-2969 — a draft arc whose constituent tasks are ALL work-completed has no
# path to closure ('fw arc close' requires in-progress — lib/arc.sh:665) and,
# before this task, nothing reported it. The stale-arc check (T-1855) is
# silent on draft arcs BY DESIGN — draft-with-no-activity is backlog, not
# stall, a different question over a different population. This suite pins
# the draft-complete WARN across the three populations that distinguish
# it from that always-answers trap: complete (WARN), incomplete (silent),
# and zero-population (silent — 0/0 is vacuously "all complete" and would
# fire on every empty draft otherwise) — plus the in-progress control.
#
# COUNTERFACTUAL (measured by running this same suite against the pre-T-2969
# audit.sh, i.e. `git stash` of the agents/audit/audit.sh change):
#   All fixtures — complete, incomplete, empty — produced ZERO output
#   matching "is draft with all". No draft-arc-completion check existed at
#   all, so the complete-population leg (the one this task exists to fix)
#   went red for the right reason (feature absent), and the other legs
#   were vacuously green (nothing to warn about because nothing warned about
#   anything). That vacuous-green shape is exactly why this suite pins all
#   populations together rather than just the positive case — a suite of
#   the positive leg alone cannot distinguish "correctly silent" from
#   "silent because the whole check is missing".
#
# HERMETIC REDESIGN (T-2969 close-out; measured 2026-09-07):
#   The original suite ran one full `--section structure` audit PER TEST with
#   FW_AUDIT_TIMEOUT=120. A scratch-scoped structure audit takes ~3m4s on this
#   host — it runs the framework's own invariant/lint sub-suites against
#   FRAMEWORK_ROOT regardless of the scratch PROJECT_ROOT — so every test died
#   at the 120s watchdog with exit 124 and `[ "$status" -le 1 ]` went red for
#   a reason that had nothing to do with the arc check. (First misdiagnosed as
#   exit-75 lock contention; disproved — the fixture's CONTEXT_DIR scopes the
#   lock to the scratch dir.) Two structural consequences drawn here:
#     1. ONE audit run in setup_file over a scratch repo carrying ALL fixture
#        arcs, with a watchdog sized to measured runtime ×3; per-population
#        tests assert on the captured output.
#     2. NO assertion on the audit's overall exit code beyond "not killed and
#        not lock-contended": the structure audit's verdict couples to the
#        LIVE framework tree's invariant state (exit 2 whenever any unrelated
#        invariant is RED), which is not this suite's subject. The positive
#        WARN assertion in the first test is the vacuity guard — if the audit
#        died before reaching the arc check, that test fails.

SUITE_OUT=""
SUITE_STATUS_FILE=""

setup_file() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || return 0   # per-test setup() skips with the message
    command -v git >/dev/null 2>&1 || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    TEST_ROOT="$(mktemp -d)"
    export T2969_TEST_ROOT="$TEST_ROOT"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.tasks/active" \
             "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.tasks/templates" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/locks" \
             "$TEST_ROOT/.context/audits"

    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    # population 1: draft, all constituents work-completed → WARN
    cat > "$TEST_ROOT/.context/arcs/complete.yaml" <<'YAML'
id: arc-201
slug: complete
name: "all done, still draft"
status: draft
anchor_task: T-2001
YAML
    printf -- '---\nid: T-2001\nname: stub\narc_id: complete\n---\n' > "$TEST_ROOT/.tasks/completed/T-2001-stub.md"
    printf -- '---\nid: T-2002\nname: stub\narc_id: complete\n---\n' > "$TEST_ROOT/.tasks/completed/T-2002-stub.md"

    # population 2: draft, one constituent still active → silent
    cat > "$TEST_ROOT/.context/arcs/incomplete.yaml" <<'YAML'
id: arc-202
slug: incomplete
name: "one still open"
status: draft
anchor_task: T-2003
YAML
    printf -- '---\nid: T-2003\nname: stub\narc_id: incomplete\n---\n' > "$TEST_ROOT/.tasks/completed/T-2003-stub.md"
    printf -- '---\nid: T-2004\nname: stub\narc_id: incomplete\n---\n' > "$TEST_ROOT/.tasks/active/T-2004-stub.md"

    # population 3: draft, zero constituents → silent (not vacuously complete)
    cat > "$TEST_ROOT/.context/arcs/empty.yaml" <<'YAML'
id: arc-203
slug: emptydraft
name: "nothing assigned yet"
status: draft
anchor_task: T-2005
YAML
    printf -- '---\nid: T-2005\nname: stub\n---\n' > "$TEST_ROOT/.tasks/active/T-2005-stub.md"

    # control: in-progress arc, all complete → out of scope (stale-arc owns it)
    cat > "$TEST_ROOT/.context/arcs/inprog.yaml" <<'YAML'
id: arc-204
slug: inprog
name: "in progress, all done"
status: in-progress
anchor_task: T-2006
YAML
    printf -- '---\nid: T-2006\nname: stub\narc_id: inprog\n---\n' > "$TEST_ROOT/.tasks/completed/T-2006-stub.md"

    ( cd "$TEST_ROOT" &&
      git init -q &&
      git config user.email "test@local" &&
      git config user.name "test" &&
      git add . &&
      git commit -q -m "init" )

    # One audit run for the whole suite. Watchdog: measured ~185s scratch
    # runtime ×3. env -u strips the parent shell's derivation sentinel so
    # paths.sh re-derives cleanly from the scratch PROJECT_ROOT (T-2289).
    local audit_status=0
    env -u _FW_PATHS_DERIVED_BY \
        PROJECT_ROOT="$TEST_ROOT" CONTEXT_DIR="$TEST_ROOT/.context" \
        FW_AUDIT_TIMEOUT=600 \
        bash "$AUDIT" --section structure \
        > "$TEST_ROOT/audit-output.txt" 2>&1 || audit_status=$?
    echo "$audit_status" > "$TEST_ROOT/audit-status.txt"
}

teardown_file() {
    [ -n "${T2969_TEST_ROOT:-}" ] && rm -rf "$T2969_TEST_ROOT" 2>/dev/null
}

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/agents/audit/audit.sh" ] || skip "audit.sh not found"
    command -v git >/dev/null 2>&1 || skip "git not on PATH"
    command -v python3 >/dev/null 2>&1 || skip "python3 not on PATH"
    [ -n "${T2969_TEST_ROOT:-}" ] || skip "setup_file did not run"
    [ -f "$T2969_TEST_ROOT/audit-output.txt" ] || skip "setup_file audit did not produce output"
    OUTPUT_FILE="$T2969_TEST_ROOT/audit-output.txt"
    AUDIT_STATUS="$(cat "$T2969_TEST_ROOT/audit-status.txt" 2>/dev/null)"
}

# ── the audit itself completed (not killed, not contended) ───────────────────

@test "T-2969: scratch audit ran to completion (no watchdog kill, no lock contention)" {
    # 124 = watchdog TERM (the original suite's actual failure mode);
    # 75 = lock contention. Anything else (0/1/2) is a completed run whose
    # verdict may legitimately reflect LIVE-tree invariant state — out of
    # scope here (see header note 2).
    [ "$AUDIT_STATUS" != "124" ]
    [ "$AUDIT_STATUS" != "75" ]
}

# ── population 1: all constituents work-completed → WARN ─────────────────────

@test "T-2969: draft arc with all constituents work-completed → WARN" {
    grep -q "'complete'.*draft with all" "$OUTPUT_FILE"
    grep -q "2 constituent" "$OUTPUT_FILE"
    grep -q "fw arc start complete" "$OUTPUT_FILE"
}

# ── population 2: some constituents still active → no WARN ───────────────────

@test "T-2969: draft arc with an unfinished constituent → no WARN" {
    if grep -q "'incomplete'.*draft with all" "$OUTPUT_FILE"; then
        echo "FAIL: draft-complete WARN fired on an arc with an active constituent" >&2
        return 1
    fi
}

# ── population 3: zero constituents → no WARN (not vacuously complete) ───────

@test "T-2969: draft arc with zero constituents → no WARN" {
    if grep -q "'emptydraft'.*draft with all" "$OUTPUT_FILE"; then
        echo "FAIL: draft-complete WARN fired on a zero-population draft (0/0 vacuity)" >&2
        return 1
    fi
}

# ── in-progress arcs are out of scope (stale-arc owns them) ──────────────────

@test "T-2969: in-progress arc with all constituents complete → no draft-complete WARN" {
    if grep -q "'inprog'.*draft with all" "$OUTPUT_FILE"; then
        echo "FAIL: draft-complete WARN fired on an in-progress arc" >&2
        return 1
    fi
}

# ── sanity ───────────────────────────────────────────────────────────────────

@test "T-2969: audit.sh parses cleanly under bash -n" {
    run bash -n "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}
