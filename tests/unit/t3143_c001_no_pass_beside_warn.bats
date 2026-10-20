#!/usr/bin/env bats
# T-3143: audit C-001 must not print its "All inceptions have research artifacts"
# PASS in the same run as its own C-001 WARN.
#
# The PASS was gated on c001_missing alone; an "unreferenced" artefact WARNed
# without touching that counter, so an unreferenced-only corpus printed both.
# Two-sided: the unreferenced fixture gets the WARN and no PASS; the same fixture
# with the artefact referenced gets the PASS and no WARN.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export AUDIT_ROOT="$(mktemp -d)"
    mkdir -p "$AUDIT_ROOT/.tasks/active" "$AUDIT_ROOT/.tasks/completed" \
             "$AUDIT_ROOT/docs/reports" "$AUDIT_ROOT/.context/working"
    cat > "$AUDIT_ROOT/.tasks/active/T-9301-worked.md" << 'EOF'
---
id: T-9301
name: "Worked inception"
description: "Being worked, artefact on disk but not referenced"
status: started-work
workflow_type: inception
owner: agent
created: 2026-08-01T00:00:00Z
last_update: 2026-08-10T00:00:00Z
---
# T-9301

## Updates

### 2026-08-01T00:00:00Z — created
EOF
    echo "# research" > "$AUDIT_ROOT/docs/reports/T-9301-the-research.md"
}

teardown() {
    rm -rf "$AUDIT_ROOT"
}

_run_oe_research() {
    run env PROJECT_ROOT="$AUDIT_ROOT" "$FRAMEWORK_ROOT/bin/fw" audit --section oe-research
    CLEAN=$(printf '%s\n' "$output" | sed -e 's/\x1b\[[0-9;]*m//g')
}

@test "T-3143: unreferenced artefact WARNs and the C-001 PASS is not printed" {
    _run_oe_research
    echo "$CLEAN" | grep -qE "^\[WARN\] C-001: Inception T-9301 \(started-work\) has artifact but task doesn't reference it"
    if echo "$CLEAN" | grep -qE '^\[PASS\] C-001: All inceptions have research artifacts'; then false; fi
}

@test "T-3143 control: referenced artefact PASSes with no C-001 WARN" {
    echo "Research artefact: docs/reports/T-9301-the-research.md" >> "$AUDIT_ROOT/.tasks/active/T-9301-worked.md"
    _run_oe_research
    echo "$CLEAN" | grep -qE '^\[PASS\] C-001: All inceptions have research artifacts — 1 started-work, 0 awaiting decision$'
    if echo "$CLEAN" | grep -qE '^\[WARN\] C-001: Inception T-9301'; then false; fi
}
