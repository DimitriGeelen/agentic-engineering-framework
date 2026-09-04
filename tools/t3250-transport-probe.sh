#!/usr/bin/env bash
# T-3250 / G-097 re-measurement — can a turn be DELIVERED into a live Claude TUI?
#
# WHY THIS EXISTS. The continuous loop needs a way to hand a running agent session
# a new turn. Of the three routes, injection into a live TUI is the only one that
# gives cheap repeatable multi-hop (the Stop hook is capped at one continuation by
# the platform; a session restart costs a full budget trip per hop). G-097 measured
# that route as BROKEN on 2026-09-03: `termlink inject` returns 0 and delivers
# nothing into an ink-based raw-mode TUI, while `tmux send-keys` against the
# identical pane at the identical moment delivers correctly.
#
# That finding is two days old and was taken at a different termlink build. Before
# any rig is designed around it — or any transport leg is added to the driver
# (T-3276) — it gets re-measured here, today, against the binaries actually
# installed. Inheriting a transport verdict is exactly the decayed-reference class
# T-3274 fixed elsewhere in this repo.
#
# WHAT IT PROVES. Two probes, same session, same pane, seconds apart:
#   A  termlink inject --enter  -> does the text reach the pane?
#   B  tmux send-keys -l + Enter -> does the text reach the pane?
# Each probe reports the transport's EXIT STATUS and, independently, whether the
# text ARRIVED. The whole point is that those two can disagree; a transport that
# exits 0 having delivered nothing is the defect under test, and a rig that only
# checked the exit code would call it a pass.
#
# NEGATIVE CONTROL (built in, not optional). A probe string that is never sent is
# searched for in the same pane. It must NOT be found. Without that leg, a pane
# matcher that returns true for everything would look identical to a working
# transport — the L-653 problem.
#
# Usage:  tools/t3250-transport-probe.sh [--keep]
#         --keep   leave the session up for manual inspection
set -uo pipefail

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="t3250probe$$"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

PASS=0; FAIL=0
ok()  { printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
note(){ printf '        %s\n' "$1"; }

cleanup() {
    [ "$KEEP" = 1 ] && { echo "kept: termlink pty output $SESSION --strip-ansi"; return; }
    tmux kill-session -t "tl-$SESSION" >/dev/null 2>&1
    termlink signal "$SESSION" SIGTERM >/dev/null 2>&1
    termlink deregister "$SESSION"     >/dev/null 2>&1
    for _p in $(pgrep -f "termlink register --name $SESSION" 2>/dev/null); do
        kill -9 "$_p" >/dev/null 2>&1
    done
    termlink clean >/dev/null 2>&1
}
trap cleanup EXIT

# squash: wrap-immune matching. A TUI wraps long input across lines and can break
# a word mid-token, so any matcher that only collapses whitespace RUNS still
# misses. Removing whitespace entirely is what survives a wrap.
squash() { printf '%s' "${1:-}" | tr -d '[:space:]'; }
pane()   { timeout 15 termlink pty output "$SESSION" --strip-ansi 2>/dev/null | tail -c 8000; }

echo "=== T-3250 transport probe — can a turn be delivered into a live Claude TUI? ==="
echo "termlink: $(termlink --version 2>&1 | head -1)"
echo "tmux:     $(tmux -V 2>&1)"
echo "claude:   $(claude --version 2>&1 | head -1)"
echo "session:  $SESSION"
echo

# --- spawn a shell session, then start a REAL claude TUI inside it -------------
if ! timeout 90 termlink spawn --name "$SESSION" --tags "task:T-3250,transport-probe" --shell --wait >/dev/null 2>&1; then
    bad "could not spawn termlink session — cannot probe"; exit 1
fi
ok "termlink session spawned (--shell, tmux-backed)"

tmux send-keys -t "tl-$SESSION" -l "cd $PROJ && claude" 2>/dev/null
tmux send-keys -t "tl-$SESSION" Enter 2>/dev/null

# Wait for the TUI to actually paint. A probe fired at a shell prompt, or at a
# half-drawn frame, measures the rig's patience rather than the transport.
READY=0
for _i in $(seq 1 40); do
    p="$(pane)"
    case "$(squash "$p")" in
        *"?forshortcuts"*|*"Welcometo"*|*"bypasspermissions"*|*"Doyoutrust"*) READY=1; break ;;
    esac
    sleep 2
