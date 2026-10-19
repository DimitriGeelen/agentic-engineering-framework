#!/usr/bin/env bash
# T-3257 — the backlog proof T-3255 designed, on a substrate that can actually run it.
#
# WHAT T-3255 GOT RIGHT, AND WHY ITS RUN COULD NEVER HAPPEN.
# T-3255's harness (tools/t3255-livefire-agent.sh) is correct in every part that
# matters: a real Claude agent reads a backlog, does ONE item, ticks it, ends its
# turn — a genuine early stop with work remaining and no budget event anywhere
# near it. That is exactly the `exit no-signal` case M2 cannot reach, reproduced
# rather than simulated. Its assertions are reproduced here almost verbatim.
#
# What it could not do is reach the agent. It spawns the session with
# `termlink spawn --shell -- bash -lc '… exec claude …'`, which nests as:
#
#     tmux pane -> termlink register -> inner PTY -> shell -> claude TUI
#
# G-097: `termlink inject` into a live ink raw-mode TUI exits 0 and delivers
# nothing. And per T-3277's measurement (tools/t3250-transport-probe.sh),
# `tmux send-keys` aimed at the OUTER pane lands on `termlink register`'s stdin
# and is likewise swallowed. So NEITHER transport reaches a termlink-wrapped
# agent, and no transport flag rescues it — the target has to not be behind the
# inner PTY at all.
#
# THE ONE CHANGE MADE HERE: the agent runs DIRECTLY in a tmux pane, and the
# driver is invoked with `--transport tmux --session <pane>`. Nothing else about
# the proof is weakened — same directive, same one-unit-per-turn early stop, same
# assertions, same negative control. The substrate moved; the claim did not.
#
# This is deliberately NOT a workaround for G-097, which stays open: a
# termlink-wrapped agent remains undrivable, and that is a real limit on where
# the continuous driver can be deployed today.
#
# Usage: tools/t3257-livefire-backlog.sh [--keep] [--model NAME]

set -uo pipefail
KEEP=0; MODEL="claude-haiku-4-5-20251001"
while [ $# -gt 0 ]; do
    case "$1" in
        --keep)  KEEP=1; shift ;;
        --model) MODEL="$2"; shift 2 ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DRIVER="$REPO/agents/context/continuous-driver.sh"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/t3257-backlog.XXXXXX")"
PROJ="$BASE/proj"
TM="t3257bk$$"
PANE="$TM:0.0"
PASS=0; FAIL=0

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { PASS=$((PASS+1)); printf '  \033[0;32mPASS\033[0m  %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[0;31mFAIL\033[0m  %s\n' "$*"; }
note() { printf '  \033[0;36m..\033[0m    %s\n' "$*"; }

squash() { printf '%s' "${1:-}" | tr -d '[:space:]'; }
pane()   { timeout 15 tmux capture-pane -p -t "$1" 2>/dev/null | tail -c 8000; }

cleanup() {
    tmux kill-session -t "$TM" >/dev/null 2>&1
    [ "$KEEP" = 1 ] || rm -rf "$BASE"
    [ "$KEEP" = 1 ] && echo "kept: $BASE  (tmux attach -t $TM)"
    return 0
}
trap cleanup EXIT

command -v tmux   >/dev/null 2>&1 || { echo "tmux not on PATH"; exit 2; }
command -v claude >/dev/null 2>&1 || { echo "claude not on PATH"; exit 2; }

# ── sandbox ──────────────────────────────────────────────────────────────────
mkdir -p "$PROJ/.context/working" "$PROJ/bin" "$PROJ/.tasks/active"
touch "$PROJ/.framework.yaml"
cat > "$PROJ/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$REPO" "$REPO/bin/fw" "\$@"
SHIM
chmod +x "$PROJ/bin/fw"

_fresh_backlog() {
    rm -f "$PROJ"/unit-*.done "$PROJ/ALL-DONE"
    cat > "$PROJ/backlog.md" <<'B'
# Backlog

- [ ] unit-1 — create a file named `unit-1.done` containing the single word DONE
- [ ] unit-2 — create a file named `unit-2.done` containing the single word DONE
- [ ] unit-3 — create a file named `unit-3.done` containing the single word DONE
B
}

