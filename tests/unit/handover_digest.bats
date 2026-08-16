#!/usr/bin/env bats
# T-3028 (T-3025 GO, option 3): the three state dumps digest to
# count + regenerating command + top-N; the narrative does not change.
#
# Runs the real generator against a synthetic corpus (TASKS_DIR / CONTEXT_DIR /
# HANDOVER_DIR are overridable per the lib/paths.sh test-fixture invariant), so
# these are end-to-end assertions on generated output rather than on a fixture
# someone captured once and stopped maintaining.
#
# The assertion that matters most is not "the file got smaller" — it is that
# digest-off reproduces the undigested sections unchanged. A size win that cannot
# be reversed is a migration, and this candidate was chosen over the 10x one
# precisely because it is subtraction you can undo.

setup_file() {
    export TMPROOT="$(mktemp -d)"
    export FW_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

    mkdir -p "$TMPROOT/.tasks/active" "$TMPROOT/.context/handovers" \
             "$TMPROOT/.context/working" "$TMPROOT/.context/project"

    # 12 in-flight tasks — enough that a top-5 digest must truncate.
    for i in $(seq 1 12); do
        cat > "$TMPROOT/.tasks/active/T-90$i-fixture.md" <<EOF
---
id: T-90$i
name: fixture task $i
status: started-work
workflow_type: build
horizon: now
last_update: '2026-08-0$((i % 9 + 1))T00:00:00Z'
---

## Acceptance Criteria
EOF
    done

    # 8 partial-complete tasks (work-completed, still in active/, Human ACs
    # unchecked) — this is what populates "Awaiting Your Action (Human)" and the
    # partial-complete footer, the two places that duplicate each other.
    for i in $(seq 1 8); do
        cat > "$TMPROOT/.tasks/active/T-95$i-partial.md" <<EOF
---
id: T-95$i
name: partial task $i
status: work-completed
workflow_type: build
horizon: now
last_update: '2026-08-0$((i % 9 + 1))T00:00:00Z'
---

## Acceptance Criteria

### Agent
- [x] done

### Human
- [ ] [REVIEW] confirm the thing reads right for partial task $i

## Recommendation

**Recommendation:** GO
EOF
    done

    # 12 pending observations — same reason.
    {
        echo "observations:"
        for i in $(seq 1 12); do
            echo "- id: OBS-90$i"
            echo "  text: \"observation number $i, with enough body text that the entry"
            echo "    truncation path is exercised as well as the list truncation path,"
            echo "    because both are ways a section can quietly lose content.\""
            echo "  status: pending"
            echo "  captured: 2026-08-0$((i % 9 + 1))T00:00:00Z"
        done
    } > "$TMPROOT/.context/inbox.yaml"

    _gen() {  # $1 = digest flag, $2 = session id
        env TASKS_DIR="$TMPROOT/.tasks" CONTEXT_DIR="$TMPROOT/.context" \
            HANDOVER_DIR="$TMPROOT/out-$1" FW_HANDOVER_DIGEST="$1" \
            bash "$FW_ROOT/agents/handover/handover.sh" --session "$2" \
            >/dev/null 2>&1 || true
    }
    mkdir -p "$TMPROOT/out-0" "$TMPROOT/out-1"
    _gen 0 S-DIGEST-OFF
    _gen 1 S-DIGEST-ON
    export FULL="$TMPROOT/out-0/S-DIGEST-OFF.md"
    export DIG="$TMPROOT/out-1/S-DIGEST-ON.md"
}

teardown_file() {
    rm -rf "$TMPROOT"
}

@test "both handovers were generated" {
    # Without this the size and content tests below pass vacuously on two
    # missing files, which is the failure mode of every end-to-end suite.
    [ -s "$FULL" ]
    [ -s "$DIG" ]
}

@test "the digested handover is materially smaller" {
    full=$(wc -c < "$FULL")
    dig=$(wc -c < "$DIG")
    [ "$dig" -lt "$full" ]
    # On the live corpus this is 15x; on a 12-task fixture the fixed narrative
    # dominates, so the bar here is only that the dumps actually shrank.
    [ "$dig" -lt "$((full - 1000))" ]
}

@test "narrative sections are byte-identical between digest on and off" {
    run python3 - "$FULL" "$DIG" <<'PY'
import sys, re, hashlib
DUMPS = {"## Observation Inbox", "## Work in Progress",
         "## Awaiting Your Action (Human)"}
def secs(p):
    t = open(p, encoding="utf-8").read()
    parts = re.split(r'(?m)^(## .*)$', t)
    return {parts[i].strip(): parts[i] + parts[i+1] for i in range(1, len(parts), 2)}
a, b = secs(sys.argv[1]), secs(sys.argv[2])
# Token Usage carries live session metrics that move between two runs seconds
# apart; it is not narrative the digest touches.
skip = DUMPS | {"## Token Usage"}
bad = [k for k in a if k not in skip
       and hashlib.md5(a[k].encode()).hexdigest()
        != hashlib.md5(b.get(k, "").encode()).hexdigest()]
print("DIFFERING:", bad)
print("SETS_EQUAL:", set(a) == set(b))
sys.exit(1 if bad or set(a) != set(b) else 0)
PY
    [ "$status" -eq 0 ]
}

