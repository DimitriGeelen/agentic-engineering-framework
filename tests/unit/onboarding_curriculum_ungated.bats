#!/usr/bin/env bats
# T-2877 — arc-017 Half A: the human onboarding curriculum.
#
# Three properties, and the second is the one that needs machinery:
#
#   1. PRESENT   — every seeded onboarding task carries a `## For the Operator`
#                  section, in both the greenfield and existing-project sets.
#   2. UNGATED   — the section contains zero checkbox markers, so P-010 cannot
#                  count it and `check-onboarding-gate.py` (which reads only the
#                  `### Human` subsection) cannot see it. "Never blocks the agent"
#                  is therefore a structural fact about the content, not a policy
#                  anyone has to remember. Measured, not asserted: the seeded
#                  tasks' AC counts must be IDENTICAL to their pre-curriculum
#                  counts, and the gate must return 0 for all of them.
#   3. ROUTES    — every corpus-map id named in the curriculum resolves to a real
#                  promoted map. The arc's constraint is "route to corpus maps
#                  rather than embedding content that will drift from them"; a
#                  dangling pointer is the failure mode that constraint creates,
#                  so it is the one this suite watches.
#
# NOT covered here (deliberately): whether the prose is any good. That is a Human
# AC on T-2877 — a static scan cannot read for tone (L-409), and claiming
# otherwise would be the `[REVIEWER]`-for-prose mistake T-1947 exists to catch.

load ../test_helper

SEEDS="$FRAMEWORK_ROOT/lib/seeds/tasks"
HEADING='## For the Operator'

# _section <file> — print the operator section body, empty if absent
_section() {
    python3 - "$1" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
m = re.search(r'^## For the Operator\s*$\n(.*?)(?=^## )', t, re.S | re.M)
sys.stdout.write(m.group(1) if m else '')
PY
}

@test "T-2877: SMOKE — both seed sets exist with the expected populations" {
    # If these counts are wrong every leg below is measuring the wrong tree.
    [ "$(ls "$SEEDS"/greenfield/T-*.md | wc -l)" -eq 5 ]
    [ "$(ls "$SEEDS"/existing-project/T-*.md | wc -l)" -eq 6 ]
}

@test "T-2877: PRESENT — every seeded onboarding task carries the operator section" {
    local missing=0
    for f in "$SEEDS"/*/T-*.md; do
        grep -q "^$HEADING\$" "$f" || { echo "MISSING: $f"; missing=1; }
    done
    [ "$missing" -eq 0 ]
}

@test "T-2877: UNGATED — zero checkbox markers inside any operator section" {
    # A `- [ ]` here would be counted by P-010 as an unmet acceptance criterion,
    # turning readable context into a completion blocker. This is the single
    # assertion that makes 'ungated' structural rather than aspirational.
    local bad=0
    for f in "$SEEDS"/*/T-*.md; do
        if _section "$f" | grep -qE '^\s*[-*]\s*\[[ xX]\]'; then
            echo "CHECKBOX in operator section: $f"; bad=1
        fi
    done
    [ "$bad" -eq 0 ]
}

