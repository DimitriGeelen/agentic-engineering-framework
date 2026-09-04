#!/usr/bin/env bats
# T-3275 (G-101, arc-012) — the driver must CONFIRM delivery, not infer it.
#
# WHAT IS UNDER TEST. `continuous-driver.sh` used to write `_log "injected"` on a
# zero exit status from `termlink inject`, with nothing observing the target in
# between. G-097 is the live proof that this is wrong: inject returns 0 and
# delivers nothing into an ink-based raw-mode TUI. So the driver reported success
# every tick while the agent received no turn.
#
# THE SUITE IS A CONTROL PAIR, NOT A SUCCESS DEMO. Every fixture below differs
# from its sibling in exactly ONE variable: whether the pane reflects the
# injection. A suite that only proved "confirmed delivery is allowed" could not
# distinguish a working guard from one that always passes, and a suite that only
# proved "silent delivery is refused" could not distinguish a working guard from
# one that always refuses. Both legs are required for either to mean anything.
#
# WHAT THE STUB MODELS AND WHAT IT DOES NOT. The transport is stubbed, so these
# tests model delivery rather than perform it — they cannot prove termlink itself
# works, which is G-097's job and is homed upstream. What they DO prove is the
# thing this task owns: given a transport that exits 0, the driver's verdict
# tracks whether the text arrived, not whether the call returned.
#
# THE THIRD LEG IS THE POINT. `C3` is a pane that CHANGES after injection without
# ever containing the directive — a spinner, a clock, a progress line. A guard
# built on "did the pane change" passes C1 and C2 and still fails C3, which is
# why change-detection was rejected in favour of keying on the text itself.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    FW="$REPO/bin/fw"
    DRIVER="$REPO/agents/context/continuous-driver.sh"
    SB="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SB/.context/working" "$SB/.tasks/active" "$SB/bin" "$SB/stub"
    touch "$SB/.framework.yaml"

    # Fixture assertions, not spot-checks (T-3254 convention): a sandbox that is
    # silently the real repo would make every verdict below meaningless.
    [ "$SB" != "$REPO" ]
    [ -f "$SB/.framework.yaml" ]
    [ -x "$FW" ]
    [ -f "$DRIVER" ]

    STATE_F="$SB/.context/working/.continuous-mode.yaml"
    DIR_F="$SB/.context/working/.next-directive.yaml"
    LEDGER="$SB/.context/working/continuous-run.jsonl"

    cat > "$SB/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$SB" FRAMEWORK_ROOT="$REPO" "$REPO/bin/fw" "\$@"
SHIM
    chmod +x "$SB/bin/fw"

    echo "sandbox-session" > "$SB/sessions"

    cat > "$STATE_F" <<'Y'
enabled: true
current_iteration: 0
tasks_completed: 0
Y
    _directive "Continue the backlog work."
}

_directive() {
    printf 'directive: %s\n' "$1" > "$DIR_F"
}

# A termlink stub whose ONLY meaningful axis is whether `pty output` reflects what
# was injected. Escaping follows T-3254's hard-won note: the heredoc is unquoted
# so $SB and $mode interpolate, therefore every variable the STUB itself uses is
# written \$-escaped.
_stub_termlink() {
    local mode="$1"
    : > "$SB/pane"
    : > "$SB/tick"
    cat > "$SB/stub/termlink" <<STUB
#!/usr/bin/env bash
verb="\$1"; shift
case "\$verb" in
  info) exit 0 ;;
  discover)
    want=""; tag=""
    while [ \$# -gt 0 ]; do
        case "\$1" in
            --name) want="\$2"; shift 2 ;;
            --tag)  tag="\$2";  shift 2 ;;
            *) shift ;;
        esac
    done
    [ -n "\$tag" ] && exit 0
    [ -f "$SB/sessions" ] && grep -F -- "\$want" "$SB/sessions"
    exit 0 ;;
  pty)
    sub="\$1"; shift
    if [ "\$sub" = "output" ]; then
        n=\$(cat "$SB/tick" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "$SB/tick"
        echo "idle prompt >"
        # The two pre-inject samples (busy detection) must be IDENTICAL or the
        # driver refuses as BUSY and never reaches the confirmation under test.
        if [ "$mode" = redraw ] && [ "\$n" -gt 2 ]; then
            echo "working... \$n"
        fi
        cat "$SB/pane" 2>/dev/null
        exit 0
    fi
    if [ "\$sub" = "inject" ]; then
        echo "\$*" >> "$SB/injected"
        [ "$mode" = echoing ] && printf '%s\n' "\$*" >> "$SB/pane"
        [ "$mode" = wrapped ] && printf 'Continue the backl\nog work.\n' >> "$SB/pane"
        exit 0
    fi
    exit 0 ;;
  inject)
    echo "\$*" >> "$SB/injected"
    [ "$mode" = echoing ] && printf '%s\n' "\$*" >> "$SB/pane"
    [ "$mode" = wrapped ] && printf 'Continue the backl\nog work.\n' >> "$SB/pane"
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
    chmod +x "$SB/stub/termlink"
}

