#!/usr/bin/env bats
# T-2966 — the OBS id allocator recycled ids and could be moved by prose.
#
# Two independent defects lived in one line:
#
#   next_id() { grep -oE 'OBS-[0-9]+' "$INBOX_FILE" | sort -n | tail -1; ...+1 }
#
#   1. FIELD-BLINDNESS — the scan covered the whole file, so an observation whose
#      BODY cited a peer's id dragged the counter up to it. 832 measured their
#      inbox jumping OBS-049 -> OBS-239 by quoting one of ours, in a note written
#      to record this very defect.
#   2. MAX-OVER-SURVIVORS — triage REMOVES the entry it converts into a task, so
#      triaging the highest-numbered observation lowered the max and the next note
#      reused its id. Confirmed live: T-2950 is titled "OBS-238: audit CTL-013…"
#      and a later note was also issued OBS-238.
#
# These legs drive the REAL next_id against a sandbox PROJECT_ROOT and assert the
# ISSUED IDS, not the arithmetic — an allocator that always returns a well-formed
# unused-LOOKING id is exactly what made this invisible. Leg 1 is the one that
# matters: it issues, triages, and issues again, and compares the two ids.
#
# COUNTERFACTUAL (measured against `git show HEAD:agents/observe/observe.sh`):
# legs 1, 2, 4 and 5 go red at their named assertions — reuse-after-triage, the
# prose citation, the emptied inbox, and the id surviving only in a task title.
# Leg 3 stays GREEN under both orderings, and that is the finding: monotonic-in-
# the-easy-case was never the broken part. A suite containing only leg 3 would
# have reported the allocator healthy while it recycled ids, which is the same
# always-answers shape the allocator itself had.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    INBOX="$PROJECT_ROOT/.context/inbox.yaml"
    printf 'observations:\n' > "$INBOX"

    # Source only the allocator, with the script's own path bindings.
    INBOX_FILE="$INBOX"
    OBS_HIGHWATER_FILE="$PROJECT_ROOT/.context/working/.obs-highwater"
    eval "$(sed -n '/^_obs_max_in_inbox()/,/^}/p;/^_obs_max_in_tasks()/,/^}/p;/^next_id()/,/^}/p' \
        "$FRAMEWORK_ROOT/agents/observe/observe.sh")"
}

_add_obs() {  # $1=id  $2=body text
    printf -- '- id: %s\n  text: %s\n' "$1" "$2" >> "$INBOX_FILE"
}

@test "triaging the highest observation does not free its id for reuse" {
    _add_obs "OBS-100" "a real observation"
    first="$(next_id)"
    _add_obs "$first" "the newly issued one"

    # Triage: the entry becomes a task and is REMOVED from the inbox.
    grep -v "id: $first" "$INBOX_FILE" > "$INBOX_FILE.tmp" && mv "$INBOX_FILE.tmp" "$INBOX_FILE"
    printf 'name: "%s: promoted by triage"\n' "$first" > "$PROJECT_ROOT/.tasks/active/T-1-x.md"

    second="$(next_id)"
    [ "$first" = "OBS-101" ]
    [ "$second" != "$first" ]
}

@test "a body citing a peer id does not move the counter" {
    _add_obs "OBS-100" "cites peer OBS-900 as evidence for a cross-project finding"
    run next_id
    # Prose must not be able to push the allocator 800 ids forward.
    [ "$output" = "OBS-101" ]
    [ "$output" != "OBS-901" ]
}

@test "ids stay monotonic across consecutive issues" {
    _add_obs "OBS-100" "seed"
    a="$(next_id)"; _add_obs "$a" "x"
    b="$(next_id)"; _add_obs "$b" "y"
    [ "$a" = "OBS-101" ]
    [ "$b" = "OBS-102" ]
}

@test "high-water mark survives an inbox emptied entirely by triage" {
    _add_obs "OBS-100" "seed"
    a="$(next_id)"
    printf 'observations:\n' > "$INBOX_FILE"   # every entry triaged away
    b="$(next_id)"
    [ "$b" != "$a" ]
    [ "$b" = "OBS-102" ]
}

@test "an id recorded only in a completed task file is not reissued" {
    # The inbox has no memory of it; the task title is the only surviving record.
    printf 'name: "OBS-777: triaged long ago"\n' > "$PROJECT_ROOT/.tasks/completed/T-9-y.md"
    run next_id
    [ "$output" = "OBS-778" ]
}
