#!/usr/bin/env bats
# T-2290 (arc-010 follow-on): doctor MCP manifest stale check uses content
# comparison, not raw mtime — false-positives on content-identical refresh.
#
# Surfaces under test:
#   - lib/doctor-drift.sh doctor_check_mcp_manifest (bin/fw doctor calls it)
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
#
# T-3801: the check runs on a FIXTURE framework root (copies of tool-set.yaml and
# manifest.py, a manifest emitted there). This file used to run a whole
# `bin/fw doctor` per test (558 s against the 900 s cap on the 2026-10-21
# nightly) and mutated the live tool-set.yaml and manifest, restoring them in
# teardown — an interrupted run left the working tree dirty.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FIX="$TEST_TEMP_DIR/fw"
    mkdir -p "$FIX/agents/mcp" "$FIX/policy/capability-overlay"
    cp "$FRAMEWORK_ROOT/agents/mcp/manifest.py" "$FIX/agents/mcp/manifest.py"
    cp "$FRAMEWORK_ROOT/policy/capability-overlay/tool-set.yaml" "$FIX/policy/capability-overlay/tool-set.yaml"
    FRAMEWORK_ROOT="$FIX" python3 "$FIX/agents/mcp/manifest.py" emit > /dev/null
    [ -f "$FIX/agents/mcp/framework-mcp-manifest.json" ]
    TS="$FIX/policy/capability-overlay/tool-set.yaml"
    MF="$FIX/agents/mcp/framework-mcp-manifest.json"
    # Manifest strictly newer than tool-set at start, so only the test's own
    # touch/edit moves the mtime fast-path.
    touch -d '2 minutes ago' "$TS"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run the check exactly as doctor does, with the fixture as FRAMEWORK_ROOT = PROJECT_ROOT.
_mcp_check() {
    run env FRAMEWORK_ROOT="$FIX" PROJECT_ROOT="$FIX" bash -c 'GREEN= YELLOW= CYAN= NC= warnings=0
        source "$1/lib/doctor-drift.sh"; doctor_check_mcp_manifest; echo "warnings=$warnings"' \
        _ "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
}

@test "t1: content-identical mtime-newer → OK (false-positive cleared)" {
    # Touch tool-set.yaml so its mtime advances past manifest's, but content
    # remains identical. The mtime fast-path will fire, then content check
    # must demote to OK.
    touch "$TS"
    [ "$TS" -nt "$MF" ]
    _mcp_check
    [[ "$output" == *"OK  framework MCP "*" tools (gated: "* ]]
    [[ "$output" != *"framework MCP manifest stale relative to tool-set.yaml"* ]]
    [[ "$output" == *"warnings=0"* ]]
}

@test "t2: real content drift → WARN (detection still works)" {
    # Mutate tool-set.yaml so the regenerated manifest would differ from the
    # on-disk manifest. The mtime fast-path fires, content check finds mismatch,
    # the existing WARN must still surface with the existing guidance.
    python3 -c "
import yaml
p = '$TS'
d = yaml.safe_load(open(p))
d['read_only'].append({'name': 'fake_drift_tool_t2290', 'rationale': 'test'})
yaml.safe_dump(d, open(p,'w'), sort_keys=False)
"
    [ "$TS" -nt "$MF" ]
    _mcp_check
    [[ "$output" == *"framework MCP manifest stale relative to tool-set.yaml"* ]]
    [[ "$output" == *"Run: fw mcp emit-manifest"* ]]
    [[ "$output" == *"warnings=1"* ]]
}

@test "t3: manifest absent → SKIP (no regression on absent branch)" {
    # Remove the manifest. The outer if-file-exists guard is unchanged; the
    # SKIP branch must still fire with the existing guidance.
    rm -f "$MF"
    _mcp_check
    [[ "$output" == *"framework MCP manifest absent"* ]]
    [[ "$output" == *"run: fw mcp emit-manifest"* ]]
}

@test "t4: doctor calls the lib check" {
    run grep -cx '    doctor_check_mcp_manifest' "$FRAMEWORK_ROOT/bin/fw"
    [ "$output" -eq 1 ]
}
