#!/usr/bin/env bats
# T-1402: audit.sh METRICS_EOF heredoc must not crash when
# .context/project/metrics-history.yaml contains an entry with null timestamp.
# Origin: handover S-2026-0423-1623 emitted
# "AttributeError: 'NoneType' object has no attribute 'replace'" at <stdin>:108.

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
    git commit -q -m "T-1402: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

@test "T-1402: audit survives metrics-history entry with null timestamp" {
    cd "$TMPREPO"
    # Seed a corrupted metrics-history entry (timestamp explicitly null, as if a
    # partial write was interrupted during a prior handover race).
    cat > .context/project/metrics-history.yaml <<'YAML'
entries:
  - timestamp: null
    pass: 0
    warn: 0
    fail: 0
    active_tasks: 0
    completed_tasks: 0
    velocity: 0
    traceability_pct: 0
    episodic_quality_pct: 100
    open_gaps: 0
  - timestamp: '2026-04-23T10:00:00Z'
    pass: 10
    warn: 1
    fail: 0
    active_tasks: 5
    completed_tasks: 20
    velocity: 3
    traceability_pct: 90
    episodic_quality_pct: 95
    open_gaps: 2
YAML

    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$AUDIT" --section structure
    [ "$status" -le 1 ]
    # Must NOT emit the old traceback
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"NoneType"* ]]
}

@test "T-1402: audit survives metrics-history entry with missing timestamp key" {
    cd "$TMPREPO"
    # Key entirely absent — original default-arg path ("" fallback) should still work
    cat > .context/project/metrics-history.yaml <<'YAML'
entries:
  - pass: 0
    warn: 0
    fail: 0
YAML

    PROJECT_ROOT="$TMPREPO" TASKS_DIR= CONTEXT_DIR= \
        run bash "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"NoneType"* ]]
}