@test "T-2877: UNGATED — the onboarding refusal gate allows every seeded task" {
    # Half B (T-2815) refuses onboarding tasks that an agent cannot resolve alone.
    # The curriculum must not make any seeded task refusable.
    for f in "$SEEDS"/*/T-*.md; do
        run bash -c "python3 -c \"
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'/tmp/probe/.tasks/active/'+sys.argv[1].split('/')[-1],'content':open(sys.argv[1]).read()}}))\" '$f' \
        | CLAUDECODE=1 python3 '$FRAMEWORK_ROOT/agents/context/check-onboarding-gate.py'"
        [ "$status" -eq 0 ] || { echo "gate refused $f (rc=$status)"; return 1; }
    done
}

@test "T-2877: POSITIVE CONTROL — that gate does refuse something" {
    # Without this, the 11 rc=0 results above are indistinguishable from a gate
    # that is inert. L-555: a check that stops being consulted looks exactly like
    # a check that found nothing.
    local unres="$BATS_TEST_TMPDIR/T-099-unresolvable.md"
    printf -- '---\nid: T-099\nstatus: started-work\nworkflow_type: build\nowner: agent\ntags: [onboarding]\n---\n\n## Acceptance Criteria\n\n### Human\n- [ ] someone must eyeball this\n' > "$unres"
    run bash -c "python3 -c \"
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'/tmp/probe/.tasks/active/T-099-x.md','content':open(sys.argv[1]).read()}}))\" '$unres' \
    | CLAUDECODE=1 python3 '$FRAMEWORK_ROOT/agents/context/check-onboarding-gate.py'"
    [ "$status" -eq 2 ]
}

@test "T-2877: ROUTES — every corpus-map id named in the curriculum resolves" {
    local ids
    ids=$(for f in "$SEEDS"/*/T-*.md; do _section "$f"; done \
          | grep -oE 'fw corpus explain [a-z0-9-]+' | awk '{print $4}' | sort -u)
    [ -n "$ids" ]     # a curriculum that routes nowhere is not routing
    local id
    for id in $ids; do
        run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw corpus explain '$id' >/dev/null 2>&1"
        [ "$status" -eq 0 ] || { echo "DANGLING map id: $id"; return 1; }
    done
}

@test "T-2877: ROUTES — every operator section points somewhere" {
    # Routing is the arc constraint; a section that only narrates has quietly
    # become embedded content, which is what drifts.
    local bad=0 sec
    for f in "$SEEDS"/*/T-*.md; do
        sec=$(_section "$f")
        echo "$sec" | grep -qE 'fw corpus explain|Watchtower' || { echo "NO ROUTE: $f"; bad=1; }
    done
    [ "$bad" -eq 0 ]
}

@test "T-2877: TEETH — a stripped section is caught" {
    # DURABLE MUTATION of live source (T-2874), not a ref-based check that goes
    # inert on the next commit and skips while reporting ok.
    local victim="$SEEDS/greenfield/T-003-first-governed-commit.md"
    local mutant="$BATS_TEST_TMPDIR/stripped.md"
    python3 - "$victim" "$mutant" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
open(sys.argv[2], 'w').write(re.sub(r'^## For the Operator\s*$\n.*?(?=^## )', '', t, flags=re.S | re.M))
PY
    local delta; delta=$(diff "$victim" "$mutant" || true)   # diff exits 1 on differs (L-387)
    [ -n "$delta" ]                                          # a no-op mutation proves nothing
    grep -q "^$HEADING\$" "$victim"                          # ...and the original still has it
    ! grep -q "^$HEADING\$" "$mutant"                        # THE DEFECT: detector fires
}

@test "T-2877: TEETH — a dangling map id is caught" {
    # The failure mode the routing constraint creates: a map is renamed or
    # unpromoted and the curriculum keeps pointing at the old id. Silent, because
    # prose does not fail to compile.
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw corpus explain aef-deliberately-not-a-map >/dev/null 2>&1"
    [ "$status" -ne 0 ]
    # ...and the resolver used above says yes to a real one, so the check
    # distinguishes rather than merely refusing everything.
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw corpus explain aef-task-lifecycle >/dev/null 2>&1"
    [ "$status" -eq 0 ]
}

@test "T-2877: vendored parity — consumers get the curriculum too" {
    # .agentic-framework/ is what a consumer's fw executes (T-2240 self-vendor
    # drift). A curriculum that exists only in lib/ ships to nobody.
    local f v
    for f in "$SEEDS"/*/T-*.md; do
        v="$FRAMEWORK_ROOT/.agentic-framework/lib/seeds/tasks/${f#$SEEDS/}"
        [ -f "$v" ] || { echo "NOT VENDORED: $f"; return 1; }
        diff -q "$f" "$v" >/dev/null || { echo "VENDOR DRIFT: $f"; return 1; }
    done
}
