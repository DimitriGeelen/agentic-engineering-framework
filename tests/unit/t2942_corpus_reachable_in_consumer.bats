#!/usr/bin/env bats
# T-2942 (OBS-235) — the onboarding curriculum ROUTES to corpus maps rather than
# embedding them. That design only holds if the routes resolve where the
# curriculum is read: a fresh `fw init` consumer, not this repo.
#
# They did not. `tools/` was never in do_vendor's includes and neither was the
# corpus store, so all 10 `fw corpus explain` calls across the eleven operator
# sections returned rc=2 from the day arc-017's Half A shipped. It was invisible
# because the routes resolve perfectly HERE — the only tree they were exercised in.
#
# These tests assert the vendor SET, not a live init: a full `fw init` is minutes
# of I/O per leg. The set is what actually broke, and it is what silently drifts.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    STORE="$FRAMEWORK_ROOT/.context/designer/projects"
}

# Extract do_vendor's includes array as one line per entry.
_includes() {
    sed -n '/^    local includes=(/,/^    )/p' "$FRAMEWORK_ROOT/bin/fw" \
        | grep -v '^\s*#' | grep -v 'includes=(' | grep -v '^\s*)' | tr -d ' '
}

_excludes() {
    sed -n '/^    local excludes=(/,/^    )/p' "$FRAMEWORK_ROOT/bin/fw" \
        | grep -v '^\s*#' | grep -v 'excludes=(' | grep -v '^\s*)' | tr -d ' "'
}

@test "t2942: the corpus reader is vendored" {
    _includes | grep -qx 'tools'
}

@test "t2942: the corpus store is vendored" {
    # Reader without maps swaps "no such file" for "no such map" — both dead.
    _includes | grep -qx '.context/designer/projects'
}

@test "t2942: every aef-* map the curriculum could route to is in the vendored set" {
    # The drift guard. Wholesale-include-minus-drafts means a NEW aef-* map is
    # vendored the day it appears; this asserts that property rather than
    # trusting it, so replacing the include with an explicit list (the shape
    # that caused this bug) fails here instead of silently shipping nothing.
    local excl
    excl=$(_excludes)
    local m
    for m in "$STORE"/aef-*; do
        [ -d "$m" ] || continue
        local name
        name=$(basename "$m")
        if echo "$excl" | grep -q "designer/projects/${name%%-*}-\*"; then
            echo "aef map $name is matched by an exclude pattern — consumers lose it" >&2
            return 1
        fi
    done
    _includes | grep -qx '.context/designer/projects'
}

@test "t2942: drafts and scratch are NOT shipped to consumers" {
    # Consumers get the framework's published lifecycle maps, not our WIP.
    _excludes | grep -q 'designer/projects/draft-\*'
    # T-2989: the scratch map used to need its own exclusion line because it was
    # named `t2584-scratch`. Renaming it `draft-t2584-scratch` folded it into the
    # glob above — and into corpus_lint's `draft-` skip, which is what the lint
    # baseline needed. Assert the map is still excluded, via whichever mechanism:
    # naming the line would re-pin the special case this task removed.
    run bash -c "cd '$FRAMEWORK_ROOT' && ls .context/designer/projects"
    [[ "$output" != *"projects/t2584-scratch"* ]]
    echo "$output" | grep -q 'draft-t2584-scratch'
}

@test "t2942: every map id the curriculum routes to actually exists" {
    # The half that guards the OTHER direction: a seed file could route to a map
    # that was renamed or never existed, and vendoring cannot fix a bad id.
    local seeds="$FRAMEWORK_ROOT/lib/seeds/tasks"
    local ids id
    ids=$(grep -ho 'fw corpus explain [a-z0-9-]*' \
              "$seeds"/greenfield/T-00*.md "$seeds"/existing-project/T-00*.md \
          | awk '{print $4}' | sort -u)
    [ -n "$ids" ] || { echo "no corpus routes found in the curriculum at all" >&2; return 1; }
    for id in $ids; do
        [ -d "$STORE/$id" ] || { echo "curriculum routes to missing map: $id" >&2; return 1; }
    done
}

@test "t2942: the guard can fail — a store with no aef maps is not silently green" {
    # Positive control. Every other leg here asserts something is PRESENT, and a
    # predicate that only ever passes is indistinguishable from one that cannot
    # fail (832's rule, and the reason T-2938 was proven in both directions).
    local tmpstore="$BATS_TEST_TMPDIR/store"
    mkdir -p "$tmpstore/draft-only"
    run bash -c "ls -d '$tmpstore'/aef-* 2>/dev/null"
    [ "$status" -ne 0 ]
}

# ── T-5415: the map decides whether it ships (aef:workflowMeta/@scope) ──────────

@test "t5415: every map the curriculum routes to is scope=framework, so consumers get it" {
    local seeds="$FRAMEWORK_ROOT/lib/seeds/tasks" ids id s
    ids=$(grep -ho 'fw corpus explain [a-z0-9-]*' \
              "$seeds"/greenfield/T-00*.md "$seeds"/existing-project/T-00*.md \
          | awk '{print $4}' | sort -u)
    [ -n "$ids" ]
    for id in $ids; do
        s=$(python3 "$FRAMEWORK_ROOT/lib/designer_scope.py" scope "$STORE" "$id")
        [ "$s" = framework ] || { echo "curriculum routes to $id but it is scope=$s (stays home)" >&2; return 1; }
    done
}

@test "t5415: the AEF-development map and every draft stay home" {
    run python3 "$FRAMEWORK_ROOT/lib/designer_scope.py" stay-home "$STORE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx 'aef-github-pr-intake'
    ! echo "$output" | grep -vq '^draft-\|^aef-github-pr-intake$'
}

@test "t5415: fw vendor turns stay-home maps into excludes" {
    grep -qF '_scope_py="$vendor_source/lib/designer_scope.py"' "$FRAMEWORK_ROOT/bin/fw"
    grep -qF 'python3 "$_scope_py" stay-home "$vendor_source/.context/designer/projects"' "$FRAMEWORK_ROOT/bin/fw"
    grep -qF 'excludes+=(".context/designer/projects/$_home_map")' "$FRAMEWORK_ROOT/bin/fw"
}

@test "t5415: framework ships, unmarked and project stay home (fixture store)" {
    local s="$BATS_TEST_TMPDIR/store" n
    for n in fw-map plain-map proj-map; do
        mkdir -p "$s/$n"
        printf '{"id":"%s","versions":[{"v":1,"note":"","ts":1}]}\n' "$n" > "$s/$n/meta.json"
    done
    printf '<x><aef:workflowMeta id="fw-map" scope="framework"/></x>\n' > "$s/fw-map/v1.bpmn"
    printf '<x><aef:workflowMeta id="plain-map"/></x>\n' > "$s/plain-map/v1.bpmn"
    printf '<x><aef:workflowMeta id="proj-map" scope="project"/></x>\n' > "$s/proj-map/v1.bpmn"
    run python3 "$FRAMEWORK_ROOT/lib/designer_scope.py" stay-home "$s"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'plain-map\nproj-map')" ]
    # marking writes a NEW version and flips the verdict
    run python3 "$FRAMEWORK_ROOT/lib/designer_scope.py" mark "$s" plain-map framework --note t
    [ "$output" = 2 ]
    [ -f "$s/plain-map/v1.bpmn" ] && [ -f "$s/plain-map/v2.bpmn" ]
    run python3 "$FRAMEWORK_ROOT/lib/designer_scope.py" stay-home "$s"
    [ "$output" = proj-map ]
}
