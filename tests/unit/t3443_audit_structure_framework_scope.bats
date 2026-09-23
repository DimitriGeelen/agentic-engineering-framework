#!/usr/bin/env bats
# T-3443: `agents/audit/audit.sh --sections structure` ran two checks that are
# properties of the FRAMEWORK REPOSITORY, not of the project being audited:
# check_invariant_suite (`timeout 300 bats tests/lint/`, 110 tests) and the
# dead-negation lint over `tests/` (T-3138/T-3191). Both ran regardless of
# PROJECT_ROOT. Measured 2026-09-22: one fixture audit inside
# tests/unit/fabric_watch_pattern_fitness.bats took ~4 min; that file shells
# six such audits, needing 24+ min, and any verification line bundling it
# under `timeout 900` exited 124 on every host (T-3435's close was blocked
# twice on exactly this).
#
# The fix gates both checks on `_t3443_project_is_framework_root` (resolved
# PROJECT_ROOT == resolved FRAMEWORK_ROOT, via `pwd -P` — not string equality,
# so a symlinked or trailing-slash path is not read as different). This file
# pins both sides: a guard that never fires and one that fires correctly must
# be distinguishable (CLAUDE.md AC guidance) —
#   1. a fixture audit (PROJECT_ROOT != FRAMEWORK_ROOT) emits the two [INFO]
#      skip lines and NO invariant-suite / dead-negation verdict line at all
#      (not even a PASS — T-3217: a skip is not the same claim as ran-clean).
#   2. a framework-root audit (PROJECT_ROOT == FRAMEWORK_ROOT, the control)
#      is unaffected — it still emits both verdict lines.

load ../test_helper

_t3443_fixture() {
    local d="$1"
    mkdir -p "$d/src/a" "$d/.fabric/components" \
             "$d/.tasks/active" "$d/.tasks/completed" "$d/.tasks/templates" \
             "$d/.context/working"
    touch "$d/.tasks/templates/default.md"
    : > "$d/src/a/watched.py"
    printf 'patterns:\n  - glob: "src/**/*.py"\n    expected_type: script\n' \
        > "$d/.fabric/watch-patterns.yaml"
    printf 'id: c1\nname: watched\nlocation: src/a/watched.py\ntype: script\n' \
        > "$d/.fabric/components/c1.yaml"
    echo "framework_root: $FRAMEWORK_ROOT" > "$d/.framework.yaml"
}

# audit.sh takes a lock; under a concurrent run it prints only "Another audit
# is already running — exiting". Every assertion below would then pass on
# output containing neither section at all — a vacuous green of exactly the
# kind this suite exists to catch (mirrors fabric_watch_pattern_fitness.bats).
_t3443_require_audit_ran() {
    if echo "$1" | grep -q "Another audit is already running"; then
        skip "audit lock held by a concurrent run"
    fi
}

@test "T-3443: fixture audit (PROJECT_ROOT != FRAMEWORK_ROOT) skips both checks with INFO lines, no verdict" {
    _t3443_fixture "$TEST_TEMP_DIR/p"
    local out
    out="$(cd "$FRAMEWORK_ROOT" && timeout 60 env PROJECT_ROOT="$TEST_TEMP_DIR/p" bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    _t3443_require_audit_ran "$out"

    echo "$out" | grep -q "Invariant suite (tests/lint) skipped — framework-repo property; PROJECT_ROOT is not the framework repo"
    echo "$out" | grep -q "Dead-negation lint (tests/) skipped — framework-repo property; PROJECT_ROOT is not the framework repo"

    # Neither check's normal verdict line (PASS/WARN/FAIL) may appear at all.
    [ "$(echo "$out" | grep -c "Invariant suite (tests/lint) green")" -eq 0 ]
    [ "$(echo "$out" | grep -c "Invariant suite (tests/lint):")" -eq 0 ]
    [ "$(echo "$out" | grep -c "Invariant suite (tests/lint) NOT CHECKED")" -eq 0 ]
    [ "$(echo "$out" | grep -c "Dead-negation lint (tests/) clean")" -eq 0 ]
    [ "$(echo "$out" | grep -c "Dead-negation lint (tests/):")" -eq 0 ]
    [ "$(echo "$out" | grep -c "Dead-negation lint output (tests/) NOT CHECKED")" -eq 0 ]
}

@test "T-3443: framework-root audit (control, PROJECT_ROOT == FRAMEWORK_ROOT) still emits both verdicts" {
    local out
    out="$(cd "$FRAMEWORK_ROOT" && timeout 600 env PROJECT_ROOT="$FRAMEWORK_ROOT" bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    _t3443_require_audit_ran "$out"

    echo "$out" | grep -qE "Invariant suite \(tests/lint\)"
    echo "$out" | grep -qE "Dead-negation lint \(tests/\)"

    # The skip lines must be absent on the control — the guard must not
    # over-fire on the very repo it exists to keep checking.
    [ "$(echo "$out" | grep -c "skipped — framework-repo property")" -eq 0 ]
}
