#!/usr/bin/env bats
# T-2297: audit.sh T-2067 fm parse block — batched single-python3 refactor.
#
# Surface under test: agents/audit/audit.sh block starting at
# `# T-2067: task-frontmatter parse check` and ending at the comment
# `# T-1856 (T-NEW-8): Anchor-task existence check.`
#
# Strategy: extract just that block via awk + a stubbed pass/warn/fail
# harness, point PROJECT_ROOT at a synthetic 3-file corpus (1 valid,
# 1 T-2067-class mangled, 1 T-2069-class folded-scalar), and assert
# the warn line names both classes. Pins:
#   - Exactly one `python3` invocation in the block (regression-net for
#     any future per-file fork sneaking back in)
#   - Synthetic corpus completes the block in under 5s (perf-net)
#   - Both error classes surface in the warn message (semantic-net)

load ../test_helper

AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

_extract_block() {
    # From the T-2067 origin comment through (but not including)
    # the T-1856 anchor-task block header.
    awk '
        /^# T-2067: task-frontmatter parse check/ { p=1 }
        p && /^# T-1856/ { exit }
        p { print }
    ' "$AUDIT_SH"
}

_make_corpus() {
    # 1 valid task
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed"
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9001-valid.md" <<'EOF'
---
id: T-9001
name: "valid task"
description: "ok"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

body
EOF
    # T-2067-class: no/invalid frontmatter delimiters
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9002-no-delim.md" <<'EOF'
no frontmatter at all
just a body
EOF
    # T-2069-class: folded-scalar terminated by blank line then col-0 list
    # causes yaml.ScannerError → parse_frontmatter returns empty dict.
    cat > "$TEST_TEMP_DIR/.tasks/completed/T-9003-folded.md" <<'EOF'
---
id: T-9003
description: >

1. col-0 line breaks YAML
2. second bad line
status: work-completed
---

body
EOF
}

_run_block() {
    _make_corpus
    local script="$TEST_TEMP_DIR/runner.sh"
    cat > "$script" <<RUNNER
#!/bin/bash
# Stub pass/warn/fail/info — record label + first arg to stdout
pass() { echo "PASS: \$1"; }
warn() { echo "WARN: \$1"; echo "EVIDENCE: \$2"; echo "MITIGATION: \$3"; [ -n "\$4" ] && echo "EXTRA: \$4"; }
fail() { echo "FAIL: \$1"; }
info() { echo "INFO: \$1"; }
PROJECT_ROOT="$TEST_TEMP_DIR"
# The audit.sh block calls _is_test_sentinel via the surrounding context
# (T-2228). Stub it: nothing here is a sentinel.
_is_test_sentinel() { return 1; }
RUNNER
    _extract_block >> "$script"
    bash "$script"
}

@test "t1: T-2067 block contains exactly one python3 -c invocation (not per-file)" {
    local block
    block="$(_extract_block)"
    # Count actual invocations (`python3 -c`), not mentions in comments.
    local n
    n="$(echo "$block" | grep -c 'python3 -c')"
    [ "$n" -eq 1 ] || { echo "expected 1 python3 -c invocation in T-2067 block, got $n"; return 1; }
}

@test "t2: synthetic 3-file corpus completes in under 5s and warns" {
    local start=$(date +%s)
    run _run_block
    local end=$(date +%s)
    local dur=$((end - start))
    [ "$status" -eq 0 ]
    [ "$dur" -lt 5 ] || { echo "block too slow: ${dur}s"; return 1; }
    # WARN must fire (we planted 2 bad files)
    [[ "$output" == *"WARN:"* ]]
    [[ "$output" == *"unparseable YAML"* ]]
}

@test "t3: warn message names both T-2067 and T-2069 classes" {
    run _run_block
    [ "$status" -eq 0 ]
    # Both class descriptors must be present in the warn's mitigation text
    [[ "$output" == *"T-2067 class"* ]]
    [[ "$output" == *"T-2069 class"* ]]
}
