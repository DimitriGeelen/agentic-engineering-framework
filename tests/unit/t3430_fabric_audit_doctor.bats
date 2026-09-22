#!/usr/bin/env bats
# T-3430: the audit + doctor surfaces for under-populated fabric cards.
#
# Both are mirrors of the same scan, so both legs are tested against the same
# two fixtures — a dirty corpus (must WARN, must name the counts) and a clean
# one (must PASS at zero). The clean leg is the one that matters: a check that
# can only ever WARN is indistinguishable from a check that is always on.
#
# The audit function is exercised through lib/fabric_doctor_facts.py + the
# scanner rather than by booting audit.sh, which takes the shared audit lock
# and several minutes; the integration of the two is pinned by the live
# Verification line on the task instead.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    COMPONENTS_DIR="$TMP_PROJECT/.fabric/components"
    mkdir -p "$COMPONENTS_DIR"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

card() {
    cat > "$COMPONENTS_DIR/$1.yaml" <<YAML
id: lib/$1.sh
name: $1
location: lib/$1.sh
subsystem: $2
purpose: "$3"
depends_on: $4
depended_by: []
YAML
}

facts() {
    local json
    json=$(python3 "$FRAMEWORK_ROOT/agents/fabric/lib/underpopulated.py" \
        "$COMPONENTS_DIR" --json --limit 3)
    FW_FAB_JSON="$json" python3 "$FRAMEWORK_ROOT/lib/fabric_doctor_facts.py" "$@"
}

@test "T-3430: facts helper flattens counts to one tab-separated line" {
    card a framework-core "TODO: describe what this component does" '[]'
    run facts
    [ "$status" -eq 0 ]
    # total, todo_purpose, unknown_subsystem, no_edges
    [ "$output" = "$(printf '1\t1\t0\t1')" ]
}

@test "T-3430: facts helper reports zero on a fully-populated corpus" {
    card a framework-core "A real sentence." '[{target: lib/x.sh, type: calls}]'
    run facts
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '0\t0\t0\t0')" ]
}

@test "T-3430: --offenders names the first few locations" {
    card a unknown "TODO: describe what this component does" '[]'
    run facts --offenders
    [ "$status" -eq 0 ]
    [ "$output" = "lib/a.sh" ]
}

@test "T-3430: facts helper exits 1 and prints nothing on unparseable input" {
    run env FW_FAB_JSON='{not json' python3 "$FRAMEWORK_ROOT/lib/fabric_doctor_facts.py"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "T-3430: facts helper exits 1 on empty input rather than reporting zero" {
    # A count of zero and a scan that did not run must not look alike.
    run env FW_FAB_JSON='' python3 "$FRAMEWORK_ROOT/lib/fabric_doctor_facts.py"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "T-3430: audit.sh declares the check and calls it" {
    grep -q '^check_fabric_underpopulated()' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q '^check_fabric_underpopulated$' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "T-3430: the audit WARN and PASS wording both exist, and the WARN names the fix" {
    grep -q 'Fabric: \$_total under-populated card(s)' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q 'Fabric: 0 under-populated card(s)' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q 'fw fabric enrich --describe-only' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "T-3430: the audit check is inside the structure section" {
    run python3 -c "
import sys
lines = open(sys.argv[1]).read().splitlines()
start = next(i for i, l in enumerate(lines) if l.startswith('if should_run_section \"structure\"'))
end   = next(i for i, l in enumerate(lines) if l.startswith('fi # end structure'))
call  = next(i for i, l in enumerate(lines) if l == 'check_fabric_underpopulated')
assert start < call < end, (start, call, end)
print('ok')
" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "T-3430: doctor mirrors the check and counts a warning" {
    grep -q 'Fabric: \$_fab_total under-populated card(s)' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'Fabric: 0 under-populated card(s)' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'fw fabric enrich --describe-only' "$FRAMEWORK_ROOT/bin/fw"
}

@test "T-3430: the cron entry is registered, active, and off the audit minutes" {
    run python3 -c "
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))['jobs']
e = [j for j in jobs if j['id'] == 'fabric-describe-daily']
assert len(e) == 1, 'entry missing'
e = e[0]
assert e['status'] == 'active', e['status']
assert e['origin_task'] == 'T-3430', e['origin_task']
assert 'flock' in e['command'] and 'fabric-describe-daily.lock' in e['command']
assert 'enrich --describe-only' in e['command']
minute = e['schedule'].split()[0]
assert minute not in ('7', '17', '27', '37', '47', '57'), minute
print('ok')
" "$FRAMEWORK_ROOT/.context/cron-registry.yaml"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}
