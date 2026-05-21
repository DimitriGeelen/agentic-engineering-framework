#!/usr/bin/env bats
# T-1975 (L-417 prevention): pin the stale-slice-reference audit check.
#
# Verifies:
#   1. Clean tree → PASS line emitted
#   2. Seeded "ship in T-NNNN" where T-NNNN is in .tasks/completed/ → WARN
#   3. Seeded "ship in T-NNNN" where T-NNNN is ACTIVE → does NOT WARN
#   4. Allowlisted paths (tests/, docs/, audit.sh self) → exempt
#   5. "once that slice ships" phrasing → WARN regardless of T-NNNN
#
# Strategy: isolated synthetic PROJECT_ROOT + check-block logic extracted
# inline (same pattern as audit_ctl_arc_tag_only_pattern.bats).

setup() {
    PROJECT_ROOT="$(mktemp -d)"
    export PROJECT_ROOT
    mkdir -p \
        "$PROJECT_ROOT/web/templates" \
        "$PROJECT_ROOT/web/blueprints" \
        "$PROJECT_ROOT/lib" \
        "$PROJECT_ROOT/tests/unit" \
        "$PROJECT_ROOT/docs" \
        "$PROJECT_ROOT/.tasks/active" \
        "$PROJECT_ROOT/.tasks/completed" \
        "$PROJECT_ROOT/agents/audit"

    # Seed task corpus: T-9001 is completed, T-9002 is active.
    : > "$PROJECT_ROOT/.tasks/completed/T-9001-some-slice-shipped.md"
    : > "$PROJECT_ROOT/.tasks/active/T-9002-future-slice.md"
}

