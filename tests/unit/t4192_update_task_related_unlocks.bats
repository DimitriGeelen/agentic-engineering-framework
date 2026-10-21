#!/usr/bin/env bats
# T-4192 — `fw task update T-XXX --related T-YYY --unlocks T-AAA:decision-id`.
#
# related_tasks: and unlocks_inception_decision: were hand-edit only: the arg
# loop had no flag for either and ends in `*) Unknown option; exit 1`, so the
# GO-scope close gate (reads related_tasks) could not be satisfied through the
# CLI (832 OBS-453, their T-1150). Pinned here:
#   1. APPEND — existing entries are kept, duplicates are not repeated.
#   2. RESOLVE — an id that does not resolve (missing task, missing inception
#      decision, malformed, self-reference) is refused non-zero.
#   3. VALIDATE-BEFORE-MUTATE (L-286) — a refusal leaves the file byte-identical,
#      even when another id in the same call was valid.
# Runs in a throwaway project (T-4523 pattern), never the framework checkout.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    UPDATE="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
        "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    export PROJECT_ROOT
    cd "$PROJECT_ROOT"
    SUBJ="$PROJECT_ROOT/.tasks/active/T-0001-subject.md"
    cat > "$SUBJ" <<'EOF'
---
id: T-0001
name: "t4192 subject"
description: fixture
status: captured
workflow_type: build
horizon: later
owner: agent
tags: []
components: []
related_tasks: [T-0002]
created: 2026-10-22T00:00:00Z
last_update: 2026-10-22T00:00:00Z
---

## Context

fixture
EOF
    cat > "$PROJECT_ROOT/.tasks/completed/T-0002-other.md" <<'EOF'
---
id: T-0002
name: "other"
status: work-completed
workflow_type: build
owner: agent
---
EOF
    cat > "$PROJECT_ROOT/.tasks/active/T-0003-third.md" <<'EOF'
---
id: T-0003
name: "third"
status: captured
workflow_type: build
owner: agent
---
EOF
    cat > "$PROJECT_ROOT/.tasks/completed/T-0004-incep.md" <<'EOF'
---
id: T-0004
name: "inception"
status: work-completed
workflow_type: inception
owner: human
inception_decisions:
  - id: ship-it
    text: ship the thing
    ships_in: T-0002
---
EOF
}

_fm() { python3 -c 'import sys,yaml; t=open(sys.argv[1]).read().split("---")[1]; d=yaml.safe_load(t); print(d.get(sys.argv[2]))' "$SUBJ" "$1"; }

@test "t4192: --related appends a resolving id and keeps existing entries" {
    run "$UPDATE" T-0001 --related T-0003
    [ "$status" -eq 0 ]
    [ "$(_fm related_tasks)" = "['T-0002', 'T-0003']" ]
    grep -q -- "- \*\*Change:\*\* related_tasks: +T-0003" "$SUBJ"
}

@test "t4192: --related dedups and accepts comma lists and repeated flags" {
    run "$UPDATE" T-0001 --related T-0002,T-0003 --related T-0003
    [ "$status" -eq 0 ]
    [ "$(_fm related_tasks)" = "['T-0002', 'T-0003']" ]
}

@test "t4192: --related converts a block-list field and keeps its entries" {
    python3 - "$SUBJ" <<'EOF'
import sys; p=sys.argv[1]; s=open(p).read()
open(p,"w").write(s.replace("related_tasks: [T-0002]\n","related_tasks:\n  - T-0002\n"))
EOF
    run "$UPDATE" T-0001 --related T-0003
    [ "$status" -eq 0 ]
    [ "$(_fm related_tasks)" = "['T-0002', 'T-0003']" ]
}

@test "t4192: --unlocks appends a known inception decision (field absent before)" {
    run "$UPDATE" T-0001 --unlocks T-0004:ship-it
    [ "$status" -eq 0 ]
    [ "$(_fm unlocks_inception_decision)" = "['T-0004:ship-it']" ]
    [ "$(_fm related_tasks)" = "['T-0002']" ]
}

@test "t4192: unresolved ids are refused and the file is byte-identical" {
    before=$(sha256sum "$SUBJ")
    for args in "--related T-9999" "--related T-0003,T-9999" "--related bogus" \
                "--related T-0001" "--unlocks T-0004:no-such" "--unlocks T-9999:x" \
                "--unlocks T-0004" "--related T-0003 --unlocks T-0004:no-such"; do
        # shellcheck disable=SC2086
        run "$UPDATE" T-0001 $args
        [ "$status" -ne 0 ]
        [ "$(sha256sum "$SUBJ")" = "$before" ]
    done
}
