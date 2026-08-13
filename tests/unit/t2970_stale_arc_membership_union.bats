#!/usr/bin/env bats
# T-2970 — the stale-arc audit's membership map read `arc_id:` and nothing else.
#
# Arc membership has two forms: the canonical `arc_id:` (T-1849) and the legacy
# `tags: [arc:<slug>]`. `arc_tasks_for` (lib/arc_membership.sh:108) unions them.
# The stale-arc map (agents/audit/audit.sh, T-1855, rewritten for speed by
# T-2298) did not. Measured, canonical reader vs that map:
#
#   horizon-axis-hardening      5   0
#   onboarding-shape-detection  3   0
#   onboarding-curriculum       4   0
#   ladder-trigger-producer     1   0
#   continuous-run             14   6
#   designer-corpus            35  21
#
# The four zeroes then hit:
#
#   # Zero-population arcs can't be assessed for staleness — skip.
#   [ "${#matching_tasks[@]}" -eq 0 ] && continue
#
# which is a REASONED EXCLUSION for an arc with no constituents and a HOLE for an
# arc whose constituents the map cannot see. Same line, no way to tell them apart
# — so the shortfall could not surface, and the section's PASS ("All N
# in-progress arcs...") counted only survivors.
#
# The same union was already added to this file by T-1875 (~line 5250) after the
# identical class cost 163 task-arc relationships across 5 arcs. T-2298's rewrite
# did not carry it across.
#
# These legs extract the REAL map builder from audit.sh rather than restating it,
# so a future edit to the extraction target fails loudly instead of testing a
# copy that has drifted from the original.
#
# COUNTERFACTUAL (measured, pre-fix map body substituted — `arc_id:` only):
#   legs 1 and 3 go red: the legacy-tag-only task, and the mixed arc's count
#   (1 of 2 found). Legs 2, 4 and 5 stay GREEN under both.
#   That split is the finding. Leg 2 (arc_id: still works), leg 4 (a task in no
#   arc emits nothing) and leg 5 (single python3 pass) are PRESERVATION guards —
#   they exist to catch the union over-reaching or reintroducing a per-task fork,
#   and not one of them could have detected the blindness they sit next to. A
#   suite of 2+4+5 alone reports the map healthy while four arcs read as empty.
#
# Stability: 3 consecutive clean runs. One earlier run went red on legs 2-4
# immediately after an edit, with no further change before the clean runs, and
# that discrepancy is unexplained rather than diagnosed. Recorded here so the
# next reader treats a single green as weaker evidence than it looks.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
}

# Run the map builder exactly as audit.sh defines it, against the sandbox root.
# Extracted from source so drift in audit.sh cannot leave this file green.
_run_map() {
    local body
    body=$(awk '/^import os, re$/ {f=1} f {print} f && /^" 2>\/dev\/null\)$/ {exit}' \
             "$FRAMEWORK_ROOT/agents/audit/audit.sh" \
           | sed '$ d' \
           | sed "s|project_root = '\$PROJECT_ROOT'|project_root = '$PROJECT_ROOT'|")
    # Fail loudly rather than silently testing an empty program — an extraction
    # that quietly yields nothing would make every leg pass on no output, which
    # is the exact always-answers shape this file exists to catch.
    case "$body" in
        *arc_id_re*arc_tag_re*) : ;;
        *) echo "EXTRACTION FAILED — audit.sh map builder not found or shape changed" >&2; return 2 ;;
    esac
    python3 -c "$body"
}

_task() {  # $1=dir $2=id $3=frontmatter-lines
    printf -- '---\nid: %s\n%s\n---\n' "$2" "$3" > "$PROJECT_ROOT/.tasks/$1/$2-x.md"
}

@test "a task declaring membership only via legacy arc:<slug> tag is in the map" {
    _task active T-9001 'tags: [arc:onboarding-shape-detection]'
    run _run_map
    [ "$status" -eq 0 ]
    [[ "$output" == *"onboarding-shape-detection"* ]]
    [[ "$output" == *"T-9001"* ]]
}

@test "a task declaring membership via arc_id: is still in the map" {
    _task active T-9002 'arc_id: value-prioritisation'
    run _run_map
    [ "$status" -eq 0 ]
    [[ "$output" == *"value-prioritisation"* ]]
}

@test "an arc with both declaration forms sees every one of its tasks" {
    _task active    T-9003 'arc_id: mixed-arc'
    _task completed T-9004 'tags: [arc:mixed-arc]'
    run _run_map
    [ "$status" -eq 0 ]
    n=$(printf '%s\n' "$output" | grep -c 'mixed-arc')
    [ "$n" -eq 2 ]
}

@test "a task in no arc emits nothing (the union does not over-reach)" {
    _task active T-9005 'tags: [build, cli]'
    run _run_map
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9005"* ]]
}

@test "the map is built by exactly one python3 invocation (T-2298 property)" {
    # The union must not have reintroduced a per-task fork.
    #
    # Count INVOCATIONS, not the string "python3": the first version of this leg
    # grepped the bare word over the stale-arc block and got 3, because two of
    # the hits are in T-2298's own comment explaining that there is only one
    # invocation. It counted prose describing the property as violations of it.
    run bash -c "sed -n '/T-1855 (T-NEW-7): Stale-arc warning/,/had task commits within/p' \
        '$FRAMEWORK_ROOT/agents/audit/audit.sh' | grep -v '^[[:space:]]*#' | grep -c 'python3 -c'"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}
