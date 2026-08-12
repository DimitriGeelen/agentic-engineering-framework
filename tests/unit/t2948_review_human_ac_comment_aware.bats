#!/usr/bin/env bats
# T-2948 — lib/review.sh's Human-AC counter was comment-immune BY ACCIDENT.
#
# Its globs are `"- [ ]"*` — whitespace-intolerant — and default.md's commented
# example ACs happen to sit indented seven spaces. Nothing in the file recorded
# that the indentation was load-bearing. De-indenting those examples (pure
# formatting, the kind no reviewer stops) would have made the counter see two
# phantom Human ACs on EVERY task created from the template: each fresh build
# task reads as partial-complete 0/2 and trips T-2421's rec-gate on work nobody
# has started.
#
# Reported by 832 at rail 570 §3, as the negative control of their own census —
# the finding came out of explaining why their count was RIGHT.
#
# These legs drive the REAL `fw task review` against a sandbox PROJECT_ROOT.
# The de-indent fixture is the landmine, built from the shipped template.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TEMPLATE="$FRAMEWORK_ROOT/.tasks/templates/default.md"
    SANDBOX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$SANDBOX/.tasks/active"
}

# $1 = id, $2 = "indented" (as shipped) | "deindented" (the landmine)
_task_from_template() {
    local id="$1" mode="$2"
    {
        printf -- '---\nid: %s\nname: "sandbox"\nstatus: started-work\n' "$id"
        printf 'workflow_type: build\nowner: agent\n---\n'
        # Body only: strip up to and including the SECOND `---`.
        awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2 {print}' "$TEMPLATE" \
        | sed -e "s|^- \[ \] \[First criterion\]|- [x] a real agent criterion|" \
              -e "s|^- \[ \] \[Second criterion\]||"
    } > "$SANDBOX/.tasks/active/${id}-x.md"

    if [ "$mode" = "deindented" ]; then
        # The formatting change nobody would stop: pull the template's commented
        # example ACs out to column 0. They are still inside `<!-- ... -->`.
        sed -i -E 's|^[[:space:]]+- \[([ xX])\]|- [\1]|' "$SANDBOX/.tasks/active/${id}-x.md"
    fi
}

# The PRE-FIX counter, verbatim from lib/review.sh before T-2948. Used to prove
# the fixture is a real landmine rather than an inert file.
_count_human_prefix() {
    local task_file="$1"
    local human_total=0 in_ac=false in_human=false
    while IFS= read -r line; do
        case "$line" in
            "## Acceptance Criteria"*) in_ac=true; in_human=false; continue ;;
            "## "*) if $in_ac; then break; fi ;;
            "### Human"*) if $in_ac; then in_human=true; continue; fi ;;
            "### "*) if $in_human; then in_human=false; fi ;;
        esac
        if $in_human; then
            case "$line" in
                "- [ ]"*|"- [x]"*|"- [X]"*) human_total=$((human_total + 1)) ;;
            esac
        fi
    done < "$task_file"
    echo "$human_total"
}

_review() {
    PROJECT_ROOT="$SANDBOX" timeout 60 "$FRAMEWORK_ROOT/bin/fw" task review "$1" >/dev/null 2>&1
}

@test "t2948: de-indenting the template's commented examples does NOT trip the rec-gate" {
    # THE LANDMINE. Pre-fix this task counts 2 phantom Human ACs, reads as
    # partial-complete 0/2, and is refused emission for an empty Recommendation
    # it was never the author's job to write.
    _task_from_template T-9201 deindented
    run _review T-9201
    [ "$status" -eq 0 ] || {
        echo "de-indented commented examples were counted as real Human ACs" >&2
        return 1
    }
}

@test "t2948: the de-indent fixture WOULD have tripped the pre-fix counter" {
    # Falsification. Without this, leg 1 passes for a fixture that never had
    # column-0 checkboxes in it at all, and proves nothing.
    _task_from_template T-9202 deindented
    run _count_human_prefix "$SANDBOX/.tasks/active/T-9202-x.md"
    [ "$output" -gt 0 ] || {
        echo "fixture is inert: pre-fix counter saw $output phantom ACs, expected >0" >&2
        return 1
    }
}

@test "t2948: the template as shipped is unaffected (the accident still holds)" {
    _task_from_template T-9203 indented
    run _review T-9203
    [ "$status" -eq 0 ]
}

@test "t2948: real Human ACs are still counted — the gate still fires when it should" {
    # Positive control. A fix that skipped everything would satisfy legs 1-3.
    # Here a genuine unticked Human AC at column 0, outside any comment, must
    # still class the task partial-complete and refuse the empty Recommendation.
    _task_from_template T-9204 indented
    sed -i 's|^### Human$|### Human\n- [ ] [REVIEW] a genuine human criterion|' \
        "$SANDBOX/.tasks/active/T-9204-x.md"
    run _review T-9204
    [ "$status" -ne 0 ] || {
        echo "a real unticked Human AC no longer reaches the rec-gate" >&2
        return 1
    }
}

@test "t2948: a comment that ENDS mid-file does not swallow the ACs after it" {
    # The other over-reach direction: `in_comment` must clear on `-->`, or every
    # AC below the template's first comment block disappears and leg 4's failure
    # mode returns inverted.
    # Injected INTO the real Human section: the counter anchors on the first
    # `## Acceptance Criteria` and breaks at the next `## `, so appending a
    # second AC block at EOF would never be read (which is how this leg first
    # went red — the fixture was unreachable, not the fix wrong).
    _task_from_template T-9205 indented
    sed -i 's|^### Human$|### Human\n<!-- a single-line note -->\n- [ ] [REVIEW] after the comment|' \
        "$SANDBOX/.tasks/active/T-9205-x.md"
    run _review T-9205
    [ "$status" -ne 0 ] || {
        echo "an AC following a closed comment span was not counted" >&2
        return 1
    }
}

@test "t2948: the fix is present and names its direction" {
    grep -q "T-2948 (832 rail 570" "$FRAMEWORK_ROOT/lib/review.sh"
    grep -q "in_comment=false" "$FRAMEWORK_ROOT/lib/review.sh"
}
