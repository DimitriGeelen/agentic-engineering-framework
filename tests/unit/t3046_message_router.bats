#!/usr/bin/env bats
# T-3046 — static msg_type router for recovered hub messages (slice 1 of T-3044).
#
# Every test here asserts that the FAILING state actually fails, not merely that
# the passing state passes. This session found three separate checks that were
# green because they asserted less than their name implied (write-set `disjoint`,
# a reachable-but-dead embed endpoint, an empty Verification block), so a guard
# that has never been observed red is not treated as a guard.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR/repo"
    ARCHIVE="$PROJECT_ROOT/.context/message-archive/raw"
    LEDGER="$PROJECT_ROOT/.context/triage-dispositions.jsonl"
    mkdir -p "$ARCHIVE"
    ROUTER="$FRAMEWORK_ROOT/lib/message_router.py"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# _archive <file-stem> <json-array-of-messages>
_archive() {
    printf '%s' "$2" > "$ARCHIVE/$1.raw.json"
}

_msg() {
    # _msg <msg_type> [offset] [topic]
    printf '{"msg_type":"%s","offset":%s,"topic":"%s","sender_id":"s","ts":"t","payload_b64":"","artifact_ref":null}' \
        "$1" "${2:-0}" "${3:-topic-a}"
}

_route() {
    env PROJECT_ROOT="$PROJECT_ROOT" python3 "$ROUTER" "$@"
}

@test "A1 — an unclassified msg_type is a hard error, not a silent default" {
    # The whole point: a new producer must surface as a failure. If this ever
    # returns 0, messages are being swallowed exactly as they were for 3 months.
    _archive one "[$(_msg 'totally-new-producer-type')]"
    run _route --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"totally-new-producer-type"* ]]
    [[ "$output" == *"match no rule"* ]]
}

@test "A1 — a known type classifies and the same run then succeeds" {
    # Companion to the test above: proves the failure was about the unknown type
    # and not about the harness being broken in some unrelated way.
    _archive one "[$(_msg 'heartbeat')]"
    run _route --dry-run
    [ "$status" -eq 0 ]
}

@test "A1 — prefix families absorb unseen members of a known family" {
    # learning-PL-099 has never existed, but must not be a hard error: that is
    # the difference between a family rule and a 79-row literal table.
    _archive one "[$(_msg 'learning-PL-099')]"
    run _route --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"deferred"* ]]
}

@test "A2 — dry-run writes nothing (asserted on the ledger, not on the message)" {
    _archive one "[$(_msg 'heartbeat'),$(_msg 'pickup' 1)]"
    run _route --dry-run
    [ "$status" -eq 0 ]
    [ ! -f "$LEDGER" ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "A3 — count identity: one ledger row per message read, no more, no fewer" {
    _archive one "[$(_msg 'heartbeat'),$(_msg 'pickup' 1),$(_msg 'note' 2)]"
    run _route
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LEDGER")" -eq 3 ]
}

@test "A3 — every dropped/deferred row carries a non-empty reason" {
    _archive one "[$(_msg 'heartbeat'),$(_msg 'note' 1)]"
    run _route
    [ "$status" -eq 0 ]
    run python3 -c "
import json,sys
rows=[json.loads(l) for l in open('$LEDGER')]
bad=[r for r in rows if r['disposition'] in ('dropped','deferred') and not r.get('reason')]
sys.exit(1 if bad else 0)"
    [ "$status" -eq 0 ]
}

@test "A4 — idempotent: a second run over the same archive appends zero rows" {
    _archive one "[$(_msg 'heartbeat'),$(_msg 'pickup' 1)]"
    _route >/dev/null
    before="$(wc -l < "$LEDGER")"
    run _route
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LEDGER")" -eq "$before" ]
    [[ "$output" == *"new disposition rows: 0"* ]]
}

