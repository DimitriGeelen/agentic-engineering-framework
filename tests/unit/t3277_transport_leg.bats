#!/usr/bin/env bats
# T-3277 — the driver's transport seam: one decision, two wires.
#
# WHY THIS SUITE EXISTS. G-097 measured that `termlink inject` returns 0 and
# delivers nothing into a live Claude TUI. T-3250's probe re-measured it on the
# installed binaries and localised the cause: `claude-fw --termlink` runs claude
# inside termlink's INNER PTY, and once an ink raw-mode TUI owns that PTY termlink
# cannot drive it. A Claude TUI running directly in a tmux pane IS drivable. So the
# driver grows a second wire.
#
# THE RISK A NEW TRANSPORT INTRODUCES, AND HOW IT IS CONTAINED. Adding a wire is
# only safe because delivery is CONFIRMED (T-3275/G-101) rather than inferred from
# an exit code. The controls below are therefore the point of the suite, not
# decoration:
#
#   POSITIVE  a pane that shows the text  -> the driver must CONFIRM.
#   NEGATIVE  a pane that accepts send-keys and shows NOTHING -> must REFUSE.
#
# The negative pane runs `stty -echo; cat >/dev/null`: it consumes every keystroke
# and displays none of them. That is the G-097 shape reproduced on the new wire, in
# a pane that is genuinely writable — so a driver that trusted `send-keys` exit
# status would call it a success, exactly as the old code called termlink a
# success. Without this leg the suite cannot distinguish "confirmation works" from
# "confirmation always passes", which is the L-653 problem this arc keeps meeting.
#
# Both legs use REAL tmux. A stubbed tmux would be a stub written against the
# driver's assumptions rather than against the tool — the failure mode that let the
# `termlink info` defect survive review (see t3254's B4 note).

setup() {
    command -v tmux >/dev/null 2>&1 || skip "tmux not installed"
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    DRIVER="$REPO/agents/context/continuous-driver.sh"
    SB="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SB/.context/working" "$SB/.tasks/active" "$SB/bin"
    touch "$SB/.framework.yaml"

    [ "$SB" != "$REPO" ]
    [ -f "$DRIVER" ]

    STATE_F="$SB/.context/working/.continuous-mode.yaml"
    DIR_F="$SB/.context/working/.next-directive.yaml"
    LEDGER="$SB/.context/working/continuous-run.jsonl"

    cat > "$SB/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$SB" FRAMEWORK_ROOT="$REPO" "$REPO/bin/fw" "\$@"
SHIM
    chmod +x "$SB/bin/fw"

    cat > "$STATE_F" <<'Y'
enabled: true
current_iteration: 0
tasks_completed: 0
Y
    # A needle with no spaces: the confirmation strips whitespace on both sides, so
    # a single token proves the match without depending on how the pane wraps.
    NEEDLE="T3277NEEDLEZULU"
    cat > "$DIR_F" <<Y
directive: "$NEEDLE"
max_iterations: 10
Y
    PANE=""
}

teardown() {
    [ -n "${PANE:-}" ] && tmux kill-session -t "$PANE" 2>/dev/null
    true
}

_run_driver() {
    run env -u FW_DRIVER_TRANSPORT FW_DRIVER_SETTLE=1 FW_DRIVER_CONFIRM_TRIES=3 \
        bash "$DRIVER" --project-root "$SB" "$@"
}

# ── the flag itself ──────────────────────────────────────────────────────────

@test "T1 an unknown transport exits 2 — it does not silently fall back to a default" {
    _run_driver --transport bogus --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown --transport"* ]]
}

@test "T2 the default is termlink — omitting the flag does not reach for tmux" {
    # Control for T1/T3: proves the transport seam did not change the no-flag path.
    # With no tmux target set, a tmux-defaulting driver would refuse naming
    # FW_DRIVER_TMUX_TARGET; the termlink path refuses for its own reasons instead.
    _run_driver --dry-run
    [[ "$output" != *"FW_DRIVER_TMUX_TARGET"* ]]
}

# ── target resolution on the tmux wire ───────────────────────────────────────

@test "T3 transport=tmux with no target refuses and names how to supply one" {
    _run_driver --transport tmux --dry-run
    grep -q '"reason": "refused"' "$LEDGER"
    grep -q 'FW_DRIVER_TMUX_TARGET' "$LEDGER"
}

@test "T4 transport=tmux with a pane that does not exist refuses and names the pane" {
    _run_driver --transport tmux --session "t3277-absent-pane:0.0" --dry-run
    grep -q "t3277-absent-pane" "$LEDGER"
    # It must NOT have wandered off to termlink's discovery ladder.
    ! grep -q 'is not registered' "$LEDGER"
}

# ── the two controls that make the wire trustworthy ──────────────────────────

@test "T5 POSITIVE CONTROL: a pane that shows the text is CONFIRMED" {
    PANE="t3277pos$$"
    tmux new-session -d -s "$PANE" -x 200 -y 50
    sleep 1

    _run_driver --transport tmux --session "${PANE}:0.0"

    grep -q '"reason": "injected"' "$LEDGER"
    grep -q 'confirmed=text-in-pane' "$LEDGER"
    # And the text genuinely reached the pane — asserted independently of the
    # driver's own ledger claim, which is the whole discipline here.
    tmux capture-pane -p -t "${PANE}:0.0" | grep -q "$NEEDLE"
}

@test "T6 NEGATIVE CONTROL: a pane that accepts input but shows nothing is REFUSED" {
    # stty -echo + cat: every keystroke is consumed, none is displayed. send-keys
    # succeeds. This is the G-097 shape on the tmux wire.
    PANE="t3277neg$$"
    tmux new-session -d -s "$PANE" -x 200 -y 50 'stty -echo; cat > /dev/null'
    sleep 1

    _run_driver --transport tmux --session "${PANE}:0.0"

    grep -q '"reason": "refused"' "$LEDGER"
    grep -q 'UNCONFIRMED' "$LEDGER"
    # The false success the old code would have written must be absent.
    ! grep -q '"reason": "injected"' "$LEDGER"
}

@test "T7 the refusal points at the tmux way of checking, not the termlink one" {
    PANE="t3277msg$$"
    tmux new-session -d -s "$PANE" -x 200 -y 50 'stty -echo; cat > /dev/null'
    sleep 1

    _run_driver --transport tmux --session "${PANE}:0.0"

    grep -q 'tmux capture-pane' "$LEDGER"
    ! grep -q 'termlink pty output' "$LEDGER"
}
