#!/usr/bin/env bats
# T-5251 (T-5224 slice 2): fw arc owner | journal | resume.
#
# Every test runs against a temporary PROJECT_ROOT; the real .context/arcs,
# arc-focus.yaml and focus.yaml are never touched.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    unset CONTEXT_DIR TASKS_DIR FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY \
          FW_SIDECAR_AGENT_ID FW_AGENT_ID _FW_PATHS_DERIVED_BY
    local td="$PROJECT_ROOT/.tasks"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working" "$td/active" "$td/completed"
    printf 'session_id: S-TEST-1\n' > "$PROJECT_ROOT/.context/working/session.yaml"

    cat > "$ARCS_DIR/demo-arc.yaml" <<'YAML'
# Arc fixture header comment (must survive)
id: arc-901
slug: demo-arc
name: "Demo arc"   # inline comment
status: in-progress
scoped_drivers: []   # max 3, weight <=6 each (M2)
description: >
  folded text
  over two lines
YAML
    cp "$ARCS_DIR/demo-arc.yaml" "$BATS_TEST_TMPDIR/original.yaml"

    _task T-9001 started-work demo-arc "open member"
    _task T-9002 captured arc-901 "captured member by numeric id"
    _task T-9003 started-work other-arc "not a member"
}

_task() {
    local tid="$1" status="$2" arc="$3" name="$4"
    printf -- '---\nid: %s\nname: "%s"\nstatus: %s\nhorizon: now\narc_id: %s\nowner: agent\n---\n\n# %s\n' \
        "$tid" "$name" "$status" "$arc" "$tid" "$name" > "$PROJECT_ROOT/.tasks/active/${tid}-fixture.md"
}

arc() {
    bash -c '. "$FRAMEWORK_ROOT/lib/arc.sh"; arc_dispatch "$@"' _ "$@"
}

# yaml.safe_load sees the same document, minus the owner/journal keys
_strip_owner() {
    python3 - "$1" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
d.pop("journal", None); d.pop("owner", None)
print(sorted(d.items()))
PY
}

@test "owner on: journal true + owner block, other fields and comments kept" {
    run arc owner demo-arc on --wake worker
    [ "$status" -eq 0 ]
    f="$ARCS_DIR/demo-arc.yaml"
    grep -q '^journal: true$' "$f"
    grep -q '^  role: "on"$' "$f"
    grep -q '^  wake: worker$' "$f"
    grep -q '^  since: "' "$f"
    grep -q '^# Arc fixture header comment (must survive)$' "$f"
    grep -q '^name: "Demo arc"   # inline comment$' "$f"
    grep -q '^scoped_drivers: \[\]   # max 3, weight <=6 each (M2)$' "$f"
    [ "$(_strip_owner "$f")" = "$(_strip_owner "$BATS_TEST_TMPDIR/original.yaml")" ]
    python3 -c 'import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); assert d["journal"] is True and d["owner"]["role"]=="on" and d["owner"]["wake"]=="worker"' "$f"
}

@test "owner on/off round trip: off keeps the journal file, one owner block, original lines intact" {
    arc owner arc-901 on
    arc journal demo-arc tried --text "spike" --result "ok"
    run arc owner demo-arc off
    [ "$status" -eq 0 ]
    f="$ARCS_DIR/demo-arc.yaml"
    grep -q '^journal: false$' "$f"
    grep -q '^  role: "off"$' "$f"
    grep -q '^  wake: notice$' "$f"
    [ "$(grep -c '^owner:' "$f")" -eq 1 ]
    [ "$(grep -c '^journal:' "$f")" -eq 1 ]
    [ -s "$ARCS_DIR/demo-arc.journal.jsonl" ]
    # removing the two added keys gives back the original file byte for byte
    python3 - "$f" "$BATS_TEST_TMPDIR/original.yaml" <<'PY'
import re, sys
cur = open(sys.argv[1]).read().splitlines()
out, skip = [], False
for ln in cur:
    if ln.startswith("owner:"): skip = True; continue
    if skip and ln.startswith("  "): continue
    skip = False
    if ln.startswith("journal:"): continue
    out.append(ln)
assert out == open(sys.argv[2]).read().splitlines(), out
PY
    # wake carries over when switched back on without --wake
    arc owner demo-arc on --wake worker
    arc owner demo-arc off
    arc owner demo-arc on
    grep -q '^  wake: worker$' "$f"
}

@test "owner: bad mode / bad wake / unknown arc refused" {
    run arc owner demo-arc maybe
    [ "$status" -eq 2 ]
    run arc owner demo-arc on --wake loud
    [ "$status" -ne 0 ]
    run arc owner no-such-arc on
    [ "$status" -ne 0 ]
    ! grep -q '^journal:' "$ARCS_DIR/demo-arc.yaml" || false
}

@test "show displays owner and journal state; arcs without it say not set" {
    run arc show demo-arc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Owner: not set   Journal: off"* ]]
    arc owner demo-arc on
    run arc show demo-arc
    [[ "$output" == *"Owner: on (wake notice, since "* ]]
    [[ "$output" == *"Journal: on"* ]]
}

@test "journal refused when the arc is not switched on, naming fw arc owner" {
    run arc journal demo-arc decided --text x --reason y
    [ "$status" -eq 1 ]
    [[ "$output" == *"fw arc owner demo-arc on"* ]]
    [ ! -e "$ARCS_DIR/demo-arc.journal.jsonl" ]
    arc owner demo-arc on
    arc owner demo-arc off
    run arc journal demo-arc decided --text x --reason y
    [ "$status" -eq 1 ]
}

