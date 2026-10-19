#!/usr/bin/env bash
# T-3254 (arc-012) AC5 + AC6 — live-fire and its negative control.
#
# WHAT IS BEING PROVEN. The loop's failure mode is `exit no-signal`: the agent stops
# before the budget gauge trips, backlog remaining, and nothing restarts it. M2 cannot
# reach that case because it triggers on budget-critical. This drives a session that
# has stopped early, to completion, using the cron path alone — with the budget gauge
# never consulted, let alone tripped.
#
# WHY THE NEGATIVE CONTROL IS NOT OPTIONAL. Without it, "the driver continued the
# work" and "the work finished on its own" produce identical evidence. That
# indistinguishability is what made the E9 ceiling result meaningless, and it is the
# single most repeated failure in this arc. So the identical run is repeated with
# `enabled: false`, and the backlog must be untouched at the end.
#
# THE BOUNDARY, STATED RATHER THAN IMPLIED. The session here is a real TermLink
# PTY session receiving real injections from the real driver — the transport,
# the bounds, the busy check, the ledger and the terminal signal are all exercised
# end to end. What it is NOT is a Claude session reasoning about a directive: the
# "work" is a shell script that consumes one backlog item per turn. So this proves
# the DRIVE mechanism, not the agent's comprehension of what it was handed. Read
# it as covering everything up to the moment the prompt lands in the session.
#
# Usage: tools/t3254-livefire.sh [--keep]

set -uo pipefail
KEEP=0; [ "${1:-}" = "--keep" ] && KEEP=1

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER="$REPO/agents/context/continuous-driver.sh"
BASE="$(mktemp -d /tmp/t3254-livefire.XXXXXX)"
PROJ="$BASE/proj"
SESSION="t3254-livefire-$$"
PASS=0; FAIL=0

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { PASS=$((PASS+1)); printf '  \033[0;32mPASS\033[0m  %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[0;31mFAIL\033[0m  %s\n' "$*"; }

# CLEANUP TAKES THREE KILLS, AND THE OBVIOUS TWO ARE NOT ENOUGH.
#
# `spawn` uses a tmux backend and registration is held by a separate long-lived
# `termlink register --name <session>` process. So:
#   - `tmux kill-session` ends the shell but leaves the register holder alive, and
#     the session keeps appearing in `termlink list` as `ready` with a live PID;
#   - `termlink clean` removes only STALE registrations, and correctly reports
#     "No stale sessions found" while that holder is running — it is not stale,
#     it is alive and pointing at a tmux session that no longer exists;
#   - `termlink deregister` DOES NOT EXIST as a CLI subcommand (it exists only as
#     an MCP tool). Calling it is a silent no-op under 2>/dev/null, which is how
#     the first version of this trap appeared to work while cleaning nothing.
#
# Measured: ten orphans accumulated across the debugging runs of this very script.
# Note this is the same "ready means REGISTERED, not IDLE" fact the driver's busy
# check is built around — here it shows up as sessions reporting ready with their
# terminal already gone.
cleanup() {
    timeout 15 termlink signal "$SESSION" SIGTERM >/dev/null 2>&1
    tmux kill-session -t "tl-$SESSION" >/dev/null 2>&1
    # The registration holder, matched on its own command line. NOT via
    # `termlink list`: that table TRUNCATES display names ("t3254-livefire…"), so a
    # name match against its output silently finds nothing and the holder survives —
    # which is how this trap still leaked one session after the first fix.
    #
    # pgrep-then-kill rather than `pkill -f`, and self is skipped explicitly: a
    # -f pattern matches ANY process whose command line contains it, including the
    # shell that is running the pkill. Measured the hard way — a bare
    # `pkill -f "termlink register --name t3254"` typed at a prompt killed its own
    # shell (exit 144, no output), because the pattern was sitting in its argv.
    local _p
    for _p in $(pgrep -f "termlink register --name $SESSION" 2>/dev/null); do
        [ "$_p" = "$$" ] && continue
        kill "$_p" >/dev/null 2>&1
    done
    timeout 15 termlink clean >/dev/null 2>&1
    [ "$KEEP" = 1 ] || rm -rf "$BASE"
}
trap cleanup EXIT

# ── the sandbox project ──────────────────────────────────────────────────────
mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/bin"
touch "$PROJ/.framework.yaml"

cat > "$PROJ/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$REPO" "$REPO/bin/fw" "\$@"
SHIM
chmod +x "$PROJ/bin/fw"

# The backlog. Three units of work the session has NOT done and will not do on its
# own — it is sitting at a prompt.
printf 'unit-1\nunit-2\nunit-3\n' > "$PROJ/backlog"
: > "$PROJ/done"

# The "work". One unit per injected turn, then back to the prompt — i.e. it stops
# early again, every time, which is exactly the condition under test. When the
# backlog empties it sends the TERMINAL SIGNAL rather than just going quiet, so
# silence stops meaning two different things (the arc's recurring confusion).
cat > "$PROJ/consume.sh" <<CONSUME
#!/usr/bin/env bash
cd "$PROJ" || exit 0
unit="\$(head -1 backlog 2>/dev/null)"
if [ -z "\$unit" ]; then
    "$PROJ/bin/fw" continuous disarm --reason "work complete — backlog empty" >/dev/null 2>&1
    echo "T3254-LIVEFIRE: backlog empty, disarmed"
    exit 0
fi
sed -i '1d' backlog
echo "\$unit" >> done
echo "T3254-LIVEFIRE: consumed \$unit"
CONSUME
chmod +x "$PROJ/consume.sh"

fwp() { "$PROJ/bin/fw" "$@"; }

