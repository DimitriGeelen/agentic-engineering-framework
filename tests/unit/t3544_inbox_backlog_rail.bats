#!/usr/bin/env bats
# T-3544 / OBS-567 — the audit rail over the INBOUND consult backlog.
#
# `fw_sidecar_inbox_stale_facts <root> [threshold_hours]` (lib/sidecar-audit.sh)
# is the fact function behind the WARN in both `fw doctor` and audit.sh's
# check_sidecar_ledger. It prints one tab-separated line per stale topic
#     TOPIC  UNREAD  AGE_HOURS  OLDEST_FROM
# and shares the rc contract its two siblings established: rc 0 facts printed,
# rc 1 nothing to check (caller stays SILENT), rc 2 the check could not run
# (caller SAYS SO, never prints zeros for a check that did not happen).
#
# It is hub-calling, like dm-stale and unlike the ledger: how many records sit
# past our cursor has no durable local answer. So the tests here stub
# `termlink` on PATH and drive the real sidecar_cli.py through it.
#
# What the rail exists for: an inbound consult was visible only to someone who
# chose to run `fw sidecar inbox`, with no reason to think there was anything
# to read. 832-Workflow-designer waited six days that way.

load ../test_helper

SIDECAR_AUDIT_LIB="$FRAMEWORK_ROOT/lib/sidecar-audit.sh"
AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"
FW_BIN="$FRAMEWORK_ROOT/bin/fw"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_ROOT="$(mktemp -d)"
    STUB_BIN="$TEST_ROOT/stub-bin"
    mkdir -p "$STUB_BIN"
}

teardown() {
    [ -d "${TEST_ROOT:-}" ] && rm -rf "$TEST_ROOT"
}

# make_sidecar — a .context/sidecar dir marks the sidecar as present.
make_sidecar() {
    mkdir -p "$TEST_ROOT/.context/sidecar"
}

# seed_hub_id — the on-disk hub-anchor cache circuit.hub_id() reads before it
# shells out (`.context/sidecar/hub-id`). Seeding it is how these tests get a
# derivable address without the stub having to emulate `hub fingerprint`'s
# exact `sha256:<16 hex>` output shape. Tests that must stage an UNREADABLE
# anchor simply do not call this.
seed_hub_id() {
    mkdir -p "$TEST_ROOT/.context/sidecar"
    echo cacc73ea32b121dd > "$TEST_ROOT/.context/sidecar/hub-id"
}

# stub_termlink AGE_HOURS [SENDER] — a fake `termlink` whose `channel
# subscribe` emits one consult envelope aged AGE_HOURS, for every topic.
# Any other subcommand returns empty, which is what the real binary does for
# a topic with nothing on it.
stub_termlink() {
    local age="$1" sender="${2:-832-Workflow-designer}"
    cat > "$STUB_BIN/termlink" <<STUB
#!/usr/bin/env bash
if [ "\$1" = "hub" ] && [ "\$2" = "fingerprint" ]; then
    echo sha256:cacc73ea32b121dd
    exit 0
fi
if [ "\$1" = "channel" ] && [ "\$2" = "subscribe" ]; then
    python3 -c '
import base64, json, sys, time
age = float(sys.argv[1])
print(json.dumps({
    "offset": 0,
    "metadata": {"from_agent": sys.argv[2], "client_msg_id": "cmid-" + sys.argv[3],
                 "conversation_id": "conv-1"},
    "payload_b64": base64.b64encode(b"is from_circuit trust-bearing?").decode(),
    "ts": int((time.time() - age * 3600) * 1000),
}))
' "$age" "$sender" "\$4"
fi
exit 0
STUB
    chmod +x "$STUB_BIN/termlink"
}

# stub_termlink_silent — present on PATH, but every topic is empty.
stub_termlink_silent() {
    cat > "$STUB_BIN/termlink" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "hub" ] && [ "$2" = "fingerprint" ]; then echo sha256:cacc73ea32b121dd; fi
exit 0
STUB
    chmod +x "$STUB_BIN/termlink"
}

# stub_termlink_no_hub — installed, but the hub anchor is unreadable, so no
# address can be derived. Must degrade to rc 2 ("could not run"), never to a
# silent rc 0 that reads as "nothing is waiting".
stub_termlink_no_hub() {
    printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB_BIN/termlink"
    chmod +x "$STUB_BIN/termlink"
}

facts() {
    PATH="$STUB_BIN:$PATH" bash -c \
        "source '$SIDECAR_AUDIT_LIB'; fw_sidecar_inbox_stale_facts '$TEST_ROOT' ${1:-24}"
}

# ── rc contract ──────────────────────────────────────────────────────────────