done
if [ "$READY" != 1 ]; then
    bad "Claude TUI never painted a recognisable frame in 80s — probe is inconclusive, not negative"
    note "last pane bytes:"; pane | tail -5
    exit 1
fi
ok "Claude TUI is up and painting in the pane"
case "$(squash "$(pane)")" in
    *"Doyoutrust"*) note "NOTE: sitting at the trust dialog — same point G-097 measured" ;;
esac

# --- Probe A: termlink inject -------------------------------------------------
A="PROBEALPHA$$ZULU"
timeout 30 termlink inject "$SESSION" --enter "$A" >/dev/null 2>&1
A_RC=$?
sleep 4
A_LANDED=0
case "$(squash "$(pane)")" in *"$(squash "$A")"*) A_LANDED=1 ;; esac

echo
echo "--- Probe A: termlink inject --enter"
note "exit status : $A_RC"
note "text arrived: $([ "$A_LANDED" = 1 ] && echo YES || echo NO)"
if [ "$A_RC" -eq 0 ] && [ "$A_LANDED" != 1 ]; then
    bad "G-097 REPRODUCED: transport exited 0 and delivered NOTHING"
    note "this is the false green the driver used to record as \"injected\""
elif [ "$A_LANDED" = 1 ]; then
    ok "termlink inject DELIVERED — G-097 does not reproduce on this build"
else
    ok "termlink inject failed loudly (exit $A_RC) — wrong, but not silent"
fi

# --- Probe B: tmux send-keys, same pane, seconds later ------------------------
B="PROBEBRAVO$$YANKEE"
tmux send-keys -t "tl-$SESSION" -l "$B" 2>/dev/null; B_RC1=$?
tmux send-keys -t "tl-$SESSION" Enter 2>/dev/null;   B_RC2=$?
sleep 4
B_LANDED=0
case "$(squash "$(pane)")" in *"$(squash "$B")"*) B_LANDED=1 ;; esac

echo
echo "--- Probe B: tmux send-keys -l + Enter (identical pane)"
note "exit status : $B_RC1/$B_RC2"
note "text arrived: $([ "$B_LANDED" = 1 ] && echo YES || echo NO)"
[ "$B_LANDED" = 1 ] \
    && ok "tmux send-keys DELIVERED into the same pane" \
    || bad "tmux send-keys did NOT deliver either"

# --- Negative control: a string nobody sent must not be found -----------------
echo
echo "--- Negative control (L-653: a matcher that always says yes proves nothing)"
NEVER="PROBENEVERSENT$$XRAY"
N_FOUND=0
case "$(squash "$(pane)")" in *"$(squash "$NEVER")"*) N_FOUND=1 ;; esac
[ "$N_FOUND" = 0 ] \
    && ok "a never-sent probe is correctly NOT found — the matcher discriminates" \
    || bad "matcher found a string that was never sent — every result above is void"

# --- Verdict ------------------------------------------------------------------
echo
echo "=== ATTRIBUTION (L-654) ==="
if [ "$A_LANDED" != 1 ] && [ "$B_LANDED" = 1 ]; then
    echo "  VERDICT: G-097 STANDS. termlink cannot deliver into this TUI; tmux can,"
    echo "           against the same pane seconds apart. The defect is the transport,"
    echo "           NOT the pane, NOT the matcher (negative control passed), and NOT"
    echo "           the TUI's ability to receive input."
elif [ "$A_LANDED" = 1 ]; then
    echo "  VERDICT: G-097 DOES NOT REPRODUCE at termlink $(termlink --version 2>&1 | head -1)."
    echo "           The injection route is open; re-open the multi-hop rig design."
else
    echo "  VERDICT: INCONCLUSIVE — neither transport delivered. Do not read this as"
    echo "           a termlink finding; the pane or the TUI state is the suspect."
fi
echo
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
