#!/usr/bin/env bats
# T-3546 / OBS-565 — P-011 must SAY when it runs zero commands.
#
# `run_verification_commands` returned at `[ -z "$verify_cmds" ] && return 0`
# without printing anything, so a close that verified nothing was byte-identical
# to a close that had nothing to verify.
#
# Measured on T-3545 (2026-09-28): a splice put its `## Verification` heading
# mid-sentence inside the Human-AC template comment — whose own text contains the
# literal phrase "added to ## Verification" — so no heading existed at line start.
# The task closed with `6/6 checked ✓` and no gate section at all. T-3544, eleven
# minutes earlier, printed `Verification: 18/18 passed ✓`. One absent line was the
# entire difference, and nobody notices an absence. Aggravating: `work-completed →
# started-work` is not a valid transition, so that task can never have the gate
# run on it — T-3545's nine commands had to be executed by hand.
#
# REPORTING, NOT GUARDING. An empty block is legitimate (CLAUDE.md documents
# tasks with no `## Verification` as backward-compatible) and the rc=2 leg from
# T-3232 already refuses a block that cannot be READ. Nothing here may gate,
# refuse, or move an exit code; the tests below assert that explicitly, because a
# "fix" that started blocking these tasks would be a worse bug than the silence.
#
# Harness shape is lifted from t3232_verification_extractor_failure.bats on
# purpose — same gate, same fixture project, so the two suites cannot drift into
# testing different things and calling them the same.
#
# EXIT CODES ARE NOT ASSERTED at the gate level: the fixture project is a bare
# directory, not a git repo, so update-task.sh exits non-zero downstream of P-011
# for its own reasons. The gate's OUTPUT is the discriminator. Asserting rc would
# make this suite green for the wrong reason.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" ] || \
        { echo "missing update-task.sh" >&2; return 1; }
}

# Explicit `if`, never `[ -n "$P" ] && rm -rf "$P"` — in final position that form
# carries its guard's status out and bats reads a non-zero teardown as a failure
# (L-628; the sibling suite's header records the same trap).
teardown() {
    if [ -n "${P:-}" ]; then rm -rf "$P"; fi
    return 0
}

# _make_project KIND — a fixture task that passes every gate ahead of P-011.
#   clean   : two real commands
#   absent  : no `## Verification` anywhere
#   spliced : T-3545's exact shape — the heading swallowed mid-line by the
#             Human-AC template comment, so `^## Verification` never matches
#             while the phrase "## Verification" IS present in the file
#   comments: a real heading whose body is entirely comments
_make_project() {
    P="$(mktemp -d)"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working"
    { printf -- '---\nid: T-9999\nname: "fixture"\nstatus: started-work\n'
      printf 'workflow_type: build\nowner: agent\nhorizon: now\n'
      printf 'created: 2026-08-31T00:00:00Z\nlast_update: 2026-08-31T00:00:00Z\n---\n\n'
      printf '# T-9999: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'
      case "$1" in
          clean)    printf '## Verification\n\ntrue\necho hi\n\n' ;;
          absent)   : ;;
          spliced)  printf '### Human\n<!-- the reviewer command in `## Verification\n\ntrue\necho hi\n\n' ;;
          comments) printf '## Verification\n\n# only a comment\n\n' ;;
      esac
      printf '## Decisions\n\n'; } > "$P/.tasks/active/T-9999-fixture.md"
}

_close() {
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" \
        T-9999 --status work-completed 2>&1
}

# ── the control: the normal path is untouched ────────────────────────────────

@test "CONTROL: a task with real commands still prints its pass count" {
    _make_project clean
    run _close
    echo "$output" | grep -q "Verification: 2/2 passed"
}

@test "CONTROL: the skip line does NOT fire on the verified path" {
    # Without this, every assertion below could be satisfied by a build that
    # prints the skip line unconditionally.
    _make_project clean
    run _close
    [ "$(echo "$output" | grep -c 'Verification: skipped')" -eq 0 ]
    [ "$(echo "$output" | grep -c 'yielded none')" -eq 0 ]
}

# ── the zero is now spoken ───────────────────────────────────────────────────

