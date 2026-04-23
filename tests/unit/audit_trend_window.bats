#!/usr/bin/env bats
# T-1394: audit trend analysis must use a rolling window so resolved issues
# stop appearing in trend output forever.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMPREPO=$(mktemp -d)
    cd "$TMPREPO"
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    mkdir -p .context/working .context/audits .context/monitors .context/approvals .context/project .tasks/active .tasks/completed .tasks/templates
    touch .tasks/templates/zzz-default.md
    for d in working audits monitors approvals project; do
        touch ".context/$d/.gitkeep"
    done
    echo "real" > README.md
    git add -A
    git commit -q -m "T-1394: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

# Helper: write an audit file with N WARN lines for a given check name.
_make_audit() {
    local date_iso="$1"
    local check_name="$2"
    local count="$3"
    local f=".context/audits/${date_iso}.yaml"
    {
        echo "timestamp: ${date_iso}T00:00:00Z"
        echo "summary: {pass: 0, warn: ${count}, fail: 0}"
        echo "findings:"
        for _ in $(seq 1 "$count"); do
            echo "  - level: WARN"
            echo "    check: \"${check_name}\""
        done
    } > "$f"
}

@test "T-1394: stale-only issues outside window are NOT reported" {
    cd "$TMPREPO"
    # Create 5 old audits, 30+ days ago, with the same WARN
    for d in 30 29 28 27 26; do
        date_iso=$(date -d "${d} days ago" +%Y-%m-%d 2>/dev/null || date -v-${d}d +%Y-%m-%d)
        _make_audit "$date_iso" "Old resolved issue" 1
    done

    # Explicitly clear derived paths so they're re-resolved from PROJECT_ROOT
    # (lib/paths.sh exports TASKS_DIR/CONTEXT_DIR — when CTL-013 re-runs this
    # test under outer audit, stale exports leak through. T-1395.)
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= FW_AUDIT_TREND_WINDOW_DAYS=14 \
        run bash "$AUDIT" --section structure
    [ "$status" -le 1 ]
    # The stale issue must NOT be reported as repeated
    [[ "$output" != *"Old resolved issue"* ]]
    # Either "First audit recorded" (no audits in window) OR "No repeated issues in last 14 days"
    [[ "$output" == *"First audit recorded"* || "$output" == *"No repeated issues in last 14 days"* ]]
}

@test "T-1394: recent-recurring issues ARE reported" {
    cd "$TMPREPO"
    # Create 4 recent audits in the last 5 days with the same WARN
    for d in 1 2 3 4; do
        date_iso=$(date -d "${d} days ago" +%Y-%m-%d 2>/dev/null || date -v-${d}d +%Y-%m-%d)
        _make_audit "$date_iso" "Recent recurring issue" 1
    done

    # Explicitly clear derived paths so they're re-resolved from PROJECT_ROOT
    # (lib/paths.sh exports TASKS_DIR/CONTEXT_DIR — when CTL-013 re-runs this
    # test under outer audit, stale exports leak through. T-1395.)
    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= FW_AUDIT_TREND_WINDOW_DAYS=14 \
        run bash "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"Recent recurring issue"* ]]
    [[ "$output" == *"Repeated issues detected in last 14 days"* ]]
}
