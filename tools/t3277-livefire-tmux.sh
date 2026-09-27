#!/usr/bin/env bash
# T-3277 / arc-012 — LIVE FIRE: the real driver, a real Claude TUI, multi-hop,
# and a brake that actually stops it.
#
# WHAT THIS IS FOR. Every prior arc-012 artefact proves one half. E1/t3254 prove
# the driver DECIDES correctly (11 brakes, 21 refusals, each with a control).
# T-3250's probe proves a turn can be DELIVERED to a live Claude TUI over tmux.
# Neither joins the two, so "the loop works" has never been observed end to end
# with the brakes in the same run. This joins them.
#
# HOW A HOP IS PROVEN — and why an echo cannot fake it. The pane shows the
# directive as soon as it is typed, so "the needle appeared" proves DELIVERY and
# nothing more. To prove the AGENT actually took a turn, each hop asks for an
# arithmetic result whose ANSWER does not appear anywhere in the prompt:
#
#     directive : "Reply with only the result of 6*7 ..."   (contains 6*7)
#     proof     : the pane contains 42                       (contains neither)
#
# A pane that merely echoed the keystrokes cannot produce 42. This is the same
# discipline as the delivery confirmation one level up: do not accept the
# transport's word, and do not accept the pane's echo either.
#
# NEGATIVE CONTROLS, because a rig that cannot fail proves nothing (L-653):
#   1. an answer NEVER asked for must not be found in the pane
#   2. when the brake trips, the driver must inject NOTHING — asserted by the
#      answer for that hop being absent, not merely by the refusal message
#
# ATTRIBUTION, because a stop can happen for two opposite reasons (L-654): the
# brake firing, or the rig simply running out of hops. The brake leg therefore
# runs an extra hop AFTER raising the cap, and prints an ATTRIBUTION verdict that
# is only satisfiable if the stop tracked the cap rather than the schedule.
#
# Usage:  tools/t3277-livefire-tmux.sh <tmux-pane>        e.g. t3250direct:0.0
set -uo pipefail

