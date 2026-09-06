#!/usr/bin/env bats
# T-1719 A2 — `fw task update --happiness N` records the retrieval-happiness
# signal that closes the embeddings routing loop.
#
# The signal is the outcome half of arc-002's headline mechanic: recall returns
# chunks, the operator (or agent) rates whether they were useful, and the next
# routing decision improves. Without a recorded rating the loop is open and the
# resolver has nothing to learn from.
#
# Three properties are load-bearing and each is pinned below:
#
#   1. RANGE — -5..-1 and +1..+5, with ZERO REJECTED. The scale has no neutral,
#      so a 0 is a mis-typed rating rather than an opinion. Accepting it would
#      silently pollute the signal with entries that mean nothing.
#
#   2. VALIDATE-BEFORE-MUTATE (L-286) — a rejected rating must not leave a
#      partial write behind. The append happens only after the range check, and
#      the append-only file must be byte-identical in length after a rejection.
#
#   3. APPEND-ONLY — ratings accumulate. A rating must never overwrite a prior
#      one, because the trend over time is the signal, not the latest value.
#
# The file lives at .context/working/happiness.jsonl. Schema per the T-1717
# Recommendation: {task_id, ts, source: human|agent, value, [reason]}.
#
# 2026-09-06: the mutating tests used to target T-1719 ITSELF — which deadlocked
# the moment this suite ran inside T-1719's own close gate: update-task.sh holds
# the per-task keylock (T-587) for the task being closed while P-011 runs
# Verification, and each `fw task update T-1719 --happiness` here then blocked
# forever on keylock_acquire for the same ID. A verification suite must never
# invoke `fw task update` on the task whose close is running it. The subject is
# now a throwaway fixture task created in setup() and removed in teardown() —
# update-task.sh requires the target to exist (lookup precedes the happiness
# append) and stamps its last_update, so a real-but-disposable file is the only
# shape that neither deadlocks nor dirties a committed task on every run.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    UPDATE="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    FW="$FRAMEWORK_ROOT/bin/fw"
    HAPPINESS_FILE="$FRAMEWORK_ROOT/.context/working/happiness.jsonl"
    FIX_ID="T-0000"
    FIX_FILE="$FRAMEWORK_ROOT/.tasks/active/${FIX_ID}-happiness-fixture.md"
    cat > "$FIX_FILE" <<'EOF'
---
id: T-0000
name: "happiness-signal bats fixture (transient — teardown removes)"
description: throwaway subject for t1719_happiness_signal.bats
status: captured
workflow_type: test
horizon: later
owner: agent
created: 2026-09-06T00:00:00Z
last_update: 2026-09-06T00:00:00Z
---

## Context

Exists only while a single bats test runs.
EOF
}

teardown() {
    rm -f "$FIX_FILE"
}

_line_count() {
    if [ -f "$HAPPINESS_FILE" ]; then wc -l < "$HAPPINESS_FILE" | tr -d ' '; else echo 0; fi
}

@test "t1719: --happiness and --happiness-reason are parsed, not swallowed by the catch-all" {
    # The arg loop ends in `*) Unknown option; exit 1`. A flag that is not in the
    # case list does not fail open — it hard-errors. So parsing IS the contract.
    run grep -c -- '--happiness) HAPPINESS="\$2"; shift 2 ;;' "$UPDATE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    run grep -c -- '--happiness-reason) HAPPINESS_REASON="\$2"; shift 2 ;;' "$UPDATE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "t1719: zero is rejected — the scale has no neutral" {
    before=$(_line_count)
    run "$FW" task update "$FIX_ID" --happiness 0
    [ "$status" -ne 0 ]
    [[ "$output" == *"-5..-1 or +1..+5"* ]]
    # Rejection must not append (L-286: validate before mutate).
    [ "$(_line_count)" -eq "$before" ]
}

@test "t1719: out-of-range ratings are rejected in both directions" {
    before=$(_line_count)
    for v in 6 -6 99; do
        run "$FW" task update "$FIX_ID" --happiness "$v"
        [ "$status" -ne 0 ]
    done
    [ "$(_line_count)" -eq "$before" ]
}

@test "t1719: non-integer ratings are rejected before any range arithmetic" {
    # Guarding this separately matters: `$((...))` on a non-numeric string is a
    # bash error under `set -e`, so the regex check must come first or the
    # failure mode is a shell trace rather than an actionable message.
    before=$(_line_count)
    run "$FW" task update "$FIX_ID" --happiness abc
    [ "$status" -ne 0 ]
    [[ "$output" == *"must be an integer"* ]]
    [ "$(_line_count)" -eq "$before" ]
}

@test "t1719: a valid rating appends exactly one well-formed JSON row" {
    before=$(_line_count)
    run "$FW" task update "$FIX_ID" --happiness +3 --happiness-reason "bats probe"
    [ "$status" -eq 0 ]
    [ "$(_line_count)" -eq "$((before + 1))" ]

    # The last row must parse and carry the full schema.
    run python3 -c "
import json, sys
row = json.loads(open('$HAPPINESS_FILE').read().strip().split('\n')[-1])
assert row['task_id'] == 'T-0000', row
assert row['value'] == 3, row
assert row['source'] in ('human', 'agent'), row
assert row['reason'] == 'bats probe', row
assert row['ts'].endswith('Z'), row
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t1719: negative ratings are accepted — the signal must carry bad news" {
    # A happiness signal that can only record success is not a signal. The
    # routing loop learns from the misses, so -1..-5 must round-trip.
    before=$(_line_count)
    run "$FW" task update "$FIX_ID" --happiness -2
    [ "$status" -eq 0 ]
    [ "$(_line_count)" -eq "$((before + 1))" ]

    run python3 -c "
import json
row = json.loads(open('$HAPPINESS_FILE').read().strip().split('\n')[-1])
assert row['value'] == -2, row
print('ok')
"
    [ "$status" -eq 0 ]
}

@test "t1719: ratings accumulate — a new rating never overwrites a prior one" {
    before=$(_line_count)
    "$FW" task update "$FIX_ID" --happiness +1 >/dev/null 2>&1
    "$FW" task update "$FIX_ID" --happiness +5 >/dev/null 2>&1
    [ "$(_line_count)" -eq "$((before + 2))" ]

    # Both values survive, in order.
    run python3 -c "
import json
rows = [json.loads(l) for l in open('$HAPPINESS_FILE') if l.strip()]
vals = [r['value'] for r in rows[-2:]]
assert vals == [1, 5], vals
print('ok')
"
    [ "$status" -eq 0 ]
}

@test "t1719: the reason field is omitted rather than empty when not supplied" {
    # An empty-string reason and an absent reason are different claims. Consumers
    # reading the trend should not have to distinguish "" from "no comment".
    "$FW" task update "$FIX_ID" --happiness +2 >/dev/null 2>&1
    run python3 -c "
import json
row = json.loads(open('$HAPPINESS_FILE').read().strip().split('\n')[-1])
assert 'reason' not in row, row
print('ok')
"
    [ "$status" -eq 0 ]
}
