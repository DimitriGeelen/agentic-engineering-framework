#!/usr/bin/env bats
# ── What the live run established (2026-08-11, S-2026-0811) ──────────────────
# On a fresh `fw init` greenfield project, doing only the work the seed asks:
#   1. AC preflight            PASS  (T-2862's fix works — no self-gating AC)
#   2. review-marker gate      PASS
#   3. Recommendation gate     PASS
#   4. P-011 verification      FAILED until the seed line was fixed this session
#   5. `**Decision**: GO`      RECORDED
#   6. decide exit code        1, from the Watchtower emit AFTER the record
#
# Two defects found by running it that a scanner could never see — both filed
# separately:
#   A. The P-011 extractor strips HTML comments from the task body before
#      running verification lines, which eats `<!--`/`-->` LITERALS out of a
#      command. The seed's own Recommendation check became `sed '//d'` — empty
#      regex, "no previous regular expression", exit 1. Fixed in the SEED this
#      session by dropping the sed pre-pass (the `^\*\*` anchor already does the
#      work, since the template's line is indented inside the comment). The
#      EXTRACTOR is still broken for any other command containing those
#      delimiters.
#   B. `fw task review` exited non-zero and wrote no `.reviewed-T-XXX` marker
#      when no Watchtower was reachable, and `fw inception decide` refused
#      without that marker on ALL THREE decision values — including DEFER. On a
#      genuinely fresh machine, where nothing instructs the user to run
#      `fw serve` (T-001 mentions it only as "what you can do meanwhile"), the
#      first inception could not be completed by any path. FIXED by T-2922 —
#      `emit_review` (lib/review.sh) no longer aborts under `set -e` when
#      `_watchtower_url` fails loud; see leg 6 below for the pinned behaviour.
#
# Also observed: decide returns 1 having already written the decision. An agent
# or script reading that exit code concludes failure and may retry a completed
# decision. Worth its own task.

setup_file() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    PRISTINE="$(mktemp -d -t t2862-pristine-XXXXXX)"
    export PRISTINE
    mkdir -p "$PRISTINE/home" "$PRISTINE/proj"
    # Seed once; each test works on a copy. `fw init` is the slow step.
    env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$PRISTINE/home" \
        "$FRAMEWORK_ROOT/bin/fw" init "$PRISTINE/proj" >/dev/null 2>&1
}

teardown_file() { rm -rf "$PRISTINE"; }

setup() {
    WORK="$(mktemp -d -t t2862-XXXXXX)"
    cp -a "$PRISTINE/proj" "$WORK/proj"
    cp -a "$PRISTINE/home" "$WORK/home"
    PROJ="$WORK/proj"
    TASK="$(ls "$PROJ/.tasks/active/T-002-"*.md)"
    FW="$FRAMEWORK_ROOT/bin/fw"
}

teardown() { rm -rf "$WORK"; }

