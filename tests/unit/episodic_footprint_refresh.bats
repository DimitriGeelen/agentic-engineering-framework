#!/usr/bin/env bats
#
# T-3130 — the episodic's git footprint is mined before the commit it describes.
#
# WHY THE NAIVE TEST DOES NOT WORK (AC2, and the whole point of this file)
# -----------------------------------------------------------------------
# The obvious control is: complete a task, commit, assert `commits > 0`.
#
# That control PASSES AGAINST UNFIXED CODE, and it passes for a reason that has
# nothing to do with the fix. By the time it asserts, the commit exists — so if
# anything re-reads git at any point (a later regeneration, a second update, a
# test helper that regenerates), the value is right for the wrong reason. It is
# measuring from a vantage point where both the broken and the fixed system look
# identical, which makes it indistinguishable from a test that asserts nothing.
#
# The value has to be captured AT GENERATION — before the commit lands — and
# compared with the value after. The defect is the DELTA between two vantage
# points, so a control that only ever occupies one of them cannot see it. That
# is why every test below snapshots first and asserts on the pair.
#
# FIXTURES ONLY (AC6, L-599). Every repo here is built by the test in
# $BATS_TEST_TMPDIR. Nothing reads the live corpus, the 577 backfill population,
# or any live task id — those all move, and a control pinned to them reports on
# the corpus rather than on the code. Synthetic ids are T-9001..T-9099.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$FRAMEWORK_ROOT/lib/episodic_footprint.py"
    REPO="$BATS_TEST_TMPDIR/repo"

    mkdir -p "$REPO/.context/episodic"
    git -C "$REPO" init -q 2>/dev/null || { mkdir -p "$REPO"; git -C "$REPO" init -q; }
    git -C "$REPO" config user.email "t3130@test.invalid"
    git -C "$REPO" config user.name "T-3130 fixture"
    git -C "$REPO" config commit.gpgsign false
}

# Write an episodic with the same metrics-block shape episodic.sh emits.
# $1 task id, $2 git_mining value, $3 commits, $4 files, $5 added, $6 removed
_write_episodic() {
    cat > "$REPO/.context/episodic/$1.yaml" <<EOF
task_id: $1
name: "fixture"

tags: [fixture]

# Passive metrics (derived automatically — do not edit)
metrics:
  # git_mining: ok = the four counters below are measurements.
  git_mining: $2
  wall_clock_minutes: 5
  commits: $3
  files_changed: $4
  lines_added: $5
  lines_removed: $6

outcome: success
EOF
}

_field() {  # $1 task id, $2 field
    grep -E "^\s+$2:" "$REPO/.context/episodic/$1.yaml" | head -1 | sed 's/.*: *//'
}

_commit_work() {  # $1 task id, $2 filename
    echo "content-$2" > "$REPO/$2"
    git -C "$REPO" add "$2"
    git -C "$REPO" commit -q -m "$1: fixture work in $2"
}

# ── The core case: one task, one commit, all of it at completion ─────────────

@test "T-3130: single-commit task records 0 at generation and is corrected after" {
    _write_episodic T-9001 ok 0 0 0 0

    # Vantage point 1 — AT GENERATION. No commit exists yet. This is the state
    # update-task.sh actually leaves behind, and it is why the naive test is
    # insufficient: at this instant `commits: 0` is a truthful measurement.
    at_generation="$(_field T-9001 commits)"
    [ "$at_generation" = "0" ]

    _commit_work T-9001 a.txt

    # Vantage point 2 — AFTER THE COMMIT. The refresh runs here, as post-commit
    # does.
    run python3 "$LIB" T-9001 --project-root "$REPO" --commit deadbeef
    [ "$status" -eq 0 ]

    after="$(_field T-9001 commits)"
    [ "$after" = "1" ]

    # The assertion is on the PAIR. A system that reported 1 at both vantage
    # points would not have the defect; one that reports 0 at both still has it.
    [ "$at_generation" != "$after" ]
}

@test "T-3130: the other three counters are corrected too, not just commits" {
    _write_episodic T-9002 ok 0 0 0 0
    _commit_work T-9002 b.txt

    run python3 "$LIB" T-9002 --project-root "$REPO" --commit cafe
    [ "$status" -eq 0 ]

    [ "$(_field T-9002 files_changed)" = "1" ]
    [ "$(_field T-9002 lines_added)" = "1" ]
    # A file that is only added has no removals; 0 here is a real measurement.
    [ "$(_field T-9002 lines_removed)" = "0" ]
}

@test "T-3130: a multi-commit task's count grows to include the completion commit" {
    _write_episodic T-9003 ok 2 2 2 0
    _commit_work T-9003 c1.txt
    _commit_work T-9003 c2.txt
    _commit_work T-9003 c3.txt

    run python3 "$LIB" T-9003 --project-root "$REPO" --commit abc123
    [ "$status" -eq 0 ]
    [ "$(_field T-9003 commits)" = "3" ]
}