arm_state() {
    cat > "$PROJ/.context/working/.continuous-mode.yaml" <<Y
enabled: $1
current_iteration: 0
tasks_completed: 0
max_iterations: 10
Y
    cat > "$PROJ/.context/working/.next-directive.yaml" <<Y
directive: bash $PROJ/consume.sh
expires_at: 2999-01-01T00:00:00Z
Y
    : > "$PROJ/.context/working/continuous-run.jsonl"
}

# ── the session ──────────────────────────────────────────────────────────────
say "Spawning a real TermLink session (not a stub)"
# --wait is required: spawn returns as soon as the LAUNCHER starts, and the
# `termlink register` that actually registers the session runs inside the spawned
# shell. Without it the check below races and reports "did not register" for a
# session that was about to exist.
# --shell is REQUIRED, not cosmetic: without it the session registers but has no
# PTY, `pty output` errors, and `inject` reports "resolved but never reached a
# terminal". A non-PTY session is registered and useless — which is exactly the
# false-quiet the driver now refuses (test B5).
timeout 60 termlink spawn --name "$SESSION" --tags "task:T-3254,livefire" --shell --wait -- bash --norc -i >/dev/null 2>&1
sleep 3
# Registered is checked the way the DRIVER checks it, not some other way — a
# harness that resolves registration differently from the code under test is worse
# than none (and `termlink info <name>` is the check that does not exist).
if timeout 20 termlink discover --name "$SESSION" --names --no-header 2>/dev/null | grep -Fxq "$SESSION"; then
    ok "session '$SESSION' is registered"
else
    bad "session did not register — cannot run live-fire"; exit 1
fi

# The driver resolves its target the way CRON does: from config, not from a flag.
fwp config set CONTINUOUS_SESSION "$SESSION" >/dev/null 2>&1
[ "$(fwp config get CONTINUOUS_SESSION 2>/dev/null | tr -d '[:space:]')" = "$SESSION" ] \
    && ok "CONTINUOUS_SESSION resolves from project config (the cron path)" \
    || bad "CONTINUOUS_SESSION did not persist — driver would refuse for the wrong reason"

# One tick, invoked exactly as the installed cron line invokes it: --project-root
# only. No --session, no flags the deployed command does not carry.
tick() { flock -n "$BASE/tick.lock" -c "bash '$DRIVER' --project-root '$PROJ' --settle 1" 2>&1; }

# ═══ AC5 — live-fire ═════════════════════════════════════════════════════════
say "AC5 — armed: the cron path alone must drive a stopped session to completion"
arm_state true
sleep 2

for i in 1 2 3 4; do
    out="$(tick)"
    why="$(tail -1 "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null \
           | python3 -c 'import json,sys
try:
    d=json.loads(sys.stdin.read() or "{}"); print(d.get("reason",""), "-", d.get("detail",""))
except Exception: print("")' 2>/dev/null)"
    printf '  tick %d: %s\n     ledger: %s\n' "$i" "${out:-<no stdout>}" "${why:-<none>}"
    sleep 3
done

done_n="$(grep -c . "$PROJ/done" 2>/dev/null; true)"
back_n="$(grep -c . "$PROJ/backlog" 2>/dev/null; true)"
echo "  done=$done_n backlog=$back_n"

[ "$done_n" -eq 3 ] && ok "all 3 backlog units completed by injection alone" \
                    || bad "expected 3 completed units, got $done_n"
[ "$back_n" -eq 0 ] && ok "backlog is empty" || bad "backlog still holds $back_n unit(s)"

# The budget gauge must never have been consulted. If it had fired, this would be
# M2's win, not this driver's, and the AC would be measuring the wrong mechanism.
if [ -f "$PROJ/.context/working/.budget-status" ]; then
    bad "a budget-status file appeared — the budget gauge was involved"
else
    ok "budget gauge never tripped (no .budget-status written in the sandbox)"
fi

# The terminal signal, not silence, is what stopped it.
if grep -q "work complete" "$PROJ/.context/working/.continuous-mode.yaml" 2>/dev/null; then
    ok "loop ended on an EXPLICIT terminal signal, not on silence"
else
    bad "loop did not record a terminal signal"
fi

inj="$(grep -c '"reason": "injected"' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "$inj" -ge 3 ] && ok "ledger records $inj injections — reconstructable without re-running" \
                 || bad "ledger records only $inj injections"

# ═══ AC6 — the negative control ══════════════════════════════════════════════
say "AC6 — negative control: the IDENTICAL run with enabled: false must stay stopped"
printf 'unit-1\nunit-2\nunit-3\n' > "$PROJ/backlog"
: > "$PROJ/done"
arm_state false
sleep 2

for i in 1 2 3 4; do
    out="$(tick)"; printf '  tick %d: %s\n' "$i" "${out:-<silent>}"
    sleep 2
done

done_n="$(grep -c . "$PROJ/done" 2>/dev/null; true)"
back_n="$(grep -c . "$PROJ/backlog" 2>/dev/null; true)"
echo "  done=$done_n backlog=$back_n"

[ "$done_n" -eq 0 ] && ok "nothing was completed while disarmed" \
                    || bad "$done_n unit(s) completed while disarmed — the bounds did not hold"
[ "$back_n" -eq 3 ] && ok "backlog untouched (3 units still pending)" \
                    || bad "backlog changed while disarmed: $back_n remaining"

inj="$(grep -c '"reason": "injected"' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "$inj" -eq 0 ] && ok "zero injections recorded while disarmed" || bad "$inj injection(s) while disarmed"

ref="$(grep -c '"reason": "refused"' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "$ref" -ge 4 ] && ok "all $ref refusals recorded with their reason" || bad "only $ref refusals recorded"

say "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
