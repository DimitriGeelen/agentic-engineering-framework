#!/usr/bin/env bats
# T-2293 (arc-010 follow-on): fw mcp check — focused exit-code drift verb
# for CI / pre-commit / scripts (sibling to fw vendor self --dry-run).
#
# Surfaces under test:
#   - agents/mcp/manifest.py main(['check', ...]) — md5 compare emitted vs on-disk
#   - bin/fw mcp check                            — dispatcher routes to manifest.py
#
# Exit-code contract (per T-2293 ACs):
#   0 → in sync (tool-set.yaml matches framework-mcp-manifest.json)
#   1 → drift (mutation made; regenerate via `fw mcp emit-manifest`)
#   2 → manifest absent (never emitted, or unreadable)

load ../test_helper

setup() {
    # Mirror t2290_doctor_mcp_content_check.bats — tests mutate live files.
    BACKUP_TS=$(mktemp -t fw-t2293-ts-XXXXXX.yaml)
    BACKUP_MF=$(mktemp -t fw-t2293-mf-XXXXXX.json)
    [ -f "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json" ] || \
        (cd "$FRAMEWORK_ROOT" && bin/fw mcp emit-manifest > /dev/null 2>&1)
    cp "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml" "$BACKUP_TS"
    cp "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"   "$BACKUP_MF"
    # Ensure sync at test start so t1's OK branch is meaningful.
    (cd "$FRAMEWORK_ROOT" && bin/fw mcp emit-manifest > /dev/null 2>&1)
}

teardown() {
    [ -s "${BACKUP_TS:-/dev/null}" ] && \
        cp "$BACKUP_TS" "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml"
    [ -s "${BACKUP_MF:-/dev/null}" ] && \
        cp "$BACKUP_MF" "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"
    rm -f "${BACKUP_TS:-}" "${BACKUP_MF:-}"
}

@test "t1: in-sync state → exit 0 with OK message" {
    cd "$FRAMEWORK_ROOT"
    run bin/fw mcp check
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK:"* ]]
    [[ "$output" == *"in sync"* ]]
}

@test "t2: drift state → exit 1 with DRIFT message" {
    # Mutate tool-set.yaml so emitted manifest would differ from on-disk.
    python3 -c "
import yaml
p = '$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml'
d = yaml.safe_load(open(p))
d['read_only'].append({'name': 'fake_drift_tool_t2293', 'rationale': 'test'})
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw mcp check
    [ "$status" -eq 1 ]
    [[ "$output" == *"DRIFT:"* ]]
    [[ "$output" == *"fw mcp emit-manifest"* ]]
}

@test "t3: manifest absent → exit 2 with ABSENT message" {
    rm -f "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"
    cd "$FRAMEWORK_ROOT"
    run bin/fw mcp check
    [ "$status" -eq 2 ]
    [[ "$output" == *"ABSENT:"* ]]
    [[ "$output" == *"fw mcp emit-manifest"* ]]
}

@test "t4: help text includes new check verb" {
    cd "$FRAMEWORK_ROOT"
    run bin/fw mcp help
    [ "$status" -eq 0 ]
    [[ "$output" == *"check"* ]]
    [[ "$output" == *"sync/drift/absent"* ]]
}