# ── AC5: the T-3129 boundary. `skipped` is NOT this task's zero. ─────────────

@test "T-3130/AC5: git_mining=skipped is left alone, not filled in" {
    # T-3129's state: git was unreachable at generation, so the counters are
    # null — an ABSENT measurement. Post-commit always runs inside git and so
    # could fill these; it must not, because that would erase the evidence that
    # generation-time mining failed.
    _write_episodic T-9004 skipped null null null null
    _commit_work T-9004 d.txt

    run python3 "$LIB" T-9004 --project-root "$REPO" --commit feed
    [ "$status" -eq 0 ]

    [ "$(_field T-9004 commits)" = "null" ]
    [ "$(_field T-9004 git_mining)" = "skipped" ]
    echo "$output" | grep -q "left alone"
}

@test "T-3130/AC5: a measured zero and an absent measurement are distinguishable" {
    # The two states this task and T-3129 produce must not collapse into each
    # other. Same repo, same commit history, different treatment.
    _write_episodic T-9005 ok 0 0 0 0
    _write_episodic T-9006 skipped null null null null
    _commit_work T-9005 e.txt
    _commit_work T-9006 f.txt

    python3 "$LIB" T-9005 --project-root "$REPO" --commit x >/dev/null
    python3 "$LIB" T-9006 --project-root "$REPO" --commit x >/dev/null

    [ "$(_field T-9005 commits)" = "1" ]      # measured too early -> corrected
    [ "$(_field T-9006 commits)" = "null" ]   # never measured -> still absent
}

# ── AC4: provenance is in the artefact, beside the values it explains ────────

@test "T-3130/AC4: a refresh records which commit it hung off" {
    _write_episodic T-9007 ok 0 0 0 0
    _commit_work T-9007 g.txt

    python3 "$LIB" T-9007 --project-root "$REPO" --commit 1a2b3c >/dev/null

    grep -q "footprint_refreshed_by_commit: 1a2b3c" "$REPO/.context/episodic/T-9007.yaml"
    grep -q "footprint_refreshed_at:" "$REPO/.context/episodic/T-9007.yaml"
}

@test "T-3130: repeated refreshes do not accumulate provenance lines" {
    _write_episodic T-9008 ok 0 0 0 0
    _commit_work T-9008 h1.txt
    python3 "$LIB" T-9008 --project-root "$REPO" --commit first >/dev/null
    _commit_work T-9008 h2.txt
    python3 "$LIB" T-9008 --project-root "$REPO" --commit second >/dev/null

    n=$(grep -c "footprint_refreshed_by_commit:" "$REPO/.context/episodic/T-9008.yaml")
    [ "$n" -eq 1 ]
    grep -q "footprint_refreshed_by_commit: second" "$REPO/.context/episodic/T-9008.yaml"
    [ "$(_field T-9008 commits)" = "2" ]
}

# ── Regression guards. These pass on BOTH sides by construction and are NOT ──
# ── counted as mutation coverage (AC3). Their job is to protect the fix.  ────

@test "T-3130 [regression guard]: a missing episodic is a no-op, not a failure" {
    # post-commit runs on every commit, most of which name no completed task.
    run python3 "$LIB" T-9099 --project-root "$REPO" --commit x
    [ "$status" -eq 0 ]
}

@test "T-3130 [regression guard]: an already-correct footprint is left byte-identical" {
    _write_episodic T-9010 ok 0 0 0 0
    _commit_work T-9010 i.txt
    python3 "$LIB" T-9010 --project-root "$REPO" --commit one >/dev/null
    before="$(md5sum "$REPO/.context/episodic/T-9010.yaml" | cut -d' ' -f1)"

    run python3 "$LIB" T-9010 --project-root "$REPO" --commit two
    [ "$status" -eq 0 ]
    after="$(md5sum "$REPO/.context/episodic/T-9010.yaml" | cut -d' ' -f1)"
    [ "$before" = "$after" ]
}

@test "T-3130 [regression guard]: non-metrics content survives a refresh" {
    _write_episodic T-9011 ok 0 0 0 0
    _commit_work T-9011 j.txt
    python3 "$LIB" T-9011 --project-root "$REPO" --commit x >/dev/null

    grep -q '^task_id: T-9011' "$REPO/.context/episodic/T-9011.yaml"
    grep -q '^outcome: success' "$REPO/.context/episodic/T-9011.yaml"
    grep -q '^  wall_clock_minutes: 5' "$REPO/.context/episodic/T-9011.yaml"
}

@test "T-3130 [regression guard]: the hook wiring is present and parses" {
    grep -q 'episodic_footprint.py' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    bash -n "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    # PL-078: the marker must move or consumers never redeploy the hook.
    grep -q '# VERSION=1.7' "$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
}
