#!/usr/bin/env bats
# T-5241 (G-134) — HTML-comment lines in '## Open Questions' never count as
# questions, dispositions or rationales.
#
# The inception template's Open Questions comment carries an example question
# with disposition:/rationale: lines. Read raw, it counted as one filed, disposed
# question, so an inception with no real question read "ready for a
# recommendation" (24 such inceptions found by T-5228).
#
# Each fixture is built from the REAL template comment, so a template edit that
# reintroduces the shape is caught here. The Python transcription is pinned to
# the same fixtures by tests/unit/test_t5241_open_questions_comments.py.

load ../test_helper

setup() {
    P="$(mktemp -d)"
    export PROJECT_ROOT="$P"
    source "$FRAMEWORK_ROOT/lib/inception-readiness.sh"
    TEMPLATE_OQ="$(awk '/^## Open Questions/{f=1;next} /^## /{f=0} f' \
        "$FRAMEWORK_ROOT/.tasks/templates/inception.md")"
}

teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# _fixture NAME QUESTIONS-TEXT
_fixture() {
    local f="$P/$1.md"
    { printf -- '---\nid: T-9001\nname: "fixture"\nstatus: started-work\n'
      printf 'workflow_type: inception\nowner: human\nhorizon: now\n---\n\n'
      printf '# T-9001: fixture\n\n## Problem Statement\n\nx\n\n'
      printf '## Open Questions\n\n%s\n\n' "$TEMPLATE_OQ"
      printf '%s\n\n' "$2"
      printf '## Recommendation\n\n**Recommendation:** EXPLORING\n\n**Rationale:** still exploring\n'
    } > "$f"
    echo "$f"
}

@test "template sanity: the template comment still carries an example question" {
    echo "$TEMPLATE_OQ" | grep -qE '^[[:space:]]*-[[:space:]]*\*\*IW-1'
    echo "$TEMPLATE_OQ" | grep -q 'disposition:'
}

@test "template-only Open Questions: no questions filed yet, not ready" {
    f=$(_fixture only "")
    run inception_handoff_blockers "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no Open Questions filed yet"* ]]
    [[ "$output" != *"ready-for-recommendation"* ]]
}

@test "template-only: underdisposed scan reports nothing and counts nothing" {
    f=$(_fixture only "")
    run inception_underdisposed_questions "$f"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "one real disposed question beside the example: ready for a recommendation" {
    f=$(_fixture disposed "- **IW-1: real question**
  disposition: answered
  rationale: evidence in docs/reports/x.md")
    run inception_handoff_blockers "$f"
    [[ "$output" == *"ready-for-recommendation"* ]]
}

@test "one real undisposed question beside the example: 1 open, not 2" {
    f=$(_fixture open "- **IW-1: real question**")
    run inception_handoff_blockers "$f"
    [[ "$output" == *"1 question(s) open"* ]]
    [ "$(printf '%s\n' "$output" | grep -c '^undisposed-question')" -eq 1 ]
}

@test "inline comment on one line is dropped; prose mentioning <!-- is kept" {
    f=$(_fixture inline "<!-- - **IW-9: hidden** disposition: answered rationale: x -->
- **IW-1: talks about the <!-- marker in prose**")
    run inception_handoff_blockers "$f"
    [[ "$output" == *"1 question(s) open"* ]]
    [[ "$output" == *"IW-1 disposition=false"* ]]
    [[ "$output" != *"IW-9"* ]]
}

@test "control: a disposition written only inside a comment does not dispose a real question" {
    f=$(_fixture ctl "- **IW-1: real question**
<!--
  disposition: answered
  rationale: hidden
-->")
    run inception_handoff_blockers "$f"
    [[ "$output" == *"IW-1 disposition=false rationale=false"* ]]
}
