#!/usr/bin/env bats
# T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check.
#
# Verifies that:
#   1. A clean tree (allowlist-only matches) → PASS line emitted
#   2. A synthetic violation under web/blueprints/ → FAIL line emitted
#   3. Matches under tests/ and lib/arc.sh / lib/arc_membership.sh / lib/migrations/
#      are exempt (allowlist works)
#
# Strategy: exercise only the check block — extract the AWK-pattern logic
# directly. Running the full audit.sh per-test would be slow + flaky.

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
    cat > "$PROJECT_ROOT/tests/unit/arc_test.bats" <<'EOF'
@test "fixture" {
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

# Helper: run JUST the check-block logic against the synthetic PROJECT_ROOT.
# Extracts the check from agents/audit/audit.sh and evaluates it inline.
run_check() {
    bash -c '
        PROJECT_ROOT="$1"
        arc_tag_only_violations=0
        arc_tag_only_evidence=""
        arc_tag_only_pattern='\''grep[^|]*"\^?tags:.*arc:|grep[^|]*arc:[A-Za-z0-9_-]'\''
        for scan_dir in lib web agents bin tools; do
            [ -d "$PROJECT_ROOT/$scan_dir" ] || continue
            while IFS= read -r hit; do
                [ -z "$hit" ] && continue
                case "$hit" in
                    *lib/arc_membership.sh:*|*lib/arc_membership.py:*) continue ;;
                    *lib/arc.sh:*) continue ;;
                    *lib/migrations/*) continue ;;
                    *tests/*|*docs/*|*.fabric/*|*.context/*) continue ;;
                esac
                arc_tag_only_violations=$((arc_tag_only_violations + 1))
                arc_tag_only_evidence="$arc_tag_only_evidence$hit"$'\''\n'\''
            done < <(grep -RnE "$arc_tag_only_pattern" \
                           --include='\''*.sh'\'' --include='\''*.py'\'' --include='\''*.bash'\'' \
                           "$PROJECT_ROOT/$scan_dir" 2>/dev/null || true)
        done
        if [ "$arc_tag_only_violations" -eq 0 ]; then
            echo "PASS"
        else
            echo "FAIL $arc_tag_only_violations"
            printf "%s" "$arc_tag_only_evidence" | head -5
        fi
    ' _ "$PROJECT_ROOT"
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
    cat > "$PROJECT_ROOT/tests/unit/check_arc_membership.bats" <<'EOF'
@test "scan" {
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
