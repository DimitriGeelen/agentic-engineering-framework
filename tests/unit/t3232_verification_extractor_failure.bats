#!/usr/bin/env bats
# T-3232 — extraction FAILURE must not read as "this task has no Verification section".
#
# Finding C3 of the arc-012 review. `extract_verification_block` ended in
# `|| true`, so every failure of every stage collapsed into the exact value the
# function returns for a task that legitimately has no `## Verification` block:
# empty stdout, exit 0. update-task.sh read that as "nothing to verify" and
# returned green having run ZERO commands and printed NOTHING.
#
# The defect was never that extraction can fail. It is that failure was
# INDISTINGUISHABLE from success-with-nothing-to-do. Measured before the fix:
#   clean block            -> 12 bytes, rc=0
#   same block + one 0xff  ->  0 bytes, rc=0     <-- same answer, different world
# comment_strip.py dies on UnicodeDecodeError, `2>/dev/null` ate the traceback,
# `|| true` ate the status.
#
# WHY BOTH LEVELS. The function-level tests pin the new three-way contract; the
# gate-level tests prove the CALLER acts on it. Either alone can be green while
# the pair is broken — a function that returns 2 into a caller that ignores it is
# precisely the shape of the bug being fixed.
#
# THE CONTROLS ARE LOAD-BEARING. `clean block` at both levels proves the harness
# can PASS; without it a harness stuck at "blocked" scores full marks measuring
# nothing. This is the T-3231 lesson applied at author time rather than after.
#
# NOTE ON EXIT CODES AT THE GATE LEVEL: the fixture project is a bare directory,
# not a git repo, so update-task.sh exits non-zero for its own downstream reasons
# AFTER the verification gate has passed. The overall rc is therefore NOT a valid
# discriminator here and is deliberately not asserted; the gate's own output is.
# Asserting rc would have produced a suite that is green for the wrong reason.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    # T3232_LIB_OVERRIDE lets the mutation harness point the function-level tests
    # at a sandboxed copy, so mutating a leg never edits the live gate library.
    LIB="${T3232_LIB_OVERRIDE:-$FRAMEWORK_ROOT/lib/verification-port.sh}"
    [ -f "$LIB" ] || { echo "missing $LIB" >&2; return 1; }
    source "$LIB"
    T="$(mktemp -d)"
}

# Explicit `if`, not `[ -n "$P" ] && rm -rf "$P"`. As the LAST statement of a
# function that trailing form returns 1 whenever the guard is false, and bats
# reads a non-zero teardown as a failed test — which is how the first run of this
# file reported 6 failures that had nothing to do with the subject. Sibling of
# L-628: a `&&` list in final position carries its guard's status out with it.
teardown() {
    if [ -n "${T:-}" ]; then rm -rf "$T"; fi
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# ── fixtures ──────────────────────────────────────────────────────────────────

_clean_file() {
    printf '# T-9999\n\n## Verification\n\ntrue\necho hi\n\n## RCA\n' > "$T/f.md"
    echo "$T/f.md"
}

# The 0xff byte sits INSIDE the block. Putting it after the closing heading does
# nothing: awk stops at the next `## `, so comment_strip.py never sees it. The
# first attempt at reproducing this finding made exactly that mistake and
# "disproved" a real bug.
_dirty_file() {
    { printf '# T-9999\n\n## Verification\n\ntrue\n'
      printf 'echo h\xffi\n'
      printf '\n## RCA\n'; } > "$T/f.md"
    echo "$T/f.md"
}

_absent_file() {
    printf '# T-9999\n\n## RCA\n\nnothing here\n' > "$T/f.md"
    echo "$T/f.md"
}

_comments_only_file() {
    printf '# T-9999\n\n## Verification\n\n# just a comment\n\n## RCA\n' > "$T/f.md"
    echo "$T/f.md"
}

# ── function level: the three-way contract ────────────────────────────────────

@test "control: a clean block extracts its commands and returns 0" {
    run extract_verification_block "$(_clean_file)"
    [ "$status" -eq 0 ]
    [ "$output" = "true
echo hi" ]
}

@test "a block that cannot be decoded returns 2, not 0" {
    run extract_verification_block "$(_dirty_file)"
    [ "$status" -eq 2 ]
}

@test "the failing block still emits empty stdout (consumers reading stdout are unaffected)" {
    # lib/verify_queue.py:89 shells out and uses r.stdout alone. The new exit code
    # must not change what it sees, or this fix breaks the verify-queue rail.
    run extract_verification_block "$(_dirty_file)"
    [ -z "$output" ]
}

@test "a genuinely absent Verification section returns 0 with empty output" {
    run extract_verification_block "$(_absent_file)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a block filtered entirely to comments is EMPTY, not FAILED" {
    # grep -vE exits 1 when it filters everything out. That is a normal outcome
    # and must not be classified with the python explosion, which also exits 1.
    # This test is why the fix uses PIPESTATUS and not pipefail: pipefail cannot
    # tell these two apart.
    run extract_verification_block "$(_comments_only_file)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "an unreadable file returns 2" {
    run extract_verification_block "$T/does-not-exist.md"
    [ "$status" -eq 2 ]
}

# ── gate level: the caller acts on the contract ───────────────────────────────

# Builds a fixture project whose T-9999 passes every gate ahead of P-011.
# $1 = clean | dirty | absent
_make_project() {
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
    { printf -- '---\nid: T-9999\nname: "fixture"\nstatus: started-work\n'
      printf 'workflow_type: build\nowner: agent\nhorizon: now\n'
      printf 'created: 2026-08-31T00:00:00Z\nlast_update: 2026-08-31T00:00:00Z\n---\n\n'
      printf '# T-9999: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'
      case "$1" in
          clean)  printf '## Verification\n\ntrue\necho hi\n\n' ;;
          dirty)  printf '## Verification\n\ntrue\n'; printf 'echo h\xffi\n'; printf '\n' ;;
          absent) : ;;
      esac
      printf '## Decisions\n\n'; } > "$P/.tasks/active/T-9999-fixture.md"
}

