#!/usr/bin/env bats
# T-3360: branch-hygiene must measure the AHEAD direction, not only BEHIND.
#
# Every pre-existing rail in lib/branch-hygiene.sh asks "how far has this branch
# fallen behind, and can it still be reconciled?". None asked "is there work here
# that was never pushed?" — and that is the direction that strands.
#
# Measured origin: origin/bleeding-edge last received a commit 2026-09-07 23:06;
# the pre-push audit gate then refused every push for ~3 days while the branch
# climbed to 32 ahead. Every handover in that window ran, committed, and reported
# success. Nothing watched the gap (OBS-394/395).
#
# The trap this suite exists to avoid is the same one T-3187 names: on a healthy
# branch the rail is SILENT, and silence is exactly what a rail that never fires
# also produces. So every quiet assertion below is paired with a firing one over
# the same fixture. That pairing is the control leg, not decoration.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    REMOTE="$TEST_TEMP_DIR/remote.git"

    git init -q --bare -b master "$REMOTE"
    git init -q -b master "$REPO"
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"
    git -C "$REPO" add f
    git -C "$REPO" commit -qm base
    git -C "$REPO" remote add origin "$REMOTE"

    # A dev branch that exists on BOTH sides — the normal, healthy starting state.
    git -C "$REPO" checkout -q -b bleeding-edge
    git -C "$REPO" push -q origin bleeding-edge

    LIB="$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Add N unpushed commits, optionally back-dating the FIRST one by <days>.
# COUNTER is monotonic across calls: reusing a filename produces an empty commit
# attempt ("nothing to commit") and the helper silently adds nothing.
COUNTER=0
_commit_n() {
    local n="$1" backdate_days="${2:-0}" i
    for i in $(seq 1 "$n"); do
        COUNTER=$(( COUNTER + 1 ))
        echo "c$COUNTER" > "$REPO/file-$COUNTER"
        git -C "$REPO" add "file-$COUNTER"
        if [ "$i" -eq 1 ] && [ "$backdate_days" -gt 0 ]; then
            local when
            when="$(date -u -d "$backdate_days days ago" +%FT%TZ)"
            GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
                git -C "$REPO" commit -qm "c$COUNTER"
        else
            git -C "$REPO" commit -qm "c$COUNTER"
        fi
    done
}

_hygiene() {
    run env FW_DEV_BRANCH=bleeding-edge FW_BRANCH_AHEAD_WARN="${1:-20}" \
        bash -c "source '$LIB'; fw_branch_hygiene '$REPO'"
}

# ── the rail fires ───────────────────────────────────────────────────────────

@test "T-3360: a dev branch past the ahead threshold raises ahead-unpushed" {
    _commit_n 5
    _hygiene 3
    echo "$output" | grep -q '^ahead-unpushed bleeding-edge ahead=5 '
}

@test "T-3360: the finding carries the AGE of the oldest unpushed commit" {
    # The count alone is a number; the age is the part worth acting on.
    _commit_n 5 4
    _hygiene 3
    echo "$output" | grep -qE '^ahead-unpushed bleeding-edge ahead=5 oldest_days=[34] '
}

@test "T-3360: the finding names its threshold, as the sibling rails do" {
    _commit_n 5
    _hygiene 3
    echo "$output" | grep -q 'ahead-unpushed .*(threshold 3)'
}

# ── control legs: it must be capable of silence, for the right reasons ───────

@test "T-3360 CONTROL: a branch AT the threshold is silent, one over fires" {
    # Both halves over one fixture — this is what separates 'fires correctly'
    # from 'always fires'.
    _commit_n 3
    _hygiene 3
    run bash -c "echo '$output' | grep -c ahead-unpushed || true"
    [ "$output" = "0" ]

    _commit_n 1
    _hygiene 3
    echo "$output" | grep -q '^ahead-unpushed bleeding-edge ahead=4 '
}

@test "T-3360 CONTROL: a fully-pushed branch is silent" {
    _hygiene 0
    run bash -c "echo '$output' | grep -c ahead-unpushed || true"
    [ "$output" = "0" ]
}

@test "T-3360 CONTROL: no remote-tracking counterpart is silent, not a finding" {
    # A local-only repo has nothing to be ahead OF. Firing here would make the
    # rail noise on every fresh project, which is how rails get muted.
    git -C "$REPO" push -q origin --delete bleeding-edge
    git -C "$REPO" update-ref -d refs/remotes/origin/bleeding-edge
    _commit_n 5
    _hygiene 1
    run bash -c "echo '$output' | grep -c ahead-unpushed || true"
    [ "$output" = "0" ]
}

# ── control leg: the existing behind-direction rails are undisturbed ─────────

@test "T-3360 CONTROL: the wrong-branch identity rail still fires (T-3187)" {
    # Guards against the new block breaking the one directly above it.
    git -C "$REPO" checkout -q -b some-feature
    _hygiene 999
    echo "$output" | grep -q '^wrong-branch some-feature expected=bleeding-edge'
}

@test "T-3360 CONTROL: on the correct branch the identity rail stays quiet" {
    _hygiene 999
    run bash -c "echo '$output' | grep -c wrong-branch || true"
    [ "$output" = "0" ]
}

# ── the knob is declared, not just read ─────────────────────────────────────

@test "T-3360: BRANCH_AHEAD_WARN is declared in FW_CONFIG_REGISTRY" {
    # A threshold read from the environment but absent from the registry is
    # invisible to `fw config` and to doctor's range-check.
    grep -q '"BRANCH_AHEAD_WARN|' "$FRAMEWORK_ROOT/lib/config.sh"
}

@test "T-3360: the default threshold is the one the registry declares" {
    # Pins code and registry to the same number — a drifting pair means the
    # documented default is a fiction.
    local declared
    declared=$(grep -o '"BRANCH_AHEAD_WARN|[0-9]*|' "$FRAMEWORK_ROOT/lib/config.sh" \
               | cut -d'|' -f2)
    [ -n "$declared" ]
    grep -q "FW_BRANCH_AHEAD_WARN:-$declared" "$FRAMEWORK_ROOT/lib/branch-hygiene.sh"
}

# ── the finding must survive the display cap (T-3092 class) ─────────────────

@test "T-3360: ahead-unpushed survives the doctor display cap among many findings" {
    # fw_doctor prints at most 12 findings. Before T-3092 that cap was
    # POSITIONAL, and emission order buried whole classes — 0 of 4
    # remote-unlanded lines survived on the live repo. A finding class that is
    # always truncated has not shipped.
    #
    # The guarantee is one line PER CLASS up to the cap, so the honest test is
    # at the production cap with more findings than slots — not a cap smaller
    # than the class count, which is unsatisfiable by construction (verified:
    # cap 2 with 3 classes necessarily drops one, and that is correct).
    local f="$TEST_TEMP_DIR/findings"
    : > "$f"
    for i in $(seq 1 20); do
        echo "behind-threshold br-$i behind=99 days=9 (threshold 50)" >> "$f"
    done
    echo "ahead-unpushed bleeding-edge ahead=36 oldest_days=3 (threshold 20)" >> "$f"

    run bash -c "source '$LIB'; fw_branch_hygiene_head 12 < '$f'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^ahead-unpushed bleeding-edge ahead=36 '

    # CONTROL: the cap is genuinely binding — 21 findings in, 12 out. Without
    # this, a filter that simply passed everything through would also pass above.
    run bash -c "source '$LIB'; fw_branch_hygiene_head 12 < '$f' | wc -l"
    [ "$output" -eq 12 ]
}