_run_driver() {
    PATH="$SB/stub:$PATH" PROJECT_ROOT="$SB" \
        bash "$DRIVER" --project-root "$SB" --session sandbox-session --settle 1 "$@"
}

# The ledger is the artefact that lied before this task. Assert on IT, not on
# stdout prose — a message can be right while the record is wrong, and the record
# is what a reader reconstructs the run from.
_ledger_says() {
    local needle="$1"
    [ -f "$LEDGER" ] || { echo "no ledger written at all"; return 1; }
    grep -q "$needle" "$LEDGER"
}

@test "C1 NEGATIVE CONTROL: a transport that exits 0 but delivers nothing is refused" {
    # The G-097 shape exactly: inject succeeds, the pane never shows the text.
    _stub_termlink silent
    run _run_driver
    [ -f "$SB/injected" ] || { echo "fixture broken — inject was never called"; return 1; }
    _ledger_says '"reason": "refused"' \
        || { echo "expected a refusal in the ledger; got:"; cat "$LEDGER" 2>/dev/null; return 1; }
    ! _ledger_says '"reason": "injected"' \
        || { echo "FALSE GREEN — ledger claims injected on an undelivered turn:"; cat "$LEDGER"; return 1; }
}

@test "C2 POSITIVE CONTROL: a transport whose text reaches the pane is confirmed" {
    # Without this leg C1 passes for any reason at all — including a guard that
    # refuses unconditionally, which would disable the loop entirely.
    _stub_termlink echoing
    run _run_driver
    [ -f "$SB/injected" ] || { echo "fixture broken — inject was never called"; return 1; }
    _ledger_says '"reason": "injected"' \
        || { echo "confirmed delivery was NOT accepted — the guard refuses everything:"; cat "$LEDGER" 2>/dev/null; echo "--- output ---"; echo "$output"; return 1; }
    _ledger_says 'confirmed=text-in-pane'
}

@test "C3 a pane that CHANGES but never shows the directive is refused" {
    # This is why the guard keys on the text and not on "did the pane change".
    # A spinner/clock/progress line redraws on its own; change-detection alone
    # would read this undelivered tick as a success.
    _stub_termlink redraw
    run _run_driver
    [ -f "$SB/injected" ] || { echo "fixture broken — inject was never called"; return 1; }
    _ledger_says '"reason": "refused"' \
        || { echo "a self-redrawing pane was read as delivery:"; cat "$LEDGER" 2>/dev/null; return 1; }
    ! _ledger_says '"reason": "injected"'
}

@test "C4 the refusal names the shape, the manual check, and the bypass" {
    # An agent that trips this at 03:00 has only the ledger. If it does not say
    # what happened and what to do, the guard has traded a silent lie for a
    # silent stall.
    _stub_termlink silent
    run _run_driver
    _ledger_says 'UNCONFIRMED'
    _ledger_says 'G-097'
    _ledger_says 'termlink pty output'
    _ledger_says 'FW_DRIVER_SKIP_DELIVERY_CONFIRM=1'
}

@test "C5 the bypass restores the old behaviour AND says so in the ledger" {
    # A bypass that is indistinguishable from a genuine confirmation would
    # reintroduce the false green through the escape hatch.
    _stub_termlink silent
    FW_DRIVER_SKIP_DELIVERY_CONFIRM=1 run _run_driver
    _ledger_says '"reason": "injected"' \
        || { echo "bypass did not restore injection:"; cat "$LEDGER" 2>/dev/null; return 1; }
    _ledger_says 'confirmed=SKIPPED-BY-ENV' \
        || { echo "bypassed run is indistinguishable from a confirmed one"; cat "$LEDGER"; return 1; }
}

@test "C6 a directive wrapped mid-word across pane lines still confirms" {
    # A TUI wraps long input. A wrap inserted mid-word ("backl\nog") defeats a
    # matcher that only collapses whitespace runs, producing a false refusal on a
    # turn that genuinely landed. Both sides are stripped of whitespace entirely.
    _stub_termlink wrapped
    run _run_driver
    _ledger_says '"reason": "injected"' \
        || { echo "wrapped-but-delivered text was refused:"; cat "$LEDGER" 2>/dev/null; return 1; }
}
