#!/usr/bin/env bats
# T-3420 — arc-011 sidecar slice 8: the audit rail over the consult ledger.
#
# `fw_sidecar_ledger_facts <root>` (lib/sidecar-audit.sh) is the fact function
# behind audit.sh's check_sidecar_ledger. It prints one tab-separated line
#     UNKNOWN  EXPIRED_UNSWEPT  STORED  DELIVERED  TOTAL  DEAD_LETTERS
# read from the sidecar's own files under <root> — never the hub.
#
# T-3434 appended a sixth field, DEAD_LETTERS: the subset of UNKNOWN the
# universal retry ladder gave up on (`ladder-exhausted` / `ladder-unretryable`).
# It is named separately from UNKNOWN because the remedy differs — an UNKNOWN
# the ladder is still working needs patience, a dead-letter needs a decision.
#
# States pinned here against a fixture ledger: never used (silent, rc 1), clean
# (zeros), UNKNOWN>0, expired_unswept>0, dead-letters counted and distinguished
# from plain UNKNOWN. The last test pins the design rule that the audit check
# body contains no `termlink` token at all.

load ../test_helper

SIDECAR_AUDIT_LIB="$FRAMEWORK_ROOT/lib/sidecar-audit.sh"
AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_ROOT="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

# make_outbox — an outbox dir marks the sidecar as "used" under TEST_ROOT.
make_outbox() {
    mkdir -p "$TEST_ROOT/.context/sidecar/outbox"
}

# ledger_row ID STATE DEADLINE — append one ack-ledger row in the shape
# lib/sidecar/outbox.py:record_ack writes (latest row per id wins).
ledger_row() {
    local id="$1" state="$2" deadline="${3:-null}"
    [ "$deadline" = "null" ] || deadline="\"$deadline\""
    printf '{"client_msg_id":"%s","target":"peer","hub":null,"state":"%s","deadline":%s,"error":null,"ts":"2026-09-22T08:00:00+00:00"}\n' \
        "$id" "$state" "$deadline" >> "$TEST_ROOT/.context/sidecar/awaiting-ack.jsonl"
}

# ladder_row ID STATE ERROR ATTEMPTS — a post-T-3434 row carrying ladder fields.
ladder_row() {
    local id="$1" state="$2" error="$3" attempts="${4:-16}"
    printf '{"client_msg_id":"%s","target":"peer","hub":null,"state":"%s","deadline":null,"error":"%s","attempts":%s,"next_retry_at":null,"rung":7,"ts":"2026-09-22T08:00:00+00:00"}\n' \
        "$id" "$state" "$error" "$attempts" >> "$TEST_ROOT/.context/sidecar/awaiting-ack.jsonl"
}

run_facts() {
    run bash -c "source '$SIDECAR_AUDIT_LIB'; fw_sidecar_ledger_facts '$TEST_ROOT'"
}

@test "never used (no outbox dir): silent, rc 1, and the call does not create the outbox" {
    run_facts
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ ! -d "$TEST_ROOT/.context/sidecar/outbox" ]
}

@test "clean ledger: all counters zero, rc 0" {
    make_outbox
    ledger_row a INJECTED_NOW
    ledger_row b INJECTED_LATER
    run_facts
    [ "$status" -eq 0 ]
    [ "$output" = $'0\t0\t0\t2\t0\t0' ]
}

@test "T-3717: HUB_ACCEPTED and legacy on-disk INJECTED_NOW rows both count as delivered" {
    make_outbox
    ledger_row new HUB_ACCEPTED
    ledger_row old INJECTED_NOW
    ledger_row later INJECTED_LATER
    run_facts
    [ "$status" -eq 0 ]
    [ "$output" = $'0\t0\t0\t3\t0\t0' ]
}

@test "T-3717: a legacy INJECTED_NOW row with no attempts is closed, not reopened by the ladder" {
    make_outbox
    ledger_row old INJECTED_NOW
    run env PROJECT_ROOT="$TEST_ROOT" PYTHONPATH="$FRAMEWORK_ROOT" python3 -c '
from lib.sidecar import outbox, retry
rows = outbox._read_ledger()
assert rows[0]["state"] == outbox.HUB_ACCEPTED, rows
print("open" if retry.is_open(rows[0]) else "closed")'
    [ "$status" -eq 0 ]
    [ "$output" = "closed" ]
}

@test "UNKNOWN rows are counted in field 1; a later row for the same id supersedes" {
    make_outbox
    ledger_row a STORED "2999-01-01T00:00:00+00:00"
    ledger_row a UNKNOWN
    ledger_row b UNKNOWN
    ledger_row c INJECTED_NOW
    run_facts
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "2" ]
    [ "$(printf '%s' "$output" | cut -f2)" = "0" ]
    [ "$(printf '%s' "$output" | cut -f4)" = "1" ]
}

