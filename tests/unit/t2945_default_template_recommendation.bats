#!/usr/bin/env bats
# T-2945 — default.md shipped no `## Recommendation`, so the section the review
# gate demands existed in only one of the two templates that reach it.
#
# lib/review.sh:205-211 (T-2421) BLOCKS `fw task review` emission for
# build/refactor/test/decommission tasks in the partial-complete state (Agent ACs
# done, >=1 `### Human` AC unticked) whose `## Recommendation` block is empty.
# inception.md carried the block; default.md did not. Reported by 832 as T-455.
#
# These tests drive the REAL `fw task review` against a sandbox PROJECT_ROOT and
# build every fixture FROM THE SHIPPED TEMPLATE — so the tests stay coupled to
# the template rather than to a copy of it. Delete the section and legs 2/3 go
# red; make the section self-satisfying and leg 1 goes red.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TEMPLATE="$FRAMEWORK_ROOT/.tasks/templates/default.md"
    SANDBOX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working"
}

# Build a task from the SHIPPED template.
#   $1 = task id
#   $2 = "unticked" | "ticked"   (the Human AC state)
#   $3 = "empty" | "filled"      (the Recommendation block state)
_task_from_template() {
    local id="$1" human="$2" rec="$3"
    local box="- [ ]"
    [ "$human" = "ticked" ] && box="- [x]"
    {
        printf -- '---\nid: %s\nname: "sandbox"\nstatus: started-work\n' "$id"
        printf 'workflow_type: build\nowner: agent\n---\n'
        # Body of the shipped template, with one real Agent AC and one real
        # Human AC injected at column 0 (the counter in review.sh:174 matches
        # `- [ ]` only at the start of a line).
        # Strip the template's own frontmatter: everything up to and including
        # the SECOND `---`. (`sed '1,/^---$/d'` alone would do it, since the
        # range end is searched from line 2 — but stating the delimiter count
        # explicitly is what stops the next reader repeating the mistake that
        # cost this test its first run: chaining a second strip deletes to EOF.)
        awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2 {print}' "$TEMPLATE" \
        | sed -e "s|^- \[ \] \[First criterion\]|- [x] a real agent criterion|" \
              -e "s|^- \[ \] \[Second criterion\]||" \
              -e "s|^### Human$|### Human\n${box} [REVIEW] a genuine human criterion|"
    } > "$SANDBOX/.tasks/active/${id}-x.md"

    if [ "$rec" = "filled" ]; then
        # Fill the block the template ships. If the heading is absent this is a
        # no-op and the leg that depends on it fails — which is the point.
        sed -i "s|^## Recommendation$|## Recommendation\n\n**Recommendation:** GO\n**Rationale:** agent ACs pass; one human check remains\n|" \
            "$SANDBOX/.tasks/active/${id}-x.md"
    fi
}

_review() {
    PROJECT_ROOT="$SANDBOX" timeout 60 "$FRAMEWORK_ROOT/bin/fw" task review "$1" >/dev/null 2>&1
}

@test "t2945: template-derived partial-complete task with an UNFILLED block is refused" {
    # The false-green guard. Shipping the section must not itself satisfy the
    # gate — otherwise the fix trades a refusal for a blank Recommendation card.
    _task_from_template T-9101 unticked empty
    run _review T-9101
    [ "$status" -ne 0 ] || {
        echo "unfilled template block satisfied the gate — false green" >&2
        return 1
    }
}

@test "t2945: the same task emits once the shipped block is filled in" {
    # The fix. The section default.md now ships is the shape the gate's parser
    # (audit_inception_recommendation) accepts — copied from inception.md, not
    # reinvented.
    _task_from_template T-9102 unticked filled
    run _review T-9102
    [ "$status" -eq 0 ] || {
        echo "filled Recommendation still refused emission (status=$status)" >&2
        return 1
    }
}

@test "t2945: positive control — with every Human AC ticked the gate never fires" {
    # Without this, leg 1 is equally satisfied by a gate that refuses
    # unconditionally. The gate is scoped to the partial-complete transition:
    # human_total > 0 AND human_checked < human_total.
    _task_from_template T-9103 ticked empty
    run _review T-9103
    [ "$status" -eq 0 ] || {
        echo "gate fired on a fully-ticked task (status=$status) — over-refusal" >&2
        return 1
    }
}

@test "t2945: default.md ships exactly one ## Recommendation heading" {
    run bash -c "grep -c '^## Recommendation$' '$TEMPLATE'"
    [ "$output" -eq 1 ]
}

@test "t2945: both templates' unfilled blocks are rejected by the same parser" {
    # Shape parity. The gate is shared between inception and build-class tasks,
    # so the two templates must agree about what an unfilled block looks like.
    source "$FRAMEWORK_ROOT/lib/task-audit.sh"
    run audit_inception_recommendation "$TEMPLATE"
    [ "$status" -ne 0 ]
    run audit_inception_recommendation "$FRAMEWORK_ROOT/.tasks/templates/inception.md"
    [ "$status" -ne 0 ]
}

@test "t2945: the documented bypass still emits" {
    # T-1890 producer/consumer parity: the block message names
    # FW_ALLOW_EMPTY_RECOMMENDATION=1, so that path must actually work.
    _task_from_template T-9104 unticked empty
    run env PROJECT_ROOT="$SANDBOX" FW_ALLOW_EMPTY_RECOMMENDATION=1 \
        timeout 60 "$FRAMEWORK_ROOT/bin/fw" task review T-9104
    [ "$status" -eq 0 ]
}