PANE="${1:-}"
[ -n "$PANE" ] || { echo "usage: $0 <tmux-pane>   (e.g. t3250direct:0.0)"; exit 2; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER="$REPO/agents/context/continuous-driver.sh"
SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/.context/working" "$SB/.tasks/active" "$SB/bin"
touch "$SB/.framework.yaml"
STATE_F="$SB/.context/working/.continuous-mode.yaml"
DIR_F="$SB/.context/working/.next-directive.yaml"
LEDGER="$SB/.context/working/continuous-run.jsonl"
ARC_F="$SB/.context/working/arc-focus.yaml"

cat > "$SB/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$SB" FRAMEWORK_ROOT="$REPO" "$REPO/bin/fw" "\$@"
SHIM
chmod +x "$SB/bin/fw"

# Arc focus travels with the run — the arc this loop belongs to, carried in the
# sandbox exactly as the real project carries it.
cat > "$ARC_F" <<'Y'
current_arc: continuous-run
focused_at: 2026-09-05T00:00:00Z
Y

PASS=0; FAIL=0
ok()  { printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
note(){ printf '        %s\n' "$1"; }

pane_text() { tmux capture-pane -p -t "$PANE" -S -400 2>/dev/null; }

arm() {  # arm <tasks_completed> <max_tasks>
    cat > "$STATE_F" <<Y
enabled: true
current_iteration: 0
tasks_completed: $1
max_tasks: $2
Y
}
directive() {  # directive <a> <b>
    cat > "$DIR_F" <<Y
directive: "Reply with only the result of $1*$2 as a bare number, nothing else. Do not use tools. Do not explain."
max_iterations: 50
Y
}

wait_quiet() {  # the driver refuses a BUSY pane by design; let the agent settle
    local a b
    for _ in $(seq 1 45); do
        a="$(pane_text)"; sleep 2; b="$(pane_text)"
        [ "$a" = "$b" ] && return 0
    done
    return 1
}

hop() {  # hop <label> <a> <b> <expected> <want_inject:yes|no>
    local label="$1" a="$2" b="$3" want="$4" expect_inject="$5"
    directive "$a" "$b"
    wait_quiet || { note "pane never settled before $label"; }
    local before; before="$(pane_text)"

    env -u FW_DRIVER_TRANSPORT FW_DRIVER_SETTLE=2 FW_DRIVER_CONFIRM_TRIES=6 \
        bash "$DRIVER" --project-root "$SB" --transport tmux --session "$PANE" >/dev/null 2>&1

    if [ "$expect_inject" = "no" ]; then
        sleep 6
        if pane_text | grep -qE "(^|[^0-9])${want}([^0-9]|$)"; then
            bad "$label: the answer $want appeared although the brake should have stopped the hop"
        else
            ok "$label: nothing was injected — answer $want absent from the pane"
        fi
        return
    fi

    # Wait for the AGENT's answer, not for the echo.
    local found=0
    for _ in $(seq 1 45); do
        if pane_text | grep -qE "(^|[^0-9])${want}([^0-9]|$)"; then found=1; break; fi
        sleep 2
    done
    [ "$found" = 1 ] \
        && ok "$label: agent answered $want — a real turn, not an echo ($a*$b is in the prompt, $want is not)" \
        || bad "$label: no answer $want in the pane within 90s"
    [ "$before" = "$(pane_text)" ] && note "WARNING: pane never changed — suspect"
}

echo "=== T-3277 LIVE FIRE — real driver, real Claude TUI, real brakes ==="
echo "pane:     $PANE"
echo "driver:   $DRIVER"
echo "sandbox:  $SB"
echo "arc:      $(grep current_arc "$ARC_F" | cut -d: -f2- | tr -d ' ')"
echo

tmux list-panes -t "$PANE" >/dev/null 2>&1 || { bad "pane '$PANE' does not exist"; exit 1; }
[ "$(tmux display-message -p -t "$PANE" '#{pane_current_command}' 2>/dev/null)" = "claude" ] \
    && ok "target pane is running a real Claude TUI" \
    || bad "target pane is NOT running claude — this would not be a live-fire"

echo
echo "--- HOPS 1-2: unattended multi-hop under the cap (max_tasks 5) ---"
arm 0 5; hop "hop 1" 6 7 42 yes
arm 1 5; hop "hop 2" 8 9 72 yes

echo
echo "--- THE BRAKE: tasks_completed reaches max_tasks ---"
arm 5 5; hop "brake" 11 12 132 no
if grep -q 'max_tasks-reached' "$LEDGER" 2>/dev/null; then
    ok "the ledger names the brake that fired: max_tasks-reached"
else
    note "ledger reasons seen: $(grep -o '"reason": "[^"]*"' "$LEDGER" 2>/dev/null | tail -3 | tr '\n' ' ')"
    bad "the ledger does not name max_tasks as the reason"
fi

echo
echo "--- NEGATIVE CONTROL for the brake (L-654 attribution) ---"
echo "    Same hop, same schedule, ONLY the cap raised. If it now proceeds, the"
echo "    stop above tracked the CAP and not the rig running out of hops."
arm 5 99; hop "control" 11 12 132 yes

echo
echo "--- NEGATIVE CONTROL for the matcher (L-653) ---"
NEVER=9801
if pane_text | grep -qE "(^|[^0-9])${NEVER}([^0-9]|$)"; then
    bad "an answer never asked for ($NEVER) is present — every result above is void"
else
    ok "an answer never asked for ($NEVER) is absent — the matcher discriminates"
fi

echo
echo "=== ATTRIBUTION ==="
echo "  multi-hop  : hops 1 and 2 each produced an agent answer absent from its own prompt"
echo "  the stop   : with the cap reached, the hop delivered nothing (answer absent)"
echo "  attribution: the SAME hop delivered once the cap was raised, so the stop"
echo "               tracked the brake, not exhaustion of the schedule"
echo "  arc focus  : carried in .context/working/arc-focus.yaml for the whole run"
echo
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