@test "every digested dump states its own total and how to regenerate it" {
    # "Showing 5 of 12" is the honesty requirement: a reader must be able to tell
    # a truncated list from a complete one without counting the bullets.
    grep -q 'Showing 5 of 12.*`bin/fw note triage`' "$DIG"
    # Derive the expected total from the corpus rather than hard-coding 12: the
    # generator seeds its own `session-handover-maintenance` task when none
    # exists, so the fixture is 13 in-flight, not the 12 we wrote. Reading the
    # total from disk keeps the assertion an independent oracle instead of a
    # number that has to be re-guessed whenever the generator does something.
    # WIP is everything in active/ that is not partial-complete — started-work
    # and captured alike — so the total is files minus work-completed.
    all=$(ls "$TMPROOT/.tasks/active"/*.md | wc -l | tr -d ' ')
    done_=$(grep -l '^status: work-completed' "$TMPROOT/.tasks/active"/*.md | wc -l | tr -d ' ')
    want=$((all - done_))
    grep -q "Showing 5 of $want — in-flight first" "$DIG"
    grep -q 'bin/fw task list --status started-work' "$DIG"
    grep -q 'Showing 5 of 8 (GO first)' "$DIG"
    grep -q 'bin/fw review-queue' "$DIG"
}

@test "the partial-complete footer is digested too, not just the section it duplicates" {
    # The footer inside Work in Progress re-lists the same set as "Awaiting Your
    # Action". Leaving it whole would give back ~40% of what the two sections
    # cost together, which is the kind of half-fix that reads as done.
    n=$(sed -n '/partial-complete-footer/,/^## /p' "$DIG" | grep -c '^- \[GO\]')
    [ "$n" -eq 5 ]
    nfull=$(sed -n '/partial-complete-footer/,/^## /p' "$FULL" | grep -c '^- \[GO\]')
    [ "$nfull" -eq 8 ]
    grep -q 'and 3 more at horizon now' "$DIG"
}

@test "top-N is respected in Work in Progress" {
    # Count every rendered task heading, not just the T-90x fixtures: the
    # generator adds a task of its own, and pinning the fixture prefix would make
    # this pass for the wrong reason if the top-5 ever included that one.
    n=$(sed -n '/^## Work in Progress/,/^## /p' "$DIG" | grep -c '^### T-')
    [ "$n" -eq 5 ]
    # The undigested run renders every in-flight task and announces no
    # truncation. Its exact count is not pinned: the generator seeds its own
    # maintenance task on first use, so the two runs see corpora one apart —
    # asserting equality here would encode run order, not behaviour.
    nfull=$(sed -n '/^## Work in Progress/,/^## /p' "$FULL" | grep -c '^### T-')
    [ "$nfull" -ge 12 ]
    [ "$nfull" -gt "$n" ]
    ! sed -n '/^## Work in Progress/,/^## /p' "$FULL" | grep -q 'Showing .* of '
}

@test "top-N is respected in the Observation Inbox" {
    n=$(sed -n '/^## Observation Inbox/,/^## /p' "$DIG" | grep -c '^- OBS-90')
    [ "$n" -eq 5 ]
    nfull=$(sed -n '/^## Observation Inbox/,/^## /p' "$FULL" | grep -c '^- OBS-90')
    [ "$nfull" -eq 12 ]
}

@test "digest-off keeps the two constant per-task fields" {
    # Next step / Blockers were constant across 119/119 entries when measured,
    # which is why the digest drops them — but digest-off must still reproduce
    # the old output, so their absence there would be an unreversible change.
    grep -q '^- \*\*Next step:\*\* See task file' "$FULL"
    grep -q '^- \*\*Blockers:\*\* None' "$FULL"
}

@test "an empty section digests to nothing, not to a zero stub" {
    # A "0 items" heading is worse than no heading: it occupies the reader's
    # attention to tell them there is nothing there.
    empty="$TMPROOT/empty"
    mkdir -p "$empty/.tasks/active" "$empty/.context/handovers" \
             "$empty/.context/working" "$empty/.context/project" "$empty/out"
    echo "observations: []" > "$empty/.context/inbox.yaml"
    env TASKS_DIR="$empty/.tasks" CONTEXT_DIR="$empty/.context" \
        HANDOVER_DIR="$empty/out" FW_HANDOVER_DIGEST=1 \
        bash "$FW_ROOT/agents/handover/handover.sh" --session S-EMPTY \
        >/dev/null 2>&1 || true
    [ -s "$empty/out/S-EMPTY.md" ]
    ! grep -q '^## Observation Inbox' "$empty/out/S-EMPTY.md"
    ! grep -q '^## Awaiting Your Action' "$empty/out/S-EMPTY.md"
}

@test "both config keys are registered on both sides" {
    # A one-sided registration passes every local check and then fails the
    # pre-push audit's cross-source parity invariant — which reads as a hung
    # push rather than a config error (T-3024 origin, cost most of a session).
    for k in HANDOVER_DIGEST HANDOVER_DIGEST_TOP_N; do
        grep -q "\"$k|" "${BATS_TEST_DIRNAME}/../../lib/config.sh"
        grep -q "(\"$k\"," "${BATS_TEST_DIRNAME}/../../web/blueprints/config.py"
    done
}