@test "no Verification section at all: the skip is PRINTED, not silent" {
    _make_project absent
    run _close
    echo "$output" | grep -q "Verification Gate (P-011)"
    echo "$output" | grep -q "Verification: skipped"
    echo "$output" | grep -q "Nothing was verified"
}

@test "T-3545's shape — heading spliced into the Human template comment — is reported" {
    # The exact live failure. `^## Verification` does not match, so the extractor
    # yields nothing, but the file DOES contain the phrase, which is what makes
    # the two causes distinguishable in the message.
    _make_project spliced
    run _close
    echo "$output" | grep -q "Verification Gate (P-011)"
    echo "$output" | grep -q "0 commands"
    # It must NOT claim the section is absent: the file visibly contains the
    # phrase, so "no section" would send the reader hunting for something they
    # can already see. It says the heading is not at the start of a line.
    echo "$output" | grep -q "NOT at the start of a line"
    [ "$(echo "$output" | grep -c "no '## Verification' section in this task")" -eq 0 ]
    # and it points at the check that localises it
    echo "$output" | grep -q "grep -n '## Verification'"
}

@test "a present-but-comments-only block reports the section as yielding none" {
    _make_project comments
    run _close
    echo "$output" | grep -q "present but yielded none"
}

@test "all THREE zero-causes are distinguishable from each other" {
    # The defect restated: before this change, 'no section' and 'section present
    # but unreachable' produced identical output — namely none. Distinguishing
    # them is the whole deliverable, so it is asserted directly rather than
    # inferred from the two tests above.
    local absent_out spliced_out
    _make_project absent;  absent_out="$(_close)"  || true; rm -rf "$P"
    _make_project spliced; spliced_out="$(_close)" || true
    local comments_out
    rm -rf "$P"; _make_project comments; comments_out="$(_close)" || true
    absent_out="$(printf '%s' "$absent_out" | sed 's#/tmp/[^ ]*##g')"
    spliced_out="$(printf '%s' "$spliced_out" | sed 's#/tmp/[^ ]*##g')"
    comments_out="$(printf '%s' "$comments_out" | sed 's#/tmp/[^ ]*##g')"
    [ "$absent_out" != "$spliced_out" ]
    [ "$absent_out" != "$comments_out" ]
    [ "$spliced_out" != "$comments_out" ]
}

@test "the message names the one-way door: the gate cannot be re-run after close" {
    _make_project absent
    run _close
    echo "$output" | grep -q "not a valid transition"
}

# ── it reports; it does not gate ─────────────────────────────────────────────

@test "reporting does not block: a task with no section still closes" {
    _make_project absent
    run _close
    [ "$(echo "$output" | grep -c 'BLOCKED')" -eq 0 ]
    echo "$output" | grep -q "work-completed"
}

@test "reporting does not block: T-3545's shape still closes" {
    # A fix that started REFUSING these would break every legitimately
    # section-less task in the corpus — a worse defect than the silence it
    # replaced. Pinned so nobody 'strengthens' it into a gate later.
    _make_project spliced
    run _close
    [ "$(echo "$output" | grep -c 'BLOCKED')" -eq 0 ]
    echo "$output" | grep -q "work-completed"
}

@test "the heading probe is wording-only: the rc=2 extractor contract is untouched" {
    # The T-3232 refusal must still be the ONLY thing that refuses, and it must
    # still key off the exit code rather than off a re-derived heading — see
    # update-task.sh's own comment on why re-deriving it would be wrong.
    body=$(awk '/^run_verification_commands\(\) \{/{f=1} f{print} f&&/^\}/{exit}' \
           "$FRAMEWORK_ROOT/agents/task-create/update-task.sh")
    [ -n "$body" ]
    # the probe exists
    printf '%s\n' "$body" | grep -q "grep -q '\^## Verification'"
    # ...and nothing on a line with that probe exits or returns non-zero
    [ "$(printf '%s\n' "$body" | grep "grep -q '\^## Verification'" | grep -c 'exit 1')" -eq 0 ]
    # the extractor's status is still what refuses
    printf '%s\n' "$body" | grep -q 'extract_rc.*-eq 2'
}