# Run a real fw command inside the seeded project, with no inherited framework
# state. `env -i` is load-bearing (L-009/L-020, T-1633): an inherited
# PROJECT_ROOT/FRAMEWORK_ROOT makes `fw` silently operate on the WRONG project,
# and what a user with no framework state sees on their first run is the whole
# subject here.
in_proj() {
    ( cd "$PROJ" && env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$WORK/home" \
        WATCHTOWER_URL="${WT_URL-http://127.0.0.1:9}" "$FW" "$@" 2>&1 )
}

# Do the work the seed actually asks of the agent: artifact, recommendation,
# Agent ACs ticked. Deliberately does NOT touch the `### Human` AC — that one is
# the operator's, and the flow must complete with it still unchecked.
do_the_agent_work() {
    mkdir -p "$PROJ/docs/reports"
    echo "# T-002 research" > "$PROJ/docs/reports/T-002-goals.md"
    python3 - "$TASK" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
ag = re.search(r'(### Agent\n)(.*?)(\n<!--|\n## )', s, re.S)
blk = ag.group(2).replace('- [ ]', '- [x]')
s = s[:ag.start(2)] + blk + s[ag.end(2):]
s = re.sub(r'## Recommendation\n.*?(?=\n## )',
           '## Recommendation\n\n**Recommendation:** GO\n\n'
           '**Rationale:** Scope is clear and bounded.\n\n'
           '**Evidence:**\n- docs/reports/T-002-goals.md\n', s, flags=re.S)
open(p, 'w').write(s)
PY
}

# ── The acceptance criterion ──────────────────────────────────────────────────

@test "t2862: a fresh greenfield project completes its first inception — no bypass, no hedge" {
    do_the_agent_work
    in_proj task review T-002 >/dev/null
    output=$(in_proj inception decide T-002 go --rationale "scope is clear")

    # Assert the OUTCOME, not the exit code. decide currently exits non-zero on
    # a project with no reachable Watchtower even when the decision was written
    # (the emit at the tail fails after the record) — filed separately. The
    # invariant this AC is about is that the decision is REACHED: no --force, no
    # --skip-acceptance-criteria, no --skip-verification, and GO rather than a
    # DEFER hedge past the preflight.
    grep -qE '^\*\*Decision\*\*: *GO' "$TASK"

    # And prove it was not reached by tripping any gate along the way.
    ! echo "$output" | grep -q 'agent AC unchecked'
    ! echo "$output" | grep -q 'Cannot complete'
    ! echo "$output" | grep -q 'Recommendation section required'
}

@test "t2862: the human AC is left for the human — task goes partial-complete" {
    do_the_agent_work
    in_proj task review T-002 >/dev/null
    in_proj inception decide T-002 go --rationale "scope is clear" >/dev/null || true

    [ -f "$TASK" ]
    grep -qE '^owner: *human' "$TASK"
    sed -n '/^### Human/,/^## /p' "$TASK" | grep -q '^- \[ \]'
}

# ── Anti-vacuity: this suite must be able to FAIL ─────────────────────────────
# Without these, a seed that silently stopped shipping T-002 at all would leave
# every leg above green. Both reconstruct a real defect and require it to bite.

@test "t2862: anti-vacuity — reintroducing the self-referential AC re-blocks decide" {
    do_the_agent_work
    python3 - "$TASK" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("### Agent\n",
              "### Agent\n- [ ] Go/no-go decision recorded: `fw inception decide T-002 go`\n", 1)
open(p, 'w').write(s)
PY
    in_proj task review T-002 >/dev/null
    # `|| true` is load-bearing: these legs REQUIRE decide to block, and under
    # bats' set -e a non-zero command substitution kills the test before the
    # assertion runs — the leg would go red for asserting nothing.
    output=$(in_proj inception decide T-002 go --rationale "scope is clear") || true
    echo "$output" | grep -q 'agent AC unchecked'
    ! grep -qE '^\*\*Decision\*\*: *GO' "$TASK"
}

@test "t2862: anti-vacuity — the pre-fix verification line fails the gate it shipped in" {
    do_the_agent_work
    python3 - "$TASK" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace(
    "grep -qE '^\\*\\*Recommendation:\\*\\*[[:space:]]*(GO|NO-GO|DEFER)' .tasks/active/T-002-*.md",
    "sed '/<!--/,/-->/d' .tasks/active/T-002-*.md | grep -qE '^\\*\\*Recommendation:\\*\\*[[:space:]]*(GO|NO-GO|DEFER)'")
open(p, 'w').write(s)
PY
    grep -q "sed '/<!--/,/-->/d'" "$TASK"   # the swap actually landed
    in_proj task review T-002 >/dev/null
    # `|| true` is load-bearing: these legs REQUIRE decide to block, and under
    # bats' set -e a non-zero command substitution kills the test before the
    # assertion runs — the leg would go red for asserting nothing.
    output=$(in_proj inception decide T-002 go --rationale "scope is clear") || true
    echo "$output" | grep -q 'verification(s) failed'
}

@test "t2862: the shipped verification block passes on a properly-done inception" {
    # Positive half of the leg above: the CURRENT seed line must succeed where
    # the old one failed. Together they pin the fix in both directions.
    do_the_agent_work
    in_proj task review T-002 >/dev/null
    output=$(in_proj inception decide T-002 go --rationale "scope is clear")
    ! echo "$output" | grep -q 'verification(s) failed'
}

# ── T-2922: fw task review must not fail closed with no Watchtower reachable ──
#
# Every leg above passes WATCHTOWER_URL, sidestepping the question entirely
# (the fast path in _watchtower_url never probes reachability). This leg drops
# WATCHTOWER_URL and confirms the real out-of-the-box path: no Watchtower
# started, nothing set. Before T-2922, `fw task review` exited non-zero and
# never wrote `.reviewed-T-002` here (this suite's own leg 6 pinned the bug —
# see git history). Full AC coverage (all three dispositions, the
# no-daemon-prerequisite invariant, and the live-Watchtower regression leg)
# lives in tests/integration/t2922_greenfield_first_inception.bats, which
# builds its own dedicated fixture; this leg keeps the cheaper PRISTINE-reuse
# fixture here honest rather than leaving it green for the wrong reason.

@test "t2862/t2922: fw task review succeeds and writes the marker with no Watchtower reachable" {
    do_the_agent_work
    run env -u WATCHTOWER_URL -i PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$WORK/home" bash -c "cd '$PROJ' && '$FW' task review T-002"
    [ "$status" -eq 0 ]
    [ -f "$PROJ/.context/working/.reviewed-T-002" ]
    echo "$output" | grep -q 'fw serve'
}
