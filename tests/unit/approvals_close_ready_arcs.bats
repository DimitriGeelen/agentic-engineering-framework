#!/usr/bin/env bats
# T-1961: _load_close_ready_arcs() filter logic.
#
# Pinned via fixture arc YAMLs + fixture anchor task with `## Recommendation`.
# Three filter dimensions:
#   1. status == "in-progress" (closed/abandoned/draft excluded)
#   2. completion_ratio >= 0.80
#   3. anchor-task has a non-empty `## Recommendation` block (verdict OK to be '?')

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$PROJECT_ROOT"
    FIXTURE_ROOT="$(mktemp -d)"
    mkdir -p "$FIXTURE_ROOT/.context/arcs" "$FIXTURE_ROOT/.tasks/active" "$FIXTURE_ROOT/.tasks/completed"
    export FIXTURE_ROOT
}

teardown() {
    if [ -n "${FIXTURE_ROOT:-}" ] && [ -d "$FIXTURE_ROOT" ]; then
        rm -rf "$FIXTURE_ROOT"
    fi
}

# Helper: write an anchor task body + a constituent task with the given status.
# args: task_id status [rec_block]
write_task() {
    local tid="$1" status="$2" rec="${3:-}"
    local sub="active"
    [ "$status" = "work-completed" ] && sub="completed"
    cat >"$FIXTURE_ROOT/.tasks/$sub/$tid-fixture.md" <<EOF
---
id: $tid
name: "Fixture $tid"
status: $status
workflow_type: build
owner: claude-code
horizon: now
tags: []
---

# $tid

$rec
EOF
}

# Helper: write an arc YAML
write_arc() {
    local slug="$1" id="$2" status="$3" anchor="$4"; shift 4
    local constituents="$@"
    {
        echo "id: $id"
        echo "slug: $slug"
        echo "name: \"Fixture arc $slug\""
        echo "status: $status"
        echo "anchor_task: $anchor"
        echo "constituent_tasks:"
        for t in $constituents; do
            echo "  - $t"
        done
    } >"$FIXTURE_ROOT/.context/arcs/$slug.yaml"
}

run_loader() {
    PROJECT_ROOT="$FIXTURE_ROOT" python3 -c "
import os, sys
sys.path.insert(0, '$PROJECT_ROOT')
os.environ['PROJECT_ROOT'] = '$FIXTURE_ROOT'
# Reload web.shared with new PROJECT_ROOT.
import importlib, web.shared
importlib.reload(web.shared)
import web.blueprints.arcs as a
importlib.reload(a)
import web.blueprints.approvals as ap
importlib.reload(ap)
import json
print(json.dumps(ap._load_close_ready_arcs()))
"
}

@test "arc with status=in-progress, ratio<0.80, rec present → excluded" {
    write_task T-9001 work-completed $'\n## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** ok.\n'
    write_task T-9002 started-work
    write_task T-9003 started-work
    # Anchor T-9001 has rec; only 1/3 = 0.33 completed → excluded.
    write_arc low-ratio arc-301 in-progress T-9001 T-9001 T-9002 T-9003
    out=$(run_loader)
    [[ "$out" == "[]" ]]
}

@test "arc with status=in-progress, ratio>=0.80, no rec → excluded" {
    write_task T-9011 work-completed
    write_task T-9012 work-completed
    write_task T-9013 work-completed
    write_task T-9014 work-completed
    write_task T-9015 started-work
    # 4/5 = 0.80, but anchor T-9011 has NO recommendation block.
    write_arc no-rec arc-302 in-progress T-9011 T-9011 T-9012 T-9013 T-9014 T-9015
    out=$(run_loader)
    [[ "$out" == "[]" ]]
}

@test "arc with status=in-progress, ratio>=0.80, rec present → included" {
    write_task T-9021 work-completed $'\n## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** Demo wire-fired.\n'
    write_task T-9022 work-completed
    write_task T-9023 work-completed
    write_task T-9024 work-completed
    write_task T-9025 started-work
    # 4/5 = 0.80 with rec present → INCLUDED.
    write_arc happy-path arc-303 in-progress T-9021 T-9021 T-9022 T-9023 T-9024 T-9025
    out=$(run_loader)
    [[ "$out" == *'"slug": "happy-path"'* ]]
    [[ "$out" == *'"verdict": "CLOSE"'* ]]
    [[ "$out" == *'"completed": 4'* ]]
}

@test "arc with status=closed is excluded regardless of completion + rec" {
    write_task T-9031 work-completed $'\n## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** ok.\n'
    write_task T-9032 work-completed
    write_arc already-closed arc-304 closed T-9031 T-9031 T-9032
    out=$(run_loader)
    [[ "$out" == "[]" ]]
}

@test "verdict is captured per arc (CLOSE / KEEP-OPEN / GO)" {
    write_task T-9041 work-completed $'\n## Recommendation\n\n**Recommendation:** KEEP-OPEN\n\n**Rationale:** Headline-mechanic instance missing.\n'
    write_task T-9042 work-completed
    write_task T-9043 work-completed
    write_task T-9044 work-completed
    write_task T-9045 work-completed
    write_arc keep-open arc-305 in-progress T-9041 T-9041 T-9042 T-9043 T-9044 T-9045
    out=$(run_loader)
    [[ "$out" == *'"verdict": "KEEP-OPEN"'* ]]
}

@test "anchor task with empty ## Recommendation body → excluded" {
    write_task T-9051 work-completed $'\n## Recommendation\n\n<!-- still drafting -->\n'
    write_task T-9052 work-completed
    write_task T-9053 work-completed
    write_task T-9054 work-completed
    write_task T-9055 work-completed
    write_arc empty-rec arc-306 in-progress T-9051 T-9051 T-9052 T-9053 T-9054 T-9055
    out=$(run_loader)
    [[ "$out" == "[]" ]]
}