@test "STORED past deadline and unswept is counted in field 2; a fresh STORED is not" {
    make_outbox
    ledger_row stuck STORED "2000-01-01T00:00:00+00:00"
    ledger_row fresh STORED "2999-01-01T00:00:00+00:00"
    run_facts
    [ "$status" -eq 0 ]
    [ "$output" = $'0\t1\t2\t0\t0\t0' ]
}

@test "T-3434: a ladder-exhausted row is counted in field 6 as well as field 1" {
    make_outbox
    ladder_row dead UNKNOWN "ladder-exhausted"
    ladder_row gone UNKNOWN "ladder-unretryable: message file missing"
    run_facts
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "2" ]   # both are UNKNOWN
    [ "$(printf '%s' "$output" | cut -f6)" = "2" ]   # both are dead-letters
}

@test "T-3434: an UNKNOWN the ladder did not produce is NOT a dead-letter" {
    make_outbox
    ledger_row plain UNKNOWN
    ladder_row dead UNKNOWN "ladder-exhausted"
    run_facts
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f1)" = "2" ]
    [ "$(printf '%s' "$output" | cut -f6)" = "1" ]
}

@test "T-3434: a row held between rungs is in flight, not expired-unswept" {
    make_outbox
    # attempts=1, next rung due in the far future: the ladder is holding it on
    # purpose. Before T-3434 its 30-second transport deadline would have read
    # as a missed sweep and WARNed on every in-flight message.
    printf '{"client_msg_id":"held","target":"peer","hub":null,"state":"STORED","deadline":"2000-01-01T00:00:00+00:00","error":"transport-failed: hub down","attempts":1,"next_retry_at":"2999-01-01T00:00:00+00:00","rung":0,"ts":"2026-09-22T08:00:00+00:00"}\n' \
        >> "$TEST_ROOT/.context/sidecar/awaiting-ack.jsonl"
    run_facts
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f2)" = "0" ]
    [ "$(printf '%s' "$output" | cut -f3)" = "1" ]
}

@test "T-3434: a row whose rung came due and was not worked IS expired-unswept" {
    make_outbox
    printf '{"client_msg_id":"late","target":"peer","hub":null,"state":"STORED","deadline":null,"error":"transport-failed: hub down","attempts":1,"next_retry_at":"2000-01-01T00:00:00+00:00","rung":0,"ts":"2026-09-22T08:00:00+00:00"}\n' \
        >> "$TEST_ROOT/.context/sidecar/awaiting-ack.jsonl"
    run_facts
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | cut -f2)" = "1" ]
}

@test "T-3434: the audit WARN names the dead-letter class and its reason" {
    body=$(awk '/^check_sidecar_ledger\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$AUDIT_SH")
    [ -n "$body" ]
    printf '%s' "$body" | grep -q 'dead-letter'
    printf '%s' "$body" | grep -q 'ladder-exhausted'
}

@test "audit check body reads our own ledger only: no termlink token in check_sidecar_ledger" {
    # T-3544: comments are stripped from BOTH halves now, with one rule.
    #
    # The property under test is that this check never invokes the hub
    # directly — it goes through the fact functions, which own the rc 0/1/2
    # degradation contract. That is a claim about CODE. The lib half already
    # allowed its header to name the word (to say it is absent from the code);
    # the audit half did not, so a comment that merely mentioned a PEER called
    # `010-termlink` failed a test about hub invocation. That is a check
    # measuring text where it means behaviour, which is the defect class this
    # rail exists to catch — so the test is fixed rather than the prose.
    #
    # `^[[:space:]]*#` rather than `^#`: comments inside a function body are
    # indented, so the old lib-side pattern would not have stripped them.
    body=$(awk '/^check_sidecar_ledger\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$AUDIT_SH")
    [ -n "$body" ]
    [ "$(printf '%s\n' "$body" | grep -v '^[[:space:]]*#' | grep -c 'termlink')" -eq 0 ]

    # In the lib, every non-comment mention must be an AVAILABILITY PROBE
    # (`command -v termlink`, the rc-1 "nothing to check" leg the hub-calling
    # fact functions need) and never an invocation that reads the hub here.
    # Asserted as a property rather than a count, so adding a fourth rail does
    # not go red for being a fourth rail.
    lib_hits=$(grep -v '^[[:space:]]*#' "$SIDECAR_AUDIT_LIB" | grep -c 'termlink')
    lib_probes=$(grep -v '^[[:space:]]*#' "$SIDECAR_AUDIT_LIB" | grep -c 'command -v termlink')
    [ "$lib_hits" -gt 0 ]
    [ "$lib_hits" -eq "$lib_probes" ]
}