_close() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9999 --status work-completed 2>&1
}

@test "control: the gate RUNS a clean block (harness can pass)" {
    _make_project clean
    run _close
    echo "$output" | grep -q "Verification: 2/2 passed"
}

@test "the gate REFUSES a block it could not extract" {
    _make_project dirty
    run _close
    echo "$output" | grep -q "BLOCKED: the ## Verification block could not be extracted"
}

@test "a FAILED extraction is distinguishable from an ABSENT section" {
    # This is the defect stated exactly: two different worlds, one answer. Before
    # the fix, closing a task whose block cannot be decoded and closing a task
    # with no block at all produced BYTE-IDENTICAL output — the gate returned
    # early in both cases and printed nothing whatsoever.
    #
    # Note this corrects the review's wording. C3 says the gate "reports the same
    # pass"; it does not report anything. It is a SILENT skip, which is worse
    # than a printed "0/0 passed" would have been — a printed green at least
    # leaves a line in the log for someone to notice.
    #
    # The first version of this test asserted `grep -c 'Verification: .*passed'
    # -eq 0` on the dirty case, which is TRUE both before and after the fix and
    # therefore measured nothing. Mutation M4 (caller ignores the exit code)
    # caught it by reddening nothing.
    # `|| true` on each capture: bats runs test bodies under errexit, and _close
    # legitimately exits non-zero on the blocked path. Without it the test fails
    # on the ASSIGNMENT rather than on the comparison — which still reddens under
    # mutation, but for the wrong reason, and a test that reddens for the wrong
    # reason is not evidence (L-302).
    local dirty_out absent_out
    _make_project dirty;  dirty_out="$(_close)"  || true; rm -rf "$P"
    _make_project absent; absent_out="$(_close)" || true

    # Strip the fixture paths, which differ per mktemp and are not the subject.
    dirty_out="$(printf '%s' "$dirty_out" | sed 's#/tmp/[^ ]*##g')"
    absent_out="$(printf '%s' "$absent_out" | sed 's#/tmp/[^ ]*##g')"

    [ "$dirty_out" != "$absent_out" ]
}

@test "a task with no Verification section still passes through untouched" {
    # Backward compatibility: P-011 has always allowed tasks with no block.
    _make_project absent
    run _close
    [ "$(echo "$output" | grep -c 'BLOCKED: the ## Verification')" -eq 0 ]
}

@test "the bypass env allows the close and writes a Tier-2 entry" {
    _make_project dirty
    run env FW_ALLOW_UNEXTRACTABLE_VERIFICATION=1 PROJECT_ROOT="$P" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" timeout 120 bash \
        "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9999 --status work-completed
    [ "$(echo "$output" | grep -c 'BLOCKED: the ## Verification')" -eq 0 ]
    grep -q 'FW_ALLOW_UNEXTRACTABLE_VERIFICATION' "$P/.context/working/.gate-bypass-log.yaml"
}