# Verbatim from T-3255. The one-item-then-stop shape is the whole point: it
# manufactures an early stop with work remaining, which is the case the driver
# exists to rescue and the one a shell script cannot produce.
DIRECTIVE='Read backlog.md in the current directory. Do EXACTLY ONE unticked item (the first one), tick its checkbox in backlog.md, then STOP and end your turn. Do not do more than one item. If every item is already ticked, create a file named ALL-DONE and stop.'

_arm() {
    cat > "$PROJ/.context/working/.continuous-mode.yaml" <<Y
enabled: $1
current_iteration: 0
tasks_completed: 0
max_iterations: 20
Y
    python3 - "$PROJ/.context/working/.next-directive.yaml" "$DIRECTIVE" <<'PY'
import sys, yaml
path, directive = sys.argv[1], sys.argv[2]
yaml.safe_dump({"directive": directive, "expires_at": "2999-01-01T00:00:00Z"},
               open(path, "w"), default_flow_style=False, sort_keys=False)
PY
    : > "$PROJ/.context/working/continuous-run.jsonl"
}

units_done() { ls "$PROJ"/unit-*.done 2>/dev/null | grep -c . || true; }

# A live TUI repaints constantly while it works (spinner, token counter), so two
# identical captures a few seconds apart mean the agent is genuinely idle. Same
# principle the driver's own busy check uses — reproduced here rather than shared,
# because the harness must be able to tell "quiet" from "quiet" INDEPENDENTLY of
# the code under test.
wait_quiet() {
    local tries="${1:-40}" a b
    for _ in $(seq 1 "$tries"); do
        a="$(squash "$(pane "$PANE")")"; sleep 4
        b="$(squash "$(pane "$PANE")")"
        [ -n "$a" ] && [ "$a" = "$b" ] && return 0
    done
    return 1
}
tick() { bash "$DRIVER" --project-root "$PROJ" --transport tmux --session "$PANE" --settle 3 2>&1; }
last_reason() {
    tail -1 "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null | python3 -c 'import json,sys
try: d=json.loads(sys.stdin.read() or "{}"); print(d.get("reason",""))
except Exception: print("")' 2>/dev/null
}

# ── spawn a REAL agent, directly in a tmux pane ──────────────────────────────
say "Spawning a real Claude agent DIRECTLY in a tmux pane ($MODEL)"
_fresh_backlog
tmux new-session -d -s "$TM" -c "$PROJ" -x 200 -y 50 >/dev/null 2>&1
tmux send-keys -t "$PANE" -l "claude --permission-mode acceptEdits --model '$MODEL'" 2>/dev/null
tmux send-keys -t "$PANE" Enter 2>/dev/null

# Clear the first-run gates and wait for a settled TUI. Measured in the T-3257
# live-fire: the trust prompt reads "Yes, I trust this folder", and an MCP server
# dialog can appear after it. Neither is a failure; both block startup silently.
READY=0
for i in $(seq 1 60); do
    P="$(squash "$(pane "$PANE")")"
    case "$P" in
        *"Yes,Itrustthisfolder"*|*"Quicksafetycheck"*)
            note "first-run: trust dialog — accepting"
            tmux send-keys -t "$PANE" Enter 2>/dev/null ;;
        *"Selectanyyouwish"*|*"newMCPserversfound"*)
            note "first-run: MCP server dialog — confirming"
            tmux send-keys -t "$PANE" Enter 2>/dev/null ;;
    esac
    # READY MARKERS ARE TAKEN FROM A REAL RENDER, NOT GUESSED. The first version of
    # this loop watched for "? for shortcuts" / "Welcome to" and declared the TUI
    # dead after 60 polls while the pane was, in fact, showing a fully painted idle
    # prompt. Every assertion below would have been skipped on a working system.
    # These three come from a captured pane: the input placeholder, the permission
    # mode indicator, and the shortcut hint — any one is sufficient, and matching a
    # union rather than a single string is the point, since which chrome renders
    # varies with terminal width and claude version.
    case "$P" in
        *'Try"howdoes'*|*"accepteditson"*|*"?forshortcuts"*) READY=1; break ;;
    esac
    sleep 2
done

if [ "$READY" = 1 ]; then
    ok "a real Claude TUI is up in pane '$PANE'"
else
    bad "the TUI never painted — nothing below would measure anything"
    pane "$PANE" | tail -20
    exit 1
fi

