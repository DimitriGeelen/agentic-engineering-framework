#!/usr/bin/env bats
# T-3051 — repo-tracked helper scripts must not be gated on their exec bit.
#
# git records only one permission bit, and it was recorded wrong for three
# helpers. Every gate of the form `[ -x "$helper" ]` therefore evaluated false
# on any install derived from a clone, and because all three call sites are
# deliberately non-fatal, a skipped helper is indistinguishable from a
# successful one. That is why this went two months unreported.
#
# The behavioural test below is written the only way that proves anything: the
# exec bit is REMOVED and the helper must still run. Asserting it runs while the
# bit is present passes against the broken code too.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    export PICKUP_DIR="$PROJECT_ROOT/.context/pickup"
    export PICKUP_INBOX="$PICKUP_DIR/inbox"
    export PICKUP_PROCESSED="$PICKUP_DIR/processed"
    export PICKUP_REJECTED="$PICKUP_DIR/rejected"
    export PICKUP_AUTO_DEFERRED="$PICKUP_DIR/auto-deferred"
    export PICKUP_DEDUP_LOG="$PICKUP_DIR/dedup.log"
    mkdir -p "$PICKUP_INBOX" "$PICKUP_PROCESSED"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

# Build a throwaway FRAMEWORK_ROOT holding a bridge at the given mode, and
# source the real lib/pickup.sh against it.
_stage_bridge() {
    local mode="$1" src="${2:-$FRAMEWORK_ROOT/lib/pickup.sh}"
    FAKE_FW="$TEST_TEMP_DIR/fw"
    MARKER="$TEST_TEMP_DIR/bridge-ran"
    mkdir -p "$FAKE_FW/lib"
    printf '#!/usr/bin/env bash\ntouch "%s"\n' "$MARKER" > "$FAKE_FW/lib/pickup-channel-bridge.sh"
    chmod "$mode" "$FAKE_FW/lib/pickup-channel-bridge.sh"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$src"

    # Neutralise the legs this test is not about: task creation, notification,
    # dedup bookkeeping. Redefining after sourcing is what makes the bridge the
    # only observable effect.
    pickup_create_inception() { :; }
    pickup_record_dedup() { :; }
    fw_notify() { :; }

    export FRAMEWORK_ROOT="$FAKE_FW"
}

_envelope() {
    cat > "$1" <<'EOF'
pickup_id: P-001
version: 1
type: bug-report
source:
  project: "t3051"
  task_id: "T-042"
  agent: "claude-code"
  timestamp: "2026-08-16T12:00:00Z"
payload:
  summary: "exec bit gate regression"
  detail: "d"
  evidence: "lib/pickup.sh:473"
  priority: high
  tags: [test]
EOF
}

@test "A3 — the bridge runs with its exec bit REMOVED (the actual failing condition)" {
    _stage_bridge 644
    _envelope "$PICKUP_INBOX/p.yaml"
    pickup_process_one "$PICKUP_INBOX/p.yaml" >/dev/null 2>&1 || true
    [ -f "$MARKER" ]
}

@test "A3 — the same test fails against the old -x gate (the guard discriminates)" {
    # Mutation: restore the pre-T-3051 form in a copy and prove this test
    # notices. Without this, a green above says nothing about whether the fix
    # is what makes it green.
    local mutant="$TEST_TEMP_DIR/pickup-mutant.sh"
    sed 's|\[ -f "\$processed_path" \] && \[ -f "\$bridge" \]|[ -f "$processed_path" ] \&\& [ -x "$bridge" ]|; s|^        bash "\$bridge"|        "$bridge"|' \
        "$FRAMEWORK_ROOT/lib/pickup.sh" > "$mutant"
    grep -q '\[ -x "\$bridge" \]' "$mutant"     # the mutation actually applied

    _stage_bridge 644 "$mutant"
    _envelope "$PICKUP_INBOX/p.yaml"
    pickup_process_one "$PICKUP_INBOX/p.yaml" >/dev/null 2>&1 || true
    [ ! -f "$MARKER" ]
}

@test "A3 — the bridge still runs when the exec bit IS present" {
    _stage_bridge 755
    _envelope "$PICKUP_INBOX/p.yaml"
    pickup_process_one "$PICKUP_INBOX/p.yaml" >/dev/null 2>&1 || true
    [ -f "$MARKER" ]
}

@test "A2 — every repo-tracked helper that a gate invokes is mode 100755 in git" {
    cd "$FRAMEWORK_ROOT"
    for f in lib/pickup-channel-bridge.sh \
             agents/termlink/bvp-estimator/bvp-estimator.sh \
             agents/handover/discard-manifest.sh; do
        mode="$(git ls-files -s "$f" | awk '{print $1}')"
        [ "$mode" = "100755" ] || { echo "$f is $mode, expected 100755"; false; }
    done
}

@test "A4 — no call site gates one of those three helpers on its exec bit" {
    cd "$FRAMEWORK_ROOT"
    # Catches both spellings: the literal path and the \$bridge indirection.
    ! grep -rnE '\[ -x .*(pickup-channel-bridge|bvp-estimator|discard-manifest)' \
        lib/ agents/ bin/fw
    ! grep -n '\[ -x "\$bridge" \]' lib/pickup.sh
}
