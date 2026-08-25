#!/usr/bin/env bats
#
# T-3134 — the P-011 verification extractor matched `## Verification` as a
# PREFIX, and sed ranges repeat.
#
# Two consequences, and the second is the one that actually bit:
#
#   INJECTION — a later section whose heading merely begins with those words
#   ("## Verification Provenance") opened a second range, and its prose was
#   handed to the loop in update-task.sh that evals verification commands.
#
#   SUPPRESSION — worse, and measured. The shipped task template carries the
#   line `## Verification` instead of a Human AC here...` at column 0 inside
#   the Human-AC HTML comment, and that comment sits BEFORE the real heading.
#   sed opens its range on the comment line and closes it on the next `^## `
#   line — which IS the real `## Verification` heading. The heading is consumed
#   as a terminator, so it can never open a range of its own, and the actual
#   commands are never extracted. `extract_verification_block` returns empty,
#   P-011 hits `[ -z "$verify_cmds" ] && return 0`, and the gate passes having
#   run nothing.
#
# Measured over the 3124-file corpus at fix time: 2 completed tasks (T-2885 with
# 6 commands, T-2887 with 5) had their verification gate run ZERO commands and
# reported no problem. That is the false-green shape this repo keeps finding —
# a check that cannot see its subject is indistinguishable from one that looked
# and was satisfied.
#
# WHY EVERY NEGATIVE ASSERTION BELOW IS `[[ "$output" != *x* ]]` AND NOT `! ... | grep -q`
# -----------------------------------------------------------------------------
# Bash exempts from errexit "any command whose return value is being inverted
# with !". So a non-final `! echo "$output" | grep -q 'leaked'` inside a bats
# test CANNOT fail it — the test only reports the status of its last command.
# This file's first draft used that form and test 3 was green against the
# unfixed extractor while the prose it asserted absent was demonstrably present
# in the output. That is this repo's own false-green shape, reproduced inside
# the control written to catch it: an assertion that cannot see its subject
# reads identically to one that looked and was satisfied.
#
# `[[ ! ... ]]` / `[[ x != y ]]` puts the negation INSIDE a single command, so
# errexit applies and the assertion is real. Measured: the switch moved this
# file from 5/10 to 6/10 discriminating, and the 4 that remain green are
# exactly the 4 labelled regression guards.
#
# FIXTURES ONLY (L-599). Every task file below is written by the test. The two
# live task ids above appear in this comment as the origin record and in no
# assertion — they are completed and will not change, but pinning a control to
# them would make it a report about the corpus rather than about the code.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/verification-port.sh"
    T="$BATS_TEST_TMPDIR/task.md"
}

# The exact shape the shipped template produces: a Human-AC comment containing
# a column-0 line beginning "## Verification", positioned before the real one.
_template_shaped_task() {
    cat > "$T" <<'EOF'
# T-9999: fixture

## Acceptance Criteria

### Agent
- [x] AC1 — something

### Human
<!-- Criteria requiring human verification.
     If your Expected clause is grep-able, that AC should be an Agent AC with
     the reviewer command in
## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste.
-->

## Verification

echo REAL_COMMAND_ONE
echo REAL_COMMAND_TWO

## Decisions

nothing
EOF
}

@test "T-3134/AC3: the template's own comment no longer suppresses the real block" {
    _template_shaped_task
    run extract_verification_block "$T"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'echo REAL_COMMAND_ONE'
    echo "$output" | grep -q 'echo REAL_COMMAND_TWO'
}