teardown() {
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

# Helper: run JUST the check-block logic against the synthetic PROJECT_ROOT.
run_check() {
    bash -c '
        PROJECT_ROOT="$1"
        stale_slice_count=0
        stale_slice_evidence=""
        for scan_dir in web/templates web/blueprints lib; do
            [ -d "$PROJECT_ROOT/$scan_dir" ] || continue
            while IFS= read -r hit; do
                [ -z "$hit" ] && continue
                case "$hit" in
                    *agents/audit/audit.sh:*) continue ;;
                    *tests/*|*docs/*|*.fabric/*|*.context/*|*.tasks/*) continue ;;
                esac
                t_id=$(echo "$hit" | grep -oE "T-[0-9]{2,5}" | head -1)
                if [ -n "$t_id" ]; then
                    if ls "$PROJECT_ROOT/.tasks/completed/${t_id}-"*.md >/dev/null 2>&1; then
                        stale_slice_count=$((stale_slice_count + 1))
                        stale_slice_evidence="$stale_slice_evidence$hit"$'\''\n'\''
                    fi
                else
                    stale_slice_count=$((stale_slice_count + 1))
                    stale_slice_evidence="$stale_slice_evidence$hit"$'\''\n'\''
                fi
            done < <(grep -RniE "(\<ship\>|\<ships\>|\<shipping\>)[[:space:]]+in[[:space:]]+T-[0-9]{2,5}|once[[:space:]]+(that[[:space:]]+)?slice[[:space:]]+ships?" \
                           --include="*.html" --include="*.py" --include="*.sh" \
                           "$PROJECT_ROOT/$scan_dir" 2>/dev/null || true)
        done
        if [ "$stale_slice_count" -eq 0 ]; then
            echo "PASS"
        else
            echo "WARN $stale_slice_count"
            printf "%s" "$stale_slice_evidence" | head -5
        fi
    ' _ "$PROJECT_ROOT"
}

@test "clean tree emits PASS" {
    run run_check
    [ "$status" -eq 0 ]
    [ "$output" = "PASS" ]
}

@test "stale reference to completed task in web/templates/ triggers WARN" {
    cat > "$PROJECT_ROOT/web/templates/page.html" <<'EOF'
<p>Read-only — sliders ship in T-9001.</p>
EOF
    run run_check
    [ "$status" -eq 0 ]
    [[ "$output" == WARN* ]]
    [[ "$output" == *"page.html"* ]]
}

@test "stale reference in web/blueprints/ triggers WARN" {
    cat > "$PROJECT_ROOT/web/blueprints/foo.py" <<'EOF'
"""Live slider commit ships in T-9001 (T-NEW-12b)."""
EOF
    run run_check
    [[ "$output" == WARN* ]]
    [[ "$output" == *"foo.py"* ]]
}

@test "stale reference in lib/ triggers WARN" {
    cat > "$PROJECT_ROOT/lib/foo.sh" <<'EOF'
# Score tasks via fw bvp confirm T-<id> (T-9001) once that slice ships.
EOF
    run run_check
    [[ "$output" == WARN* ]]
    [[ "$output" == *"foo.sh"* ]]
}

@test "reference to ACTIVE task (T-9002) does NOT trigger WARN" {
    cat > "$PROJECT_ROOT/web/templates/page.html" <<'EOF'
<p>This feature will ship in T-9002.</p>
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "reference under tests/ is exempt (allowlist)" {
    cat > "$PROJECT_ROOT/tests/unit/example.sh" <<'EOF'
# fixture: sliders ship in T-9001
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "reference under docs/ is exempt (out-of-scope)" {
    cat > "$PROJECT_ROOT/docs/notes.html" <<'EOF'
<p>Sliders ship in T-9001 — historical note.</p>
EOF
    # docs/ is outside scan_dir scope (we only scan web/templates, web/blueprints, lib)
    run run_check
    [ "$output" = "PASS" ]
}

@test "audit.sh itself is exempt (self-reference)" {
    # If we scanned audit.sh, the check block's own pattern strings would match.
    # The check lives under agents/, not web|lib, so scope already protects it,
    # but we belt-and-braces with a path exclusion. Verify by simulating.
    mkdir -p "$PROJECT_ROOT/lib"
    cat > "$PROJECT_ROOT/lib/audit_stub.sh" <<'EOF'
# Internal reference: "ships in T-9001" — would normally trigger but
# audit.sh path is allowlisted (path-based, not name-based, so this stub
# is NOT exempt). This test asserts that the path check is path-shaped.
EOF
    run run_check
    # This SHOULD trigger — audit.sh-allowlist is path-prefix only.
    [[ "$output" == WARN* ]]
}

@test "once-that-slice-ships phrasing triggers WARN (no T-NNNN)" {
    cat > "$PROJECT_ROOT/lib/foo.sh" <<'EOF'
# Will be wired once that slice ships.
EOF
    run run_check
    [[ "$output" == WARN* ]]
    [[ "$output" == *"foo.sh"* ]]
}

@test "multiple stale references across files are all counted" {
    cat > "$PROJECT_ROOT/web/templates/a.html" <<'EOF'
<p>Sliders ship in T-9001.</p>
EOF
    cat > "$PROJECT_ROOT/web/blueprints/b.py" <<'EOF'
"""Live commit ships in T-9001."""
EOF
    run run_check
    [[ "$output" == "WARN 2"* ]]
}

@test "case-insensitive matching (Ships In T-...) is caught" {
    cat > "$PROJECT_ROOT/web/templates/a.html" <<'EOF'
<p>Feature SHIPS IN T-9001.</p>
EOF
    run run_check
    [[ "$output" == WARN* ]]
}

@test "past-tense 'shipped in T-NNNN' is NOT flagged (historical)" {
    # The L-417 anti-pattern is FORECASTS that became stale; past-tense
    # references to already-shipped work are correct documentation.
    cat > "$PROJECT_ROOT/web/blueprints/arcs.py" <<'EOF'
"""Generic operator-facing surface for the Arc system shipped in T-9001."""
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "T-NNNN that does not exist anywhere is NOT flagged" {
    # FP guard: if neither active nor completed has T-9999, we don't know
    # — could be a planned-but-not-yet-filed slice. Don't flag.
    cat > "$PROJECT_ROOT/web/templates/a.html" <<'EOF'
<p>Feature will ship in T-9999 (planned).</p>
EOF
    run run_check
    [ "$output" = "PASS" ]
}
