#!/usr/bin/env bats
# T-2290 (arc-010 follow-on): doctor MCP manifest stale check uses content
# comparison, not raw mtime — false-positives on content-identical refresh.
#
# Surfaces under test:
#   - bin/fw doctor MCP manifest block (lines ~1244-1280)
#   - Fast-path: if tool-set.yaml is NOT newer than manifest, the OK branch
#     fires directly without invoking the content check.
#   - Slow-path: if tool-set.yaml IS newer than manifest, re-emit the manifest
#     in-memory via agents/mcp/manifest.py show, md5 it, compare to on-disk md5.
#     Match → OK, mismatch → WARN.
#
# AC mapping (per .tasks/active/T-2290-*.md):
#   content-identical mtime-newer → OK            — t1
#   real content drift → WARN                     — t2
#   manifest absent → SKIP                        — t3

load ../test_helper

setup() {
    # Save originals — these tests mutate live tool-set.yaml/manifest in place.
    BACKUP_TS=$(mktemp -t fw-t2290-ts-XXXXXX.yaml)
    BACKUP_MF=$(mktemp -t fw-t2290-mf-XXXXXX.json)
    # Ensure manifest exists before backing up (regen if a prior failed test deleted it)
    [ -f "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json" ] || \
        (cd "$FRAMEWORK_ROOT" && bin/fw mcp emit-manifest > /dev/null 2>&1)
    cp "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml" "$BACKUP_TS"
    cp "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"   "$BACKUP_MF"
    # Make sure manifest is in sync with tool-set.yaml at test start
    (cd "$FRAMEWORK_ROOT" && bin/fw mcp emit-manifest > /dev/null 2>&1)
}

teardown() {
    # Defensive: only restore if the backup is a non-empty file.
    [ -s "${BACKUP_TS:-/dev/null}" ] && \
        cp "$BACKUP_TS" "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml"
    [ -s "${BACKUP_MF:-/dev/null}" ] && \
        cp "$BACKUP_MF" "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"
    rm -f "${BACKUP_TS:-}" "${BACKUP_MF:-}"
}

@test "t1: content-identical mtime-newer → OK (false-positive cleared)" {
    # Touch tool-set.yaml so its mtime advances past manifest's, but content
    # remains identical. The mtime fast-path will fire, then content check
    # must demote to OK.
    touch "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    # The MCP line must be the OK branch, not the WARN branch.
    [[ "$output" == *"framework MCP 22 tools"* ]] || [[ "$output" == *"framework MCP "* ]]
    [[ "$output" != *"framework MCP manifest stale relative to tool-set.yaml"* ]]
}

@test "t2: real content drift → WARN (detection still works)" {
    # Mutate tool-set.yaml so the regenerated manifest would differ from the
    # on-disk manifest. The mtime fast-path fires, content check finds mismatch,
    # the existing WARN must still surface with the existing guidance.
    python3 -c "
import yaml, sys
p = '$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml'
d = yaml.safe_load(open(p))
d['read_only'].append({'name': 'fake_drift_tool_t2290', 'rationale': 'test'})
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"framework MCP manifest stale relative to tool-set.yaml"* ]]
    [[ "$output" == *"Run: fw mcp emit-manifest"* ]]
}

@test "t3: manifest absent → SKIP (no regression on absent branch)" {
    # Remove the manifest. The outer if-file-exists guard is unchanged; the
    # SKIP branch must still fire with the existing guidance.
    rm -f "$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
    [[ "$output" == *"framework MCP manifest absent"* ]]
    [[ "$output" == *"run: fw mcp emit-manifest"* ]]
}
