#!/usr/bin/env bash
# T-3255 — live-fire with a REAL Claude agent (the AC5 claim T-3254 did not prove).
#
# WHAT T-3254 ACTUALLY PROVED, AND WHY IT WAS NOT ENOUGH. Its live-fire drove a real
# TermLink PTY session through the real driver, but the "work" was a shell script
# that consumed one backlog line per turn. That covers the transport and every
# bound; it does NOT cover the claim the AC makes, which is that an AGENT that has
# stopped early gets driven to completion. A shell script does not stop early — it
# has no notion of a turn — so the single most important property was assumed.
#
# Here the session IS a Claude agent. It reads a backlog, does ONE item, ticks it,
# and ends its turn — which is a genuine early stop with work remaining and no
# budget event anywhere near it. That is precisely the `exit no-signal` case M2
# cannot reach, reproduced rather than simulated.
#
# The busy check earns its keep here too: while the agent is thinking, the driver
# refuses; when the agent falls quiet, it injects. Both appear in the ledger.
#
# Usage: tools/t3255-livefire-agent.sh [--keep] [--model NAME]

set -uo pipefail
KEEP=0; MODEL="claude-haiku-4-5-20251001"
while [ $# -gt 0 ]; do
    case "$1" in
        --keep)  KEEP=1; shift ;;
        --model) MODEL="$2"; shift 2 ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER="$REPO/agents/context/continuous-driver.sh"
BASE="$(mktemp -d /tmp/t3255-agent.XXXXXX)"
PROJ="$BASE/proj"
SESSION="t3255-agent-$$"
PASS=0; FAIL=0

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()  { PASS=$((PASS+1)); printf '  \033[0;32mPASS\033[0m  %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[0;31mFAIL\033[0m  %s\n' "$*"; }

# Three kills, for the reasons documented in tools/t3254-livefire.sh: tmux backend,
# a separate registration holder, and `termlink deregister` not existing as a CLI
# verb. pgrep-then-kill with self skipped, because a bare `pkill -f` on this pattern
# kills the shell running it.
cleanup() {
    timeout 15 termlink signal "$SESSION" SIGTERM >/dev/null 2>&1
    tmux kill-session -t "tl-$SESSION" >/dev/null 2>&1
    local _p
    for _p in $(pgrep -f "termlink register --name $SESSION" 2>/dev/null); do
        [ "$_p" = "$$" ] && continue
        kill "$_p" >/dev/null 2>&1
    done
    timeout 15 termlink clean >/dev/null 2>&1
    [ "$KEEP" = 1 ] || rm -rf "$BASE"
}
trap cleanup EXIT

mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/bin"
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
tick() { bash "$DRIVER" --project-root "$PROJ" --session "$SESSION" --settle 3 2>&1; }
last_reason() {
    tail -1 "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null | python3 -c 'import json,sys
try: d=json.loads(sys.stdin.read() or "{}"); print(d.get("reason",""))
except Exception: print("")' 2>/dev/null
}

# ── spawn a REAL agent ───────────────────────────────────────────────────────
say "Spawning a real Claude agent in a sandbox ($MODEL)"
_fresh_backlog
timeout 90 termlink spawn --name "$SESSION" --tags "task:T-3255,livefire-agent" --shell --wait \
    -- bash -lc "cd '$PROJ' && exec claude --permission-mode acceptEdits --model '$MODEL'" >/dev/null 2>&1
sleep 12

if timeout 20 termlink discover --name "$SESSION" --names --no-header 2>/dev/null | grep -Fxq "$SESSION"; then
    ok "agent session registered"
else
    bad "agent session did not register"; exit 1
fi

# It must be a real claude process, not a shell that failed to start one. Asserted
# rather than assumed: a dead claude leaves a bash prompt that looks perfectly idle,
# and the whole run would then measure an empty room.
if pgrep -f "claude --permission-mode acceptEdits" >/dev/null 2>&1; then
    ok "a real claude process is running in the sandbox"
else
    bad "no claude process — the session is a bare shell, the run would measure nothing"; exit 1
fi

# ═══ AC: the agent stops early, and the driver drives it to completion ═══════
say "Armed: driving a REAL agent that stops after every single unit"
_arm true
sleep 2

for i in $(seq 1 14); do
    before="$(units_done)"
    out="$(tick)"; r="$(last_reason)"
    printf '  tick %2d: %-9s done=%s %s\n' "$i" "$r" "$before" "${out:+| $out}"
    [ -f "$PROJ/ALL-DONE" ] && { echo "  agent signalled ALL-DONE"; break; }
    sleep 25
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

# The busy check is doing real work here rather than being stubbed: a thinking agent
# must have been observed at least once, or the settle window never overlapped any
# actual work and the guard was never exercised.
busy="$(grep -c 'is BUSY' "$PROJ/.context/working/continuous-run.jsonl" 2>/dev/null; true)"
[ "${busy:-0}" -ge 1 ] && ok "observed the agent BUSY $busy time(s) and refused to interleave" \
                       || bad "never observed a busy agent — the busy guard was not exercised"

# ═══ negative control ════════════════════════════════════════════════════════
say "Negative control: identical run, enabled: false"
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
