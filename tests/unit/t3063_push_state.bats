#!/usr/bin/env bats
# T-3063: the push signal remembers.
#
# The failure this guards is not "the warning is missing". The warning was
# never missing — T-3025's unpushed counter printed `⚠ 7 commit(s) NOT pushed`
# in four consecutive sessions and was ignored in all four, because a snapshot
# reads the same at "not yet" as at "stuck". So the tests that matter here are
# the ones about *when it stays quiet*: a rail that escalates on the ordinary
# case is a rail that gets tuned out, which is precisely how the signal it
# replaces stopped working.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    . "$FW_ROOT/lib/push-state.sh"

    # A real git repo with a real remote-tracking ref: the self-heal path reads
    # `rev-list origin/<b>..HEAD`, so a fixture that fakes it would be testing
    # the fixture. `git push` to a bare repo on disk gives us the genuine ref.
    REPO="$BATS_TEST_TMPDIR/repo"
    REMOTE="$BATS_TEST_TMPDIR/remote.git"
    git init -q --bare "$REMOTE"
    git init -q -b main "$REPO"
    git -C "$REPO" config user.email t@example.com
    git -C "$REPO" config user.name test
    git -C "$REPO" remote add origin "$REMOTE"
    mkdir -p "$REPO/.context/working"
    echo one > "$REPO/f"; git -C "$REPO" add -A; git -C "$REPO" commit -qm one
    git -C "$REPO" push -q origin main
    git -C "$REPO" branch --set-upstream-to=origin/main main 2>/dev/null || true
}

# Add a commit that exists only locally, so `origin/main..HEAD` is non-empty.
add_unpushed() {
    echo "$RANDOM$1" >> "$REPO/f"
    git -C "$REPO" add -A
    git -C "$REPO" commit -qm "local $1"
}

# ------------------------------------------------------------- the quiet cases

