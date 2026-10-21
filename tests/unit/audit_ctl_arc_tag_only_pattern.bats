#!/usr/bin/env bats
# T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check.
#
# Verifies that:
#   1. A clean tree (allowlist-only matches) → PASS line emitted
#   2. A synthetic violation under web/blueprints/ → FAIL line emitted
#   3. Matches under tests/ and lib/arc.sh / lib/arc_membership.sh / lib/migrations/
#      are exempt (allowlist works)
#
# Strategy: exercise only the check block, extracted from audit.sh (T-4380).
# Running the full audit.sh per-test would be slow + flaky.

load ../test_helper

setup() {
    PROJECT_ROOT="$(mktemp -d)"
    guard_project_root
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/lib" "$PROJECT_ROOT/web/blueprints" \
             "$PROJECT_ROOT/agents/foo" "$PROJECT_ROOT/tests/unit" \
             "$PROJECT_ROOT/lib/migrations" "$PROJECT_ROOT/docs"

    # Allowlist files — these contain the legacy pattern but must NOT
    # trigger the check (they ARE the canonical sites).
    cat > "$PROJECT_ROOT/lib/arc_membership.sh" <<'EOF'
arc_tasks_with_tag() {
    grep -lE "^tags:.*arc:foo" "$PROJECT_ROOT"/.tasks/active/*.md
}
EOF
    cat > "$PROJECT_ROOT/lib/arc.sh" <<'EOF'
_arc_tasks_with_tag() {
    grep -lE "^tags:.*${tag}" "$PROJECT_ROOT"/.tasks/active/*.md
}
EOF
    cat > "$PROJECT_ROOT/lib/migrations/arc-id-migration.sh" <<'EOF'
# one-shot migrator
grep -lE "tags:.*arc:foo" *.md
EOF
    # T-4521: fixture tests are spelled @@test and restored by sed, so bats <1.11 (which
    # scans source text, heredocs included) does not count them as tests of this file.
    sed 's/^@@test/@test/' > "$PROJECT_ROOT/tests/unit/arc_test.bats" <<'EOF'
@@test "fixture" {
    grep "arc:foo" file.md
}
EOF

    # Reusable check runner — sources the audit.sh check block isolated.
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export REPO_ROOT
}

teardown() {
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

# Helper: run JUST the check block, extracted from agents/audit/audit.sh, against
# the synthetic PROJECT_ROOT. T-4380: this used to be a copy of the block written
# out in the test, which stayed green when the shipped pattern was broken. The
# block is cut between its own first assignment and the next check's header, so
# a moved or renamed block fails loudly instead of yielding an empty script.
run_check() {
    local block="$PROJECT_ROOT/.ctl-arc-tag-only-block.sh"
    awk '/^arc_tag_only_violations=0$/{f=1} /^# T-3516 \(OBS-546\): ctl-arc-membership-python-import/{f=0} f' \
        "$REPO_ROOT/agents/audit/audit.sh" > "$block"
    [ -s "$block" ] || { echo "extraction empty - did the block move?" >&2; return 1; }
    bash -c '
        PROJECT_ROOT="$1"
        pass_over() { echo "PASS"; }
        fail() { echo "FAIL $arc_tag_only_violations"; printf "%b" "$2" | head -5; }
        source "$2"
    ' _ "$PROJECT_ROOT" "$block"
}

@test "clean tree (allowlist-only) emits PASS" {
    run run_check
    [ "$status" -eq 0 ]
    [ "$output" = "PASS" ]
}

@test "synthetic violation in web/blueprints/ triggers FAIL" {
    cat > "$PROJECT_ROOT/web/blueprints/badscan.py" <<'EOF'
# new inline scan — should be caught
import subprocess
result = subprocess.run(["grep", "-lE", "^tags:.*arc:foo", "/tasks/*.md"])
EOF
    run run_check
    [ "$status" -eq 0 ]
    [[ "$output" == FAIL* ]]
    [[ "$output" == *"badscan.py"* ]]
}

@test "synthetic violation in agents/ triggers FAIL" {
    cat > "$PROJECT_ROOT/agents/foo/scanner.sh" <<'EOF'
#!/bin/bash
# bad: inline arc tag scan
grep -lE "^tags:.*arc:bar" "$PROJECT_ROOT"/.tasks/active/*.md
EOF
    run run_check
    [ "$status" -eq 0 ]
    [[ "$output" == FAIL* ]]
    [[ "$output" == *"scanner.sh"* ]]
}

@test "violation under tests/ is exempt (allowlist)" {
    sed 's/^@@test/@test/' > "$PROJECT_ROOT/tests/unit/check_arc_membership.bats" <<'EOF'
@@test "scan" {
    grep -lE "^tags:.*arc:foo" *.md
}
EOF
    run run_check
    [ "$status" -eq 0 ]
    # Still PASS — tests/ allowlisted
    [ "$output" = "PASS" ]
}

@test "violation under docs/ is exempt (allowlist)" {
    cat > "$PROJECT_ROOT/docs/example.sh" <<'EOF'
# illustrative only
grep -lE "^tags:.*arc:foo" *.md
EOF
    # docs/ is outside scan_dir scope (we only scan lib/web/agents/bin/tools)
    # so this is doubly safe.
    run run_check
    [ "$output" = "PASS" ]
}

@test "lib/arc_membership.sh internal scan is exempt (canonical site)" {
    # Already created in setup — verifies PASS state holds
    run run_check
    [ "$output" = "PASS" ]
}

@test "two violations across two files are both flagged" {
    cat > "$PROJECT_ROOT/web/blueprints/a.py" <<'EOF'
grep "arc:foo" file.md
EOF
    cat > "$PROJECT_ROOT/agents/foo/b.sh" <<'EOF'
grep "tags:.*arc:bar" file.md
EOF
    run run_check
    [[ "$output" == "FAIL 2"* ]]
}

@test "current_arc: lookup (different namespace) is not flagged" {
    cat > "$PROJECT_ROOT/agents/foo/focus.sh" <<'EOF'
#!/bin/bash
# Reads arc-focus.yaml, not legacy task tag — should not trigger.
cur_arc=$(grep -E '^current_arc:' "$ARC_FOCUS_FILE")
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "arc_id: read (canonical) is not flagged" {
    cat > "$PROJECT_ROOT/agents/foo/canonical.sh" <<'EOF'
#!/bin/bash
grep -lE "^arc_id:.*test-arc-x" "$PROJECT_ROOT"/.tasks/active/*.md
EOF
    run run_check
    [ "$output" = "PASS" ]
}
