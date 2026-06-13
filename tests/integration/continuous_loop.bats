#!/usr/bin/env bats
# T-2368 (arc-012 S-test): end-to-end continuous-loop integration test.
#
# Drives the REAL agents/context/post-compact-resume.sh resume hook against a
# temp PROJECT_ROOT, feeding SessionStart hook JSON on stdin and asserting on
# the emitted additionalContext JSON. This exercises the integration seam that
# the per-component unit tests (test_inject_next_directive.py, resume.bats) do
# NOT cover: post-compact-resume.sh invoking the injector, capturing its stdout,
# and folding the directive into the SessionStart output (post-compact-resume.sh
# :267-313). Closes the D-058 "shipped before substrate-verified" gap for the
# continuous-run loop.
#
# NOT covered here (by design): the `claude-fw` process auto-restart junction —
# an interactive wrapper, demonstrated operator-side per the arc headline_mechanic.
# This test covers everything up to and including the resume-side directive fold
# plus the two refusal modes (cap-termination, tier-ceiling freeze).

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
    INJECTOR="$FRAMEWORK_ROOT/agents/context/inject-next-directive.py"

    # Skip cleanly if prerequisites are unavailable (e.g. PyYAML not installed).
    [ -f "$HOOK" ] || skip "post-compact-resume.sh not found"
    [ -f "$INJECTOR" ] || skip "inject-next-directive.py not found"
    python3 -c 'import yaml' 2>/dev/null || skip "PyYAML not available"

    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working" "$PROJ/.context/handovers" "$PROJ/.tasks/active"
    # Minimal handover so the hook has something to fold (optional path).
    printf '## Where We Are\nTest fixture.\n' > "$PROJ/.context/handovers/LATEST.md"
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
}

# --- fixture helpers -------------------------------------------------------

# Write .continuous-mode.yaml with given enabled/max/ceiling/iteration.
_mode() {
    local enabled="$1" maxit="$2" ceiling="$3" iter="$4"
    cat > "$PROJ/.context/working/.continuous-mode.yaml" <<EOF
enabled: $enabled
max_iterations: $maxit
tier_ceiling: $ceiling
expires_after_seconds: 86400
current_iteration: $iter
EOF
}

# Write .next-directive.yaml. $1 = directive body, $2 (optional) = next_task ref.
_directive() {
    local body="$1" next_task="${2:-}"
    {
        echo "directive: |"
        echo "  $body"
        echo "filed_by: test"
        echo "filed_at: 2026-06-13T00:00:00Z"
        echo "expires_at: 2099-01-01T00:00:00Z"
        if [ -n "$next_task" ]; then echo "next_task: $next_task"; fi
    } > "$PROJ/.context/working/.next-directive.yaml"
}

# Write a task file carrying a cost_estimate.blast_radius (for the ceiling test).
_task_with_blast() {
    local id="$1" blast="$2"
    cat > "$PROJ/.tasks/active/${id}-fixture.md" <<EOF
---
id: $id
name: "blast fixture"
status: started-work
workflow_type: build
cost_estimate:
  blast_radius: $blast
---
# $id
EOF
}

# Run the real resume hook with given SessionStart source. Sets \$output / \$status.
_run_hook() {
    local source_tag="${1:-resume}"
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$HOOK" <<<"{\"source\":\"$source_tag\"}"
}

# Read current_iteration back out of the state file.
_iter() {
    python3 -c "import yaml,sys; print(yaml.safe_load(open('$PROJ/.context/working/.continuous-mode.yaml')).get('current_iteration'))"
}

# --- tests -----------------------------------------------------------------

@test "t1: resume injects directive and advances counter 0->1" {
    _mode true 10 5 0
    _directive "Continue the loop. No task ref here."
    _run_hook resume
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "## Next Directive (iteration 1/"
    [ "$(_iter)" -eq 1 ]
}

@test "t2: multi-cycle advances 0->1->2->3 across three resumes" {
    _mode true 10 5 0
    _directive "Continue the loop. No task ref here."
    _run_hook resume; [ "$(_iter)" -eq 1 ]
    _run_hook resume; [ "$(_iter)" -eq 2 ]
    _run_hook resume
    [ "$status" -eq 0 ]
    [ "$(_iter)" -eq 3 ]
    echo "$output" | grep -q "## Next Directive (iteration 3/"
}

@test "t3: cap-termination at max_iterations emits LOOP TERMINATED; directive withheld" {
    # current_iteration already at the cap; next resume is cap+1 -> terminated.
    _mode true 2 5 2
    _directive "Continue the loop. No task ref here."
    _run_hook resume
    [ "$status" -eq 0 ]
    # ASCII-only marker: the hook wraps the section in json.dumps(ensure_ascii=True),
    # so the em-dash in "Directive — LOOP TERMINATED" is escaped to —. Assert
    # on the ASCII substring downstream consumers actually receive.
    echo "$output" | grep -q "LOOP TERMINATED"
    # The directive itself is NOT surfaced for auto-pickup once terminated.
    ! echo "$output" | grep -q "Continue the loop. No task ref here."
    # Shipped spec (unit test test_loop_terminated_state_records_reason): the
    # counter records the over-cap attempt (new_iter = cap+1 = 3). What the cap
    # withholds is the directive, not the increment.
    [ "$(_iter)" -eq 3 ]
}

@test "t4: tier-ceiling freeze (S5) — high-blast next_task emits TIER CEILING EXCEEDED, counter frozen" {
    _mode true 10 1 0
    _task_with_blast T-9001 5
    _directive "Continue the loop." "T-9001"
    _run_hook resume
    [ "$status" -eq 0 ]
    # ASCII-only marker (json.dumps escapes the em-dash — see t3).
    echo "$output" | grep -q "TIER CEILING EXCEEDED"
    # Counter frozen at 0 (operator resumes the same iteration after sign-off).
    [ "$(_iter)" -eq 0 ]
}

@test "t5: compact source resets counter before advancing (fresh loop)" {
    # Counter at 2; a /compact must reset to 0 then advance to 1, not to 3.
    _mode true 10 5 2
    _directive "Continue the loop. No task ref here."
    _run_hook compact
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "## Next Directive (iteration 1/"
    [ "$(_iter)" -eq 1 ]
}

@test "t6: disabled continuous-mode is a no-op (no directive section, no counter change)" {
    _mode false 10 5 0
    _directive "Continue the loop. No task ref here."
    _run_hook resume
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "## Next Directive"
    [ "$(_iter)" -eq 0 ]
}
