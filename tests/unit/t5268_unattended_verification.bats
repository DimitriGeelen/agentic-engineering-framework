#!/usr/bin/env bats
# T-5268 (0506-Voxtype-extention P25): stored Verification lines re-run unattended
# on a live host by CTL-013 and verify-queue (CTL-013b). One shared predicate
# (lib/unattended_verification.py) decides whether a line may run; an author can
# mark a line `# needs: fixture`; process control is refused; every run or skip is
# appended to .context/audits/verify-queue/history.jsonl. The P-011 close gate
# still runs a marked line (bash reads the marker as a comment).
#
# Every "skipped" leg proves non-execution with a marker file the line would
# create if it ran; every "runs" leg proves execution the same way.

load ../test_helper

UV="$FRAMEWORK_ROOT/lib/unattended_verification.py"
VQ="$FRAMEWORK_ROOT/lib/verify_queue.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    P="$(create_test_project "$TEST_TEMP_DIR/project")"
    HIST="$P/.context/audits/verify-queue/history.jsonl"
    BLOCK="$TEST_TEMP_DIR/ctl013.sh"
    awk '/^# CTL-013 OE:/{f=1} f{print} f && /^shopt -u nullglob$/{exit}' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh" > "$BLOCK"
    grep -q 'unattended_verification.py" check' "$BLOCK" || \
        { echo "CTL-013 block does not call the shared predicate" >&2; return 1; }
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# Lines that would leave $P/ran if executed.
MARKED='touch ran # needs: fixture'
PKILL='touch ran; echo pkill'
KILL='touch ran; kill -TERM 999999999 2>/dev/null || true'
KILL0='kill -0 $$ && touch ran'

vq() {  # vq <verification-line>
    rm -f "$P/ran"
    printf -- '---\nid: T-9900\nstatus: work-completed\nowner: human\n---\n\n## Verification\n\n%s\n\n## Updates\n' \
        "$1" > "$P/.tasks/active/T-9900-vq.md"
    run env PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" FW_VERIFY_QUEUE_TIMEOUT=20 \
        python3 "$VQ" --task T-9900
}

ctl013() {  # ctl013 <verification-line>
    rm -f "$P/ran" "$P/.tasks/completed/"*.md
    printf -- '---\nid: T-9901\n---\n\n## Verification\n\n%s\n\n## Updates\n' \
        "$1" > "$P/.tasks/completed/T-9901-fixture.md"
    run env TASKS_DIR="$P/.tasks" PROJECT_ROOT="$P" CONTEXT_DIR="$P/.context" bash -c '
        cd "$PROJECT_ROOT"
        pass() { echo "PASS: $1"; }
        warn() { echo "WARN: $1"; }
        source "$1"
    ' _ "$BLOCK"
}

# ── the predicate ────────────────────────────────────────────────────────────

@test "predicate: marker and process control are refused with a reason (exit 3)" {
    for line in "$MARKED" "bash spike.sh  #NEEDS: Fixture (live service)" \
                "pkill -f voxtype-review" "killall foo" "kill 1234" "kill -TERM 5" "kill -9 5" \
                "systemctl --user stop foo" "systemctl restart foo" "service nginx stop" \
                "sudo shutdown -h now" "x && reboot" "bin/fw audit | grep -q x" "rm -rf /tmp/x"; do
        run python3 "$UV" check "$line"
        [ "$status" -eq 3 ] || { echo "not refused: $line"; false; }
        [ -n "$output" ]
    done
}

@test "predicate: kill -0 and read-only lines may run (exit 0)" {
    for line in 'kill -0 $(cat x.pid)' "systemctl status foo" "grep -q shutdown log" \
                "test -f reboot.log" "fw auditor x" "echo skill"; do
        run python3 "$UV" check "$line"
        [ "$status" -eq 0 ] || { echo "refused: $line -> $output"; false; }
    done
}

@test "predicate: verify_queue imports the shared patterns, holds no copy" {
    run grep -c 're.compile' "$VQ"
    [ "$output" -eq 0 ]
    grep -q 'from unattended_verification import' "$VQ"
}

# ── verify-queue ─────────────────────────────────────────────────────────────

@test "verify-queue: a marked line is skipped with its reason and never runs" {
    vq "$MARKED"
    [ "$status" -eq 0 ]
    [[ "$output" == *SKIP* ]] && [[ "$output" != *PASS* ]]
    [[ "$output" == *"INFO skipped (declared '# needs: fixture'"* ]]
    [ ! -e "$P/ran" ]
}

