#!/usr/bin/env bats
# T-4209 — `fw audit --list-checks` / `--check <id>`: run one audit check instead
# of a whole section (832: four probes each paid a ~54 s structure audit to read
# one check). Ids are derived from the check_* functions in audit.sh.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context/locks" "$PROJ/.tasks/active" "$PROJ/.tasks/completed" \
             "$PROJ/.fabric/components"
    # One card whose file does not exist -> fabric-coverage WARNs (orphaned card).
    printf 'id: a\nlocation: src/missing.sh\n' > "$PROJ/.fabric/components/a.yaml"
}

run_audit() { PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" run "$AUDIT" "$@"; }

@test "list-checks prints id and section, includes fabric-coverage, exits 0" {
    run_audit --list-checks
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^fabric-coverage  structure$'
    echo "$output" | grep -q '^stale-drafts  structure$'
}

@test "list-checks has one line per check_* function in audit.sh" {
    n=$(grep -c -E '^check_[a-z0-9_]+\(\) \{' "$AUDIT")
    run_audit --list-checks
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | wc -l)" -eq "$n" ]
}

@test "--check runs exactly the named check: its lines present, others absent" {
    run_audit --check fabric-coverage
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'Fabric: 1 orphaned card'
    if echo "$output" | grep -q -E 'Tasks directory exists|Self-vendor|Stale draft'; then false; fi
    echo "$output" | grep -q '=== SUMMARY ==='
    echo "$output" | grep -q '^AUDIT-SCOPE: fails=0'
}

@test "--check accepts a comma list and underscore spelling" {
    run_audit --check fabric_coverage,stale-drafts
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'Fabric: 1 orphaned card'
}

@test "--check on a clean check exits 0" {
    run_audit --check stale-drafts
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '=== END AUDIT ==='
}

@test "unknown id is refused with exit 2 and the valid ids" {
    run_audit --check no-such-check
    [ "$status" -eq 2 ]
    echo "$output" | grep -q 'Unknown audit check id'
    echo "$output" | grep -q 'fabric-coverage'
    if echo "$output" | grep -q '=== SUMMARY ==='; then false; fi
}

@test "--check with no id is refused with exit 2" {
    run_audit --check
    [ "$status" -eq 2 ]
}

@test "--check takes no lock: runs while another audit holds it, writes no YAML" {
    exec 9>"$PROJ/.context/locks/audit.lock"
    flock -n 9
    run_audit --check stale-drafts
    exec 9>&-
    [ "$status" -eq 0 ]
    [ ! -d "$PROJ/.context/audits" ] || [ -z "$(ls "$PROJ"/.context/audits/*.yaml 2>/dev/null)" ]
}

@test "full audit still prints the fabric lines (function called in place)" {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" run "$AUDIT" --section structure
    echo "$output" | grep -q 'Fabric: 1 orphaned card'
}
