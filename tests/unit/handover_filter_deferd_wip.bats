#!/usr/bin/env bats
# T-1619 — handover Work-in-Progress loop must skip DEFER'd inceptions.
# Per T-1617's GO outcome: DEFER means "park for later, not done" — these
# tasks must not appear under "Work in Progress" / horizon: now. They DO
# remain in .tasks/active/ for audit traceability and surface in T-1517's
# "Deferred Inceptions — Watching for Recurrence" section instead.
#
# Canonical witness: T-1611 (DEFER'd 2026-04-30T08:48Z) was pinned in WIP
# in LATEST.md until this fix landed.

load ../test_helper

# ---- Source-level invariant ----

@test "handover.sh skips DEFER'd inceptions in WIP loop (T-1619)" {
    # Pattern pinned: workflow_type=inception AND Decision=DEFER short-circuits the WIP loop.
    grep -q "if wf == 'inception' and dec == 'DEFER':" \
        "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "T-1619 rationale comment present (T-1619)" {
    grep -q 'T-1619' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh captures Decision in the data tuple (T-1619)" {
    # The first-pass collector must read **Decision** and store it for the WIP loop
    # to filter on. Reusing the captured value avoids a second per-task file read
    # (the stale 5-tuple loop did exactly that for T-1517's section).
    grep -qE "Decision\\\\\\*\\\\\\*:\\\\s\\*\\(GO\\|NO-GO\\|DEFER\\)" \
        "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

# ---- Behavioural ----
# T-4380: these run the SHIPPED Work-in-Progress block, cut out of handover.sh,
# against fixture tasks. They used to run a Python copy of the loop, which stayed
# green when the DEFER skip in handover.sh was disabled.

# wip_block: print the Python source of the WIP renderer. It starts at the
# heredoc that follows "# Add active tasks sorted by horizon" and stops before the
# partial-complete footer (the later Deferred-Inceptions section lists DEFER'd
# inceptions on purpose and is not under test).
wip_block() {
    awk '/^# Add active tasks sorted by horizon/{s=1; next}
         s && !f && /python3 << .PYEOF./{f=1; next}
         f && /^# T-2160: single bottom footer/{exit}
         f' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

# run_wip: render WIP for the fixture tasks in $TEST_TEMP_DIR/fixture/active and
# print the task ids that appear under "### T-...:" headings, comma-joined.
run_wip() {
    wip_block > "$TEST_TEMP_DIR/wip.py"
    [ -s "$TEST_TEMP_DIR/wip.py" ] || { echo "WIP block extraction empty - did it move?" >&2; return 1; }
    grep -q "dec == 'DEFER'" "$TEST_TEMP_DIR/wip.py" || { echo "extraction lost the DEFER filter" >&2; return 1; }
    TASKS_DIR_PY="$TEST_TEMP_DIR/fixture" WT_URL_PY="" PROJECT_ROOT_PY="$TEST_TEMP_DIR" \
        HANDOVER_DIGEST=0 DIGEST_TOP_N=50 python3 "$TEST_TEMP_DIR/wip.py" \
        | sed -n 's/^### \(T-[A-Z0-9]*\):.*/\1/p' | paste -sd, -
}

@test "DEFER'd inception is NOT printed in WIP (T-1619)" {
    # Fixture: one DEFER'd inception, one normal build task. WIP loop must
    # emit the build task and skip the DEFER'd inception.
    mkdir -p "$TEST_TEMP_DIR/fixture/active"
    cat > "$TEST_TEMP_DIR/fixture/active/T-D01-deferred-inception.md" <<'EOF'
---
id: T-D01
name: "Deferred inception"
status: started-work
workflow_type: inception
owner: agent
horizon: now
---

# T-D01

## Recommendation

**Recommendation:** DEFER

## Decision

**Decision**: DEFER
EOF
    cat > "$TEST_TEMP_DIR/fixture/active/T-B01-active-build.md" <<'EOF'
---
id: T-B01
name: "Active build"
status: started-work
workflow_type: build
owner: agent
horizon: now
---

# T-B01
EOF

    run run_wip
    [ "$status" -eq 0 ]
    [ "$output" = "T-B01" ]
}

@test "DEFER'd build task IS printed (only inceptions filtered) (T-1619)" {
    # Edge: a regular build task with a DEFER recommendation (not a decision)
    # must still appear in WIP. The filter is workflow_type-aware on purpose.
    mkdir -p "$TEST_TEMP_DIR/fixture/active"
    cat > "$TEST_TEMP_DIR/fixture/active/T-B02-deferred-build.md" <<'EOF'
---
id: T-B02
name: "Build with DEFER recommendation but no Decision"
status: started-work
workflow_type: build
owner: agent
horizon: now
---

## Recommendation

**Recommendation:** DEFER
EOF

    run run_wip
    [ "$status" -eq 0 ]
    [ "$output" = "T-B02" ]
}

@test "GO inception in flight IS still printed in WIP (T-1619)" {
    # Edge: an inception that has a GO decision but hasn't been swept to
    # completed/ yet is in-flight, NOT parked. Must still appear in WIP.
    mkdir -p "$TEST_TEMP_DIR/fixture/active"
    cat > "$TEST_TEMP_DIR/fixture/active/T-G01-go-inception.md" <<'EOF'
---
id: T-G01
name: "GO inception, not yet swept"
status: started-work
workflow_type: inception
owner: agent
horizon: now
---

## Decision

**Decision**: GO
EOF

    run run_wip
    [ "$status" -eq 0 ]
    [ "$output" = "T-G01" ]
}

# ---- Sanity ----

@test "handover.sh parses (bash -n) after T-1619 fix" {
    bash -n "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}
