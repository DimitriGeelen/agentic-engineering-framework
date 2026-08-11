#!/usr/bin/env bats
# T-2926 — fw doctor's resolver-health blocks: the latch surface, and the
# brace-expansion bug that made the sibling stalled-block silently inert.
#
# Two defects, one file, found together because the doctor code that surfaces
# them was written during T-2915 and never committed — 38 uncommitted lines in
# bin/fw across at least two sessions, invisible to git log, recovered only
# because a branch reconcile needed the file stashed.
#
# Defect 1 (the reason this suite exists at all):
#
#     _stalled_count=$(echo "${_stalled_json:-{}}" | python3 -c "...")
#
# `${var:-{}}` looks like a safe empty-default. It is not. Bash's brace matching
# inside parameter expansion terminates the expansion at the FIRST `}`, so the
# remaining `}` is emitted as a literal — appended to the value whenever the
# variable IS set. JSON always ends in `}`, so valid output became invalid on
# every non-empty run.
#
# And the consumer swallowed it:
#
#     try:    d = json.load(sys.stdin)
#     except: d = {}
#
# so a corrupted payload produced count 0 rather than an error. The WARN
# therefore never fired regardless of the real stalled count — a false green
# indistinguishable from "nothing is wrong", which is why it survived.
#
# Defect 2: the latched block did not exist in any committed form.
#
# The legs below assert SHELL behaviour rather than re-implementing it: the bug
# is in the shell's expansion rules, and a Python reimplementation of the
# pipeline cannot reproduce it.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    FW="$FRAMEWORK_ROOT/bin/fw"
}

# ── Defect 1: the expansion itself ───────────────────────────────────────────

@test "t2926: anti-vacuity — the old form DOES corrupt a JSON value ending in }" {
    # Reconstructs the original defect and requires it to bite. Without this
    # leg the suite could pass in a world where the bug never existed, and we
    # would have no evidence the fixed form is fixing anything.
    run bash -c '_j="{\"a\":1}"; printf "%s" "${_j:-{}}"'
    [ "$status" -eq 0 ]
    [ "$output" = '{"a":1}}' ]   # <-- the stray trailing } is the bug
}

@test "t2926: the fixed form round-trips a JSON value unmodified" {
    run bash -c '_j="{\"a\":1}"; [ -z "$_j" ] && _j="{}"; printf "%s" "$_j"'
    [ "$status" -eq 0 ]
    [ "$output" = '{"a":1}' ]
}

@test "t2926: the fixed form still defaults an EMPTY value to {}" {
    # The empty-default behaviour is the whole reason the original author
    # reached for that expansion. Losing it while fixing the corruption would
    # trade one defect for another.
    run bash -c '_j=""; [ -z "$_j" ] && _j="{}"; printf "%s" "$_j"'
    [ "$status" -eq 0 ]
    [ "$output" = '{}' ]
}

@test "t2926: corrupted JSON reaches the consumer as invalid, not as zero" {
    # The second half of the failure: json.load on the corrupted payload raises,
    # and the `except: d = {}` in the original turned that raise into a count of
    # 0. This leg pins WHY the defect was silent, so a future reader does not
    # "simplify" the bare except back in.
    run bash -c '_j="{\"stalled\":{\"T-1\":{}}}"; printf "%s" "${_j:-{}}" | python3 -c "
import sys, json
try:
    json.load(sys.stdin)
    print(\"PARSED\")
except Exception:
    print(\"RAISED\")
"'
    [ "$status" -eq 0 ]
    [ "$output" = "RAISED" ]
}

@test "t2926: no defective brace-expansion remains on either JSON variable in bin/fw" {
    # The instance, not the mention — and this leg got that wrong on its first
    # run. Scoping to bin/fw and anchoring to the two variable names was not
    # enough: bin/fw:2672 is the COMMENT that explains the bug, quoting the
    # defective form verbatim, and the leg flagged it. A detector for
    # mention-vs-instance that itself matched a mention.
    #
    # So: drop comment-only lines before judging. Limitation stated rather than
    # implied — a defective expansion sharing a line with a trailing comment is
    # still caught (only whole-line comments are dropped), but this is a text
    # scan, not a parse, and legs 1-4 are the behavioural guard that matters.
    code=$(grep -vE '^[[:space:]]*#' "$FW")
    if echo "$code" | grep -nE '\$\{_(stalled|latched)_json:-'; then
        echo "defective brace-expansion still present in bin/fw (code, not comment)" >&2
        return 1
    fi
}

# ── Defect 2: the latch surface exists and is wired ──────────────────────────

@test "t2926: fw doctor has a latched block wired to fw resolver latched" {
    run grep -c 'resolver.py" latched --json' "$FW"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "t2926: the latched block has both an OK and a WARN branch" {
    grep -q 'No stale in-flight latches' "$FW" || {
        echo "OK branch missing — a check with no clean verdict cannot be read as passing" >&2
        return 1
    }
    grep -q 'latched stale — no terminal_event' "$FW" || {
        echo "WARN branch missing" >&2
        return 1
    }
}

@test "t2926: the latched listing is capped but names what it dropped" {
    # No-silent-caps: a truncated list that does not say it was truncated reads
    # as "these are all of them". 250 latched dispatches were live when this
    # shipped, so the cap is load-bearing and so is the elision line.
    grep -q 'rows\[:5\]' "$FW" || {
        echo "listing is not capped — 250 rows would bury every other finding" >&2
        return 1
    }
    grep -q 'more (oldest shown first)' "$FW" || {
        echo "cap is SILENT — no elision line naming the dropped count" >&2
        return 1
    }
}

@test "t2926: fw resolver latched --json returns parseable JSON with a latched key" {
    # Drives the real producer. If this returns nothing parseable, the doctor
    # block's count is 0 for the wrong reason and its OK branch is a false green
    # — exactly defect 1's shape, one layer up.
    run bash -c "cd '$FRAMEWORK_ROOT' && PROJECT_ROOT='$FRAMEWORK_ROOT' python3 '$FRAMEWORK_ROOT/lib/resolver.py' latched --json"
    [ "$status" -eq 0 ]
    payload="$output"
    run python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert 'latched' in d, 'no latched key in resolver output'
print('OK %d' % len(d['latched'] or {}))
" <<< "$payload"
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    [[ "$output" == OK* ]]
}