# It must be a real claude process, not a shell that failed to start one. A dead
# claude leaves a prompt that looks perfectly idle and the run measures an empty
# room — asserted rather than assumed (T-3255's reasoning, kept).
if pgrep -f "claude --permission-mode acceptEdits" >/dev/null 2>&1; then
    ok "a real claude process is running in the sandbox"
else
    bad "no claude process — the pane is a bare shell"; exit 1
fi

# ═══ AC: the agent stops early, and the driver drives it to completion ═══════
say "Armed: driving a REAL agent that stops after every single unit"
_arm true
sleep 3

for i in $(seq 1 16); do
    before="$(units_done)"
    out="$(tick)"; r="$(last_reason)"
    printf '  tick %2d: %-9s done=%s %s\n' "$i" "$r" "$before" "${out:+| $out}"

    # PROBE THE BUSY GUARD DELIBERATELY, DO NOT WAIT FOR LUCK. The first run
    # recorded zero BUSY observations: with a 25s gap and a fast model the agent
    # had always finished by the time the driver looked, so the guard was never
    # exercised and the AC failed on a harness artifact. Ticking ~3s after a
    # confirmed injection lands squarely inside the turn, which is exactly the
    # interleave the guard exists to refuse.
    if [ "$r" = "injected" ]; then
        sleep 3
        probe="$(tick)"; pr="$(last_reason)"
        printf '      busy-probe: %-9s %s\n' "$pr" "${probe:+| $probe}"
    fi

    [ -f "$PROJ/ALL-DONE" ] && { echo "  agent signalled ALL-DONE"; break; }
    sleep 22
done

d="$(units_done)"
echo "  units complete: $d/3   ALL-DONE: $([ -f "$PROJ/ALL-DONE" ] && echo yes || echo no)"

[ "$d" -eq 3 ] && ok "all 3 units completed by a real agent, driven only by injection" \
               || bad "expected 3 units, got $d"
[ -f "$PROJ/ALL-DONE" ] && ok "agent reached its own terminal signal" \
                        || bad "no ALL-DONE — the loop did not run to completion"
[ ! -f "$PROJ/.context/working/.budget-status" ] \
    && ok "budget gauge never tripped — this is the no-signal case M2 cannot reach" \
    || bad "a budget-status file appeared; the budget path was involved"

inj="$(grep -c '"reason": "injected"' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "${inj:-0}" -ge 3 ] && ok "ledger records $inj injections" || bad "only ${inj:-0} injections recorded"

# The busy check is doing real work rather than being stubbed: a thinking agent
# must have been observed at least once, or the settle window never overlapped any
# actual work and the guard was never exercised.
busy="$(grep -c 'is BUSY' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "${busy:-0}" -ge 1 ] && ok "observed the agent BUSY $busy time(s) and refused to interleave" \
                       || bad "never observed a busy agent — the busy guard was not exercised"

# ═══ negative control ════════════════════════════════════════════════════════
# Without this the run above proves only that units got done, not that the DRIVER
# is why. Same pane, same agent, same directive on disk — only `enabled` flips.
say "Negative control: identical run, enabled: false"

# WAIT FOR THE AGENT TO GO QUIET FIRST. The first run scored 1 unit "completed
# while disarmed" and it was not a leak — the agent was still finishing the turn
# the LAST armed injection had started when the control wiped the backlog and
# re-armed it disabled. That in-flight turn then ticked a fresh unit-1, and the
# control read it as work done with the driver off. The control's claim is "no
# injection => no progress", so it can only start from a genuinely idle agent;
# anything else measures the previous phase's tail.
if wait_quiet 40; then
    note "agent is idle — the armed phase has fully drained"
else
    bad "agent never went quiet; the control would measure the armed phase's tail"
fi

_fresh_backlog
_arm false
sleep 2
for i in 1 2 3; do
    out="$(tick)"; printf '  tick %d: %s\n' "$i" "$(last_reason)"
    sleep 8
done
d="$(units_done)"
echo "  units complete: $d/3"
[ "$d" -eq 0 ] && ok "the agent did nothing while disarmed — it really was the driver" \
              || bad "$d unit(s) completed while disarmed"
inj="$(grep -c '"reason": "injected"' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "${inj:-0}" -eq 0 ] && ok "zero injections while disarmed" || bad "${inj} injection(s) while disarmed"

say "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