@test "verify-queue: process control is skipped and never runs" {
    for line in "$PKILL" "$KILL"; do
        vq "$line"
        [[ "$output" == *"process control"* ]] || { echo "$output"; false; }
        [ ! -e "$P/ran" ] || { echo "executed: $line"; false; }
    done
}

@test "verify-queue: kill -0 is NOT skipped" {
    vq "$KILL0"
    [[ "$output" == *PASS* ]]
    [ -e "$P/ran" ]
}

@test "verify-queue: appends one history row per line run or skipped" {
    vq "$MARKED"; vq "$KILL0"; vq "false"
    [ "$(wc -l < "$HIST")" -eq 3 ]
    python3 - "$HIST" <<'PY'
import json, sys, hashlib
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["outcome"] for r in rows] == ["skipped", "pass", "fail"], rows
for r in rows:
    assert r["runner"] == "verify-queue" and r["task"] == "T-9900", r
    assert set(r) == {"ts", "runner", "task", "line_sha256", "outcome", "reason"}, r
    assert r["ts"].endswith("Z") and len(r["line_sha256"]) == 64
assert rows[1]["line_sha256"] == hashlib.sha256(b"kill -0 $$ && touch ran").hexdigest()
assert "needs: fixture" in rows[0]["reason"]
PY
}

# ── CTL-013 ──────────────────────────────────────────────────────────────────

@test "CTL-013: a marked line is skipped with its reason, never counted as a pass" {
    ctl013 "$MARKED"
    [[ "${lines[0]}" == "PASS: CTL-013: T-9901 verification re-run: 0/0 pass (1 skipped — declared '# needs: fixture' (runs at close only))" ]]
    [ ! -e "$P/ran" ]
}

@test "CTL-013: process control is skipped and never runs" {
    for line in "$PKILL" "$KILL"; do
        ctl013 "$line"
        [[ "${lines[0]}" == *"0/0 pass (1 skipped — process control"* ]] || { echo "$output"; false; }
        [ ! -e "$P/ran" ] || { echo "executed: $line"; false; }
    done
}

@test "CTL-013: now refuses verify-queue's patterns too (no second list)" {
    ctl013 'touch ran; curl -s -X POST http://127.0.0.1:9/x || true'
    [[ "${lines[0]}" == *"1 skipped — HTTP write against a live service"* ]]
    [ ! -e "$P/ran" ]
}

@test "CTL-013: kill -0 is NOT skipped" {
    ctl013 "$KILL0"
    [[ "${lines[0]}" == "PASS: CTL-013: T-9901 verification re-run: 1/1 pass" ]]
    [ -e "$P/ran" ]
}

@test "CTL-013: appends one history row per line run or skipped, never rewrites" {
    ctl013 "$MARKED"; ctl013 "$KILL0"
    first=$(head -1 "$HIST")
    ctl013 "false"
    [ "$(wc -l < "$HIST")" -eq 3 ]
    [ "$(head -1 "$HIST")" = "$first" ]
    python3 - "$HIST" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["outcome"] for r in rows] == ["skipped", "pass", "fail"], rows
assert all(r["runner"] == "ctl-013" and r["task"] == "T-9901" for r in rows), rows
assert rows[2]["reason"] == "rc=1", rows
PY
}

# ── the P-011 close gate ─────────────────────────────────────────────────────

@test "P-011 close gate still runs a line carrying the marker" {
    { printf -- '---\nid: T-9902\nname: "fixture"\nstatus: started-work\n'
      printf 'workflow_type: build\nowner: agent\nhorizon: now\n'
      printf 'created: 2026-11-19T00:00:00Z\nlast_update: 2026-11-19T00:00:00Z\n---\n\n'
      printf '# T-9902: fixture\n\n## Context\n\nx\n\n## Acceptance Criteria\n\n### Agent\n- [x] done\n\n'
      printf '## Verification\n\n%s\n\n## Decisions\n\n' "$MARKED"; } > "$P/.tasks/active/T-9902-fixture.md"
    rm -f "$P/ran"
    run env PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9902 --status work-completed
    [[ "$output" == *"Verification: 1/1 passed"* ]] || { echo "$output" | tail -30; false; }
    [ -e "$P/ran" ]
}