@test "journal written when on; by defaults to session id, then FW_SIDECAR_AGENT_ID; --by wins" {
    arc owner demo-arc on
    run arc journal demo-arc decided --text "use B" --reason "A slow" --consequential
    [ "$status" -eq 0 ]
    FW_SIDECAR_AGENT_ID=sidecar-7 arc journal arc-901 tried --text t --result r
    arc journal demo-arc outside --text "freeze lifted" --reason "release" --where "chat" --by operator
    j="$ARCS_DIR/demo-arc.journal.jsonl"
    python3 - "$j" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["kind"] for r in rows] == ["decided", "tried", "outside"], rows
assert rows[0]["by"] == "S-TEST-1" and rows[0]["consequential"] is True
assert rows[1]["by"] == "sidecar-7"
assert rows[2]["by"] == "operator" and rows[2]["where"] == "chat"
PY
}

@test "journal validation comes from arc_journal.py; event kind refused by hand" {
    arc owner demo-arc on
    run arc journal demo-arc next --step "x"
    [ "$status" -eq 2 ]
    [[ "$output" == *"needs 'owner'"* ]]
    run arc journal demo-arc next --step x --owner a --deadline tomorrow
    [ "$status" -eq 2 ]
    run arc journal demo-arc event --task T-1 --from a --to b
    [ "$status" -eq 2 ]
    [ ! -s "$ARCS_DIR/demo-arc.journal.jsonl" ]
}

@test "resume on a non-resumable arc: exit 1, findings shown, brief printed, arc focus set, task focus NOT moved" {
    arc owner demo-arc on
    arc journal demo-arc next --step "old step" --owner agent --task T-9001
    arc journal demo-arc decided --text "pivot" --reason "evidence"
    run arc resume demo-arc
    [ "$status" -eq 1 ]
    [[ "$output" == *"NOT resumable"* ]]
    [[ "$output" == *"STALE_NEXT"* ]]
    [[ "$output" == *"pivot"* ]]
    [[ "$output" == *"old step"* ]]
    grep -q '^current_arc: demo-arc$' "$ARC_FOCUS_FILE"
    # A stale next step must not steer focus (1409: stale next worse than none).
    [ ! -e "$PROJECT_ROOT/.context/working/focus.yaml" ] || ! grep -q '^current_task: T-9001$' "$PROJECT_ROOT/.context/working/focus.yaml"
    [[ "$output" == *"Task focus NOT moved to T-9001"* ]]
}

@test "resume on a resumable arc: exit 0, brief sections, decisions newest first and capped, focus set" {
    arc owner demo-arc on
    for i in 1 2 3 4 5 6 7; do arc journal demo-arc decided --text "d$i" --reason "r$i"; done
    arc journal demo-arc outside --text "o8" --reason "r8" --where "chat"
    arc journal demo-arc next --step "build B" --owner agent --deadline 2099-01-01 --task T-9001
    run arc resume arc-901
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESUMABLE"* ]]
    [[ "$output" == *"build B"* ]]
    [[ "$output" == *"owner: agent   deadline: 2099-01-01"* ]]
    [[ "$output" == *"T-9001 [started-work/now]"* ]]
    [[ "$output" == *"T-9002 [captured/now]"* ]]
    [[ "$output" != *"T-9003"* ]]
    # newest first, capped at 5: o8 d7 d6 d5 d4 shown, d3 not
    [[ "$output" == *"o8"* ]]
    [[ "$output" != *"d3 "* ]]
    o8=$(grep -n 'o8' <<<"$output" | head -1 | cut -d: -f1)
    d4=$(grep -n ' d4 ' <<<"$output" | head -1 | cut -d: -f1)
    [ "$o8" -lt "$d4" ]
    grep -q '^current_arc: demo-arc$' "$ARC_FOCUS_FILE"
    grep -q '^current_task: T-9001$' "$PROJECT_ROOT/.context/working/focus.yaml"
    [[ "$output" == *"Task focus → T-9001"* ]]
}

@test "resume: next names a task that is not active → no task focus" {
    arc owner demo-arc on
    arc journal demo-arc next --step "later" --owner agent --task T-4242
    run arc resume demo-arc
    [ "$status" -eq 0 ]
    [ ! -e "$PROJECT_ROOT/.context/working/focus.yaml" ]
}

@test "resume on an arc with no journal: NOT resumable (NO_NEXT), exit 1" {
    run arc resume demo-arc
    [ "$status" -eq 1 ]
    [[ "$output" == *"NO_NEXT"* ]]
}

@test "help and verb-list name owner, journal, resume; no handover verb" {
    run arc help
    [[ "$output" == *"owner <id> on"* ]]
    [[ "$output" == *"journal <id> tried|decided|next|outside"* ]]
    [[ "$output" == *"resume <id>"* ]]
    head -80 "$FRAMEWORK_ROOT/lib/arc.sh" | grep -q '^#   owner <slug-or-id>'
    head -80 "$FRAMEWORK_ROOT/lib/arc.sh" | grep -q '^#   journal <slug-or-id>'
    head -80 "$FRAMEWORK_ROOT/lib/arc.sh" | grep -q '^#   resume <slug-or-id>'
    ! grep -qE '^[[:space:]]+handover\)' "$FRAMEWORK_ROOT/lib/arc.sh" || false
    run arc handover demo-arc
    [ "$status" -eq 2 ]
}