@test "T-3063: a clean repo with no recorded failure says nothing" {
    run fw_push_state_read "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-3063: ONE failure does not escalate" {
    # Load-bearing. A single failed push is already visible in its own session's
    # output; a second voice for the ordinary case is how the previous signal
    # became background noise. The escalation is for the pattern, not the event.
    add_unpushed a
    fw_push_state_record "$REPO" failure killed S-1
    run fw_push_state_read "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-3063: a success clears a streak" {
    add_unpushed a
    fw_push_state_record "$REPO" failure killed S-1
    fw_push_state_record "$REPO" failure killed S-2
    [ -n "$(fw_push_state_read "$REPO")" ]

    fw_push_state_record "$REPO" success
    run fw_push_state_read "$REPO"
    [ -z "$output" ]
}

@test "T-3063: a manual push outside the handover self-heals the streak" {
    # The state is a cache of an observable fact and the fact wins. Without
    # this, the escalation keeps firing after the problem is gone — and an
    # alarm that outlives its cause is the next thing people learn to ignore.
    add_unpushed a
    fw_push_state_record "$REPO" failure killed S-1
    fw_push_state_record "$REPO" failure killed S-2
    [ -n "$(fw_push_state_read "$REPO")" ]

    git -C "$REPO" push -q origin main       # nothing told push-state about this

    run fw_push_state_read "$REPO"
    [ -z "$output" ]
    [ ! -f "$REPO/.context/working/.push-state.json" ]
}

@test "T-3063: a streak on another branch does not carry over" {
    add_unpushed a
    fw_push_state_record "$REPO" failure killed S-1
    fw_push_state_record "$REPO" failure killed S-2

    git -C "$REPO" checkout -q -b other
    run fw_push_state_read "$REPO"
    [ -z "$output" ]
}

# ------------------------------------------------------------- the loud cases

@test "T-3063: two consecutive failures escalate, with count and origin time" {
    add_unpushed a
    fw_push_state_record "$REPO" failure killed S-1
    fw_push_state_record "$REPO" failure killed S-2

    run fw_push_state_read "$REPO"
    [ "$status" -eq 0 ]
    [[ "$output" == stuck-push* ]]
    [[ "$output" == *"failures=2"* ]]
    [[ "$output" == *"kind=killed"* ]]
    [[ "$output" == *"branch=main"* ]]
    # The elapsed-time anchor: without it the operator cannot tell a streak
    # that started an hour ago from one that started last week.
    [[ "$output" =~ since=[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "T-3063: the streak counts every failure" {
    add_unpushed a
    for s in 1 2 3 4; do fw_push_state_record "$REPO" failure killed "S-$s"; done
    run fw_push_state_read "$REPO"
    [[ "$output" == *"failures=4"* ]]
}

@test "T-3063: since= is when the streak STARTED, not the latest failure" {
    # `since=<t>` is the only field that answers "how long has this been
    # broken", which is the entire difference between this rail and the
    # snapshot it replaces. A first_failure_ts that gets overwritten on every
    # failure always reads as "started just now" — the exact reassurance that
    # let seven commits sit for four sessions.
    #
    # The one-second sleep is load-bearing: without it both timestamps land in
    # the same second and `first == last` holds whether or not the field is
    # being overwritten, so the assertion cannot fail.
    add_unpushed a
    fw_push_state_record "$REPO" failure killed S-1
    sleep 1
    fw_push_state_record "$REPO" failure killed S-2

    state="$REPO/.context/working/.push-state.json"
    first=$(python3 -c "import json;print(json.load(open('$state'))['first_failure_ts'])")
    last=$(python3 -c "import json;print(json.load(open('$state'))['last_failure_ts'])")
    [ -n "$first" ] && [ -n "$last" ]
    [ "$first" != "$last" ]
    [[ "$first" < "$last" ]]

    run fw_push_state_read "$REPO"
    [[ "$output" == *"since=$first"* ]]
}

@test "T-3063: the unpushed count reported is the real one" {
    add_unpushed a; add_unpushed b; add_unpushed c
    fw_push_state_record "$REPO" failure killed S-1
    fw_push_state_record "$REPO" failure killed S-2
    run fw_push_state_read "$REPO"
    [[ "$output" == *"unpushed=3"* ]]
}

# ------------------------------------------------- killed vs refused, in words

@test "T-3063: a killed push and a refused push read differently" {
    killed=$(fw_push_state_advice killed)
    refused=$(fw_push_state_advice refused)
    unknown=$(fw_push_state_advice anything-else)

    [ -n "$killed" ] && [ -n "$refused" ] && [ -n "$unknown" ]
    [ "$killed" != "$refused" ]

    # The killed case must say the gate produced NO verdict — that is the whole
    # distinction, and the reason "the push failed" was uninformative for four
    # sessions. It must also point at measuring the gate, since the cost of the
    # gate is the actual variable.
    [[ "$killed" == *"KILLED"* ]]
    [[ "$killed" == *"no verdict"* || "$killed" == *"No verdict"* || "$killed" == *"NO verdict"* ]]
    [[ "$killed" == *"audit --section structure"* ]]

    # The refused case must NOT tell the operator to go measure the gate; the
    # gate already answered, and sending them to a stopwatch buries the answer.
    [[ "$refused" == *"REFUSED"* ]]
    [[ "$refused" != *"audit --section structure"* ]]
}

# ------------------------------------------------------------------ robustness

@test "T-3063: a corrupt state file starts a fresh streak instead of dying" {
    add_unpushed a
    echo 'not json {{{' > "$REPO/.context/working/.push-state.json"
    run fw_push_state_record "$REPO" failure killed S-1
    [ "$status" -eq 0 ]
    run fw_push_state_read "$REPO"
    [ "$status" -eq 0 ]
}

@test "T-3063: a repo with no origin ref is survivable and silent" {
    bare="$BATS_TEST_TMPDIR/noremote"
    git init -q -b main "$bare"
    git -C "$bare" config user.email t@example.com
    git -C "$bare" config user.name test
    mkdir -p "$bare/.context/working"
    echo x > "$bare/f"; git -C "$bare" add -A; git -C "$bare" commit -qm x
    fw_push_state_record "$bare" failure killed S-1
    fw_push_state_record "$bare" failure killed S-2
    run fw_push_state_read "$bare"
    [ "$status" -eq 0 ]
    # No origin ref means unpushed is unknowable (-1), not zero — reporting a
    # streak is right here, silently swallowing it is not.
    [[ "$output" == *"unpushed=-1"* ]]
}

# ------------------------------------------------------------- consumer wiring

@test "T-3063: handover records the outcome and escalates in the unpushed line" {
    h="$FW_ROOT/agents/handover/handover.sh"
    grep -q 'fw_push_state_record "$PROJECT_ROOT" failure' "$h"
    grep -q 'fw_push_state_record "$PROJECT_ROOT" success' "$h"
    grep -q 'fw_push_state_read "$PROJECT_ROOT"' "$h"
    grep -q 'THE PUSH IS STUCK' "$h"
    # The timeout branch must classify as killed, not fold into the generic one.
    grep -q '_push_kind="killed"' "$h"
    grep -q '_push_kind="refused"' "$h"
}

@test "T-3063: doctor surfaces a stuck push" {
    grep -q 'fw_push_state_read "$PROJECT_ROOT"' "$FW_ROOT/bin/fw"
    grep -q 'Push STUCK' "$FW_ROOT/bin/fw"
}