@test "no sidecar dir: silent, rc 1, and the call does not create one" {
    stub_termlink 99
    run facts
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ ! -d "$TEST_ROOT/.context/sidecar" ]
}

@test "termlink absent: rc 1, silent — nothing to check is not a failure" {
    make_sidecar
    # A PATH that still has a shell and coreutils but no termlink. If the host
    # ships termlink in one of these, the premise does not hold here.
    bare="/usr/bin:/bin"
    PATH="$bare" command -v termlink >/dev/null 2>&1 && \
        skip "termlink is on the minimal PATH; cannot stage its absence"
    run env PATH="$bare" bash -c \
        "source '$SIDECAR_AUDIT_LIB'; fw_sidecar_inbox_stale_facts '$TEST_ROOT' 24"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "hub anchor unreadable: rc 2, NOT a silent rc 0 that reads as 'nothing waiting'" {
    make_sidecar
    stub_termlink_no_hub
    run facts 24
    [ "$status" -eq 2 ]
}

@test "sidecar_cli.py missing: rc 2, so the caller says so rather than reporting zero" {
    make_sidecar
    stub_termlink 99
    cp "$SIDECAR_AUDIT_LIB" "$TEST_ROOT/orphan-audit.sh"   # no sidecar_cli.py beside it
    run env PATH="$STUB_BIN:$PATH" bash -c \
        "source '$TEST_ROOT/orphan-audit.sh'; fw_sidecar_inbox_stale_facts '$TEST_ROOT' 24"
    [ "$status" -eq 2 ]
}

# ── facts ────────────────────────────────────────────────────────────────────

@test "an old unread consult is reported with count, age and the waiting peer" {
    make_sidecar
    seed_hub_id
    stub_termlink 168 "832-Workflow-designer"     # six days, the origin case
    run facts 24
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | grep -q '832-Workflow-designer'
    # TOPIC UNREAD AGE_HOURS OLDEST_FROM — four tab-separated fields
    [ "$(echo "$output" | head -1 | awk -F'\t' '{print NF}')" -eq 4 ]
    [ "$(echo "$output" | head -1 | awk -F'\t' '{print $2}')" -ge 1 ]
}

@test "a consult younger than the threshold is not reported" {
    make_sidecar
    seed_hub_id
    stub_termlink 1
    run facts 24
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "NEGATIVE CONTROL: an empty inbox produces no rows, so a row means something" {
    make_sidecar
    seed_hub_id
    stub_termlink_silent
    run facts 0
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the check does not drain what it measures — cursors unmoved across a run" {
    make_sidecar
    seed_hub_id
    stub_termlink 168
    facts 24 >/dev/null
    before=$(cat "$TEST_ROOT/.context/sidecar/inbox-state.json" 2>/dev/null || echo ABSENT)
    facts 24 >/dev/null
    after=$(cat "$TEST_ROOT/.context/sidecar/inbox-state.json" 2>/dev/null || echo ABSENT)
    [ "$before" = "$after" ]
    # and the backlog is still reported on the second run
    run facts 24
    [ -n "$output" ]
}

# ── consumers ────────────────────────────────────────────────────────────────

@test "audit's check_sidecar_ledger consumes the fact function and names the remedy" {
    body=$(awk '/^check_sidecar_ledger\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$AUDIT_SH")
    [ -n "$body" ]
    printf '%s\n' "$body" | grep -q 'fw_sidecar_inbox_stale_facts'
    printf '%s\n' "$body" | grep -q 'unread consult'
    printf '%s\n' "$body" | grep -q 'sidecar inbox --peek'
    # rc 2 must produce its own WARN, not be folded into the rc 0 path
    printf '%s\n' "$body" | grep -q 'consult-inbox backlog check could not run'
}

@test "fw doctor consumes the same fact function with the same rc-2 branch" {
    grep -q 'fw_sidecar_inbox_stale_facts' "$FW_BIN"
    grep -q 'Consult-inbox backlog check could not run' "$FW_BIN"
    grep -q 'A peer is waiting' "$FW_BIN"
}

@test "the threshold is configurable and defaults below the dm rail's" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/config.sh'; fw_config SIDECAR_CONSULT_WARN_HOURS"
    [ "$status" -eq 0 ]
    [ "$output" -lt 24 ]
    # both consumers must read it rather than hard-coding a number
    grep -q 'fw_sidecar_inbox_stale_facts "$PROJECT_ROOT" "$(fw_config SIDECAR_CONSULT_WARN_HOURS)"' "$FW_BIN"
    grep -q 'fw_sidecar_inbox_stale_facts "$PROJECT_ROOT" "$(fw_config SIDECAR_CONSULT_WARN_HOURS)"' "$AUDIT_SH"
}