@test "A4 — dedupe is on content, so re-recovery into a new dated file is not re-routed" {
    # This is the case (source_file, topic, offset) cannot survive, and it is not
    # hypothetical: the archive is produced as dated files, so the same message
    # reappears under a new name on the next recovery.
    _archive local-topic-20260816 "[$(_msg 'pickup')]"
    _route >/dev/null
    [ "$(wc -l < "$LEDGER")" -eq 1 ]
    _archive local-topic-20260817 "[$(_msg 'pickup')]"   # same content, new file
    run _route
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LEDGER")" -eq 1 ]
}

@test "A4 — a genuinely different message IS appended (dedupe is not over-matching)" {
    # Guards the inverse failure of the test above: dedupe so aggressive that it
    # swallows real messages would look identical to correct idempotency.
    _archive one "[$(_msg 'pickup')]"
    _route >/dev/null
    _archive two "[$(_msg 'pickup' 99 'topic-b')]"
    run _route
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LEDGER")" -eq 2 ]
}

@test "A6 — all four pickup spellings route to the pickup handler" {
    # T-3044's artifact named only 'framework-pickup'; the archive holds four.
    _archive one "[$(_msg 'pickup'),$(_msg 'framework:pickup' 1),$(_msg 'framework-pickup' 2),$(_msg 'upstream-pickup' 3)]"
    run _route --dry-run --json
    [ "$status" -eq 0 ]
    run python3 -c "
import json,subprocess,sys
r=json.loads(subprocess.run(['python3','$ROUTER','--dry-run','--json'],
    capture_output=True,text=True,env={'PROJECT_ROOT':'$PROJECT_ROOT','PATH':'/usr/bin:/bin'}).stdout)
sys.exit(0 if r['counts'].get('routed')==4 else 1)"
    [ "$status" -eq 0 ]
}

@test "A8 — the origin case surfaces, and is never dropped" {
    # The three-month-old bug report. If this drops, the slice has not cleared
    # the only bar it was created to clear.
    _archive one "[$(_msg 'pickup-bug-report'),$(_msg 'bug-report' 1),$(_msg 'pickup-bug-report-followup' 2)]"
    run _route
    [ "$status" -eq 0 ]
    run python3 -c "
import json,sys
rows=[json.loads(l) for l in open('$LEDGER')]
sys.exit(0 if all(r['disposition']=='surfaced' for r in rows) else 1)"
    [ "$status" -eq 0 ]
}

@test "A6 — telemetry is dropped, never surfaced to a human" {
    _archive one "[$(_msg 'dashboard.health-state'),$(_msg 'heartbeat' 1),$(_msg 'fed-probe' 2)]"
    run _route
    [ "$status" -eq 0 ]
    run python3 -c "
import json,sys
rows=[json.loads(l) for l in open('$LEDGER')]
sys.exit(0 if all(r['disposition']=='dropped' for r in rows) else 1)"
    [ "$status" -eq 0 ]
}

@test "A5 — the ledger is declared in the implicit write-set" {
    run python3 -c "
import sys; sys.path.insert(0,'$FRAMEWORK_ROOT/lib')
import write_set as w
sys.exit(0 if '.context/triage-dispositions.jsonl' in w.implicit_paths() else 1)"
    [ "$status" -eq 0 ]
}

@test "a corrupt archive file is loud, not skipped" {
    # Skipping an unreadable file silently is the same bug class as a silent drop.
    printf 'not json at all' > "$ARCHIVE/broken.raw.json"
    run _route --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"unreadable archive file"* ]]
}

@test "fw triage --help documents the four dispositions" {
    run "$FRAMEWORK_ROOT/bin/fw" triage --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"routed"* ]]
    [[ "$output" == *"surfaced"* ]]
    [[ "$output" == *"deferred"* ]]
    [[ "$output" == *"dropped"* ]]
}

@test "fw triage with an unknown subcommand exits 64" {
    run "$FRAMEWORK_ROOT/bin/fw" triage bogus
    [ "$status" -eq 64 ]
}