@test "T-3134/AC3: and it extracts EXACTLY the real commands, nothing else" {
    # Asserting a COUNT alone is not enough and was a false pass while this file
    # was being written: the broken extractor also returned exactly two lines
    # here — two lines of the comment's prose. The assertion has to name the
    # content, or a wrong answer of the right length satisfies it.
    _template_shaped_task
    got=$(extract_verification_block "$T")
    [ "$got" = "echo REAL_COMMAND_ONE
echo REAL_COMMAND_TWO" ]
}

@test "T-3134/AC3: no line of the Human-AC comment reaches the executed block" {
    _template_shaped_task
    # These are the exact lines the broken extractor emitted for this fixture.
    # Picking prose that merely *looks* like it would leak is how the first
    # draft of this test passed against the defect.
    run extract_verification_block "$T"
    # Non-emptiness FIRST. Against the defect this block is empty, and "no prose
    # leaked" is then vacuously true — the test would pass while the gate ran
    # nothing at all. An absence assertion needs a presence assertion beside it
    # or it cannot tell "clean" from "did not look".
    [ -n "$output" ]
    [[ "$output" != *'genuinely needs human taste'* ]]
    [[ "$output" != *'-->'* ]]
    [[ "$output" != *'Human AC here'* ]]
}

@test "T-3134/AC1: a later prefix-matching heading does not inject its prose" {
    # TWO details are load-bearing and were both wrong in the first draft:
    #   - an intervening section is required. Without one, the prefix heading is
    #     consumed as the FIRST range's terminator and never opens a range of
    #     its own, so nothing leaks and the test passes against the defect.
    #   - a trailing line after the payload is required, because `sed '$d'`
    #     drops the last line of the stream. Putting `rm -rf` last meant the
    #     defect deleted the evidence of itself.
    cat > "$T" <<'EOF'
## Verification

echo ONLY_THIS

## RCA

something in between

## Verification Provenance

This paragraph documents a mutation check and must never be executed.
rm -rf /definitely-not
trailing line so the payload is not the last line
EOF
    run extract_verification_block "$T"
    echo "$output" | grep -q 'echo ONLY_THIS'
    [[ "$output" != *'rm -rf'* ]]
    [[ "$output" != *'paragraph'* ]]
    [ "$(extract_verification_block "$T" | wc -l)" -eq 1 ]
}

@test "T-3134 [regression guard]: anchored match still accepts trailing whitespace" {
    # Passes on both sides by construction — a PREFIX match accepted this too.
    # Its job is to stop the anchor being written too tightly, not to detect the
    # defect, so it is not counted as mutation coverage.
    printf '## Verification   \n\necho TRAILING_WS_OK\n\n## Next\n' > "$T"
    run extract_verification_block "$T"
    echo "$output" | grep -q 'echo TRAILING_WS_OK'
}

@test "T-3134/AC2: a second exact heading contributes nothing" {
    cat > "$T" <<'EOF'
## Verification

echo FIRST_BLOCK

## Something

in between

## Verification

echo SECOND_BLOCK_MUST_NOT_RUN
trailing line so the payload is not the last line
EOF
    run extract_verification_block "$T"
    echo "$output" | grep -q 'echo FIRST_BLOCK'
    [[ "$output" != *'SECOND_BLOCK_MUST_NOT_RUN'* ]]
}

@test "T-3134/AC6: both extractors agree on the same inputs" {
    # lib/reviewer/static_scan.py:extract_section has always anchored correctly.
    # Nothing ever compared them, which is how one stayed wrong. This is that
    # comparison, so the next fix to either cannot silently leave the other
    # behind.
    _template_shaped_task
    shell_out=$(extract_verification_block "$T")
    py_out=$(cd "$FRAMEWORK_ROOT" && python3 -c "
import sys, re
sys.path.insert(0, '.')
from lib.reviewer.static_scan import extract_section
sec = extract_section(open('$T').read(), 'Verification') or ''
for ln in sec.splitlines():
    if ln.strip() and not re.match(r'^\s*(#|\`\`\`)', ln):
        print(ln)
")
    [ "$shell_out" = "$py_out" ]
}

# ── Regression guards: pass on both sides by construction (not coverage) ─────

@test "T-3134 [regression guard]: a task with no Verification section yields nothing" {
    printf '# T-1\n\n## Context\n\nnothing here\n' > "$T"
    run extract_verification_block "$T"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-3134 [regression guard]: comments and fences are still stripped" {
    printf '## Verification\n\n# a comment\n```\necho FENCED\n```\n\n## Next\n' > "$T"
    run extract_verification_block "$T"
    [[ "$output" != *'# a comment'* ]]
    [[ "$output" != *'```'* ]]
    echo "$output" | grep -q 'echo FENCED'
}

@test "T-3134/AC7 [regression guard]: T-2991's parseable-check still refuses a bad block" {
    # This fix removes the CAUSE. It must not remove the last line of defence
    # that caught it twice.
    printf '## Verification\n\npython3 -c "import yaml\nprint(1)"\n\n## Next\n' > "$T"
    blk=$(extract_verification_block "$T")
    run check_verification_parseable "$blk"
    [ "$status" -ne 0 ]
}
