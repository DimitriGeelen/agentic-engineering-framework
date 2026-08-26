#!/bin/bash
# Stop hook — the continuous-run turn driver (T-3164, arc-012 S1).
#
# THE PROBLEM THIS SOLVES. Without a Stop hook, control returns to the idle prompt
# after every assistant turn. arc-012 built an entire continuous-run substrate —
# budget gauge, auto-handover, restart signal, iteration counter, tier ceiling,
# directive injector — on top of a loop that had no driver, so the mechanic never
# fired once across 26 tasks. T-2404 named the gap exactly and fixed it by appending
# prose asking the agent to invoke /resume: a repair that presumes the very turn it
# is trying to cause. This hook is that turn.
#
# THE CONTRACT, MEASURED (T-3163) — do not "simplify" this:
#   {"decision": "block", "reason": "..."}  -> Claude takes ANOTHER turn.   WORKS.
#   exit 2 with the reason on stderr        -> Claude takes ANOTHER turn.   WORKS.
#   {"ok": false, "reason": "..."}          -> INERT. Output is identical to
#                                              returning {}. A driver built on this
#                                              shape fires, logs, returns cleanly and
#                                              drives nothing — and only a control leg
#                                              can tell the difference.
#   {}                                      -> yield to the prompt (stop).
# Pinned by tests/unit/stop_driver.bats. The wrong shape is silently inert, which is
# why the assertion exists at all.
#
# POSTURE: DISARMED BY DEFAULT, AND FAILS CLOSED.
# Every path that is not an explicit, in-cap, un-halted continuation emits {} — absent
# state file, malformed YAML, missing python3, unreadable payload, any error at all.
# Registering this hook is a no-op for an ordinary session. That is deliberate: a
# driver that continued by default would take the operator's session away from them.
#
# SOVEREIGNTY (T-3159 IW-2). A component that decides whether to continue can decide
# not to stop. Three independent brakes, checked in this order:
#   1. HALT FILE      — read first, before anything else can vote. Out of band from
#                       the model's reasoning, so it works precisely when the model is
#                       the thing misbehaving. Operator writes it; nothing else clears
#                       it automatically.
#   2. OUR CAPS       — max_iterations, expires_at / expires_after_seconds.
#   3. PLATFORM CAP   — stop_hook_active, plus Claude Code's own 8-consecutive-block
#                       ceiling. We deliberately do NOT raise CLAUDE_CODE_STOP_HOOK_
#                       BLOCK_CAP: our counter is meant to stop the loop first, leaving
#                       the vendor's cap as the backstop we did not write.
#
# Part of: Agentic Engineering Framework — arc-012 (continuous-run)

set -uo pipefail

# ---------------------------------------------------------------------------
# yield: emit the stop contract and exit clean. Every failure path routes here.
# ---------------------------------------------------------------------------
yield() {
    printf '{}\n'
    exit 0
}

# A crash must never continue the loop, and must never break the session either.
trap 'yield' ERR

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PROJECT_ROOT:-$(pwd)}}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
STATE_FILE="${WORKING_DIR}/.continuous-mode.yaml"
HALT_FILE="${FW_CONTINUOUS_HALT:-${WORKING_DIR}/.continuous-halt}"
DIRECTIVE_FILE="${WORKING_DIR}/.next-directive.yaml"
LOG_FILE="${WORKING_DIR}/.stop-driver.log"

# Read the payload if one is piped in; never block waiting for it.
payload=""
if [ ! -t 0 ]; then
    payload=$(timeout 2 cat 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# log: every decision, with its reason. A loop that stalls or runs away has to be
# diagnosable afterwards, not by re-running it and hoping it misbehaves again.
# ---------------------------------------------------------------------------
log() {
    mkdir -p "$WORKING_DIR" 2>/dev/null || return 0
    printf '%s decision=%s reason=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >> "$LOG_FILE" 2>/dev/null || true
}

# --- Brake 1: the halt file, before anything else gets a vote --------------
if [ -f "$HALT_FILE" ]; then
    log stop "halt-file present at ${HALT_FILE}"
    yield
fi

# --- Brake 3a: the platform's own runaway guard -----------------------------
# stop_hook_active means we already drove this continuation; honouring it is what
# keeps a bug in our own counter from becoming an unbounded loop.
if [ -n "$payload" ] && command -v python3 >/dev/null 2>&1; then
    active=$(printf '%s' "$payload" | python3 -c "
import json, sys
try:
    print('yes' if json.load(sys.stdin).get('stop_hook_active') else 'no')
except Exception:
    print('unknown')
" 2>/dev/null || echo unknown)
    if [ "$active" = "yes" ]; then
        log stop "stop_hook_active=true (platform runaway guard)"
        yield
    fi
fi

# No state file, no python3, no loop. Both are hard preconditions, not warnings.
[ -f "$STATE_FILE" ] || { log stop "no state file at ${STATE_FILE}"; yield; }
command -v python3 >/dev/null 2>&1 || { log stop "python3 unavailable"; yield; }

# --- Brake 2: enabled flag + caps, evaluated together ----------------------
# Returns "continue <reason>" or "stop <reason>". Anything else is treated as stop.
verdict=$(python3 - "$STATE_FILE" "$DIRECTIVE_FILE" <<'PY' 2>/dev/null || true
import sys, datetime

def out(decision, reason):
    print(f"{decision} {reason}")
    raise SystemExit(0)

try:
    import yaml
except ImportError:
    out("stop", "pyyaml-unavailable")

state_path, directive_path = sys.argv[1], sys.argv[2]

def load(p):
    try:
        with open(p) as f:
            d = yaml.safe_load(f)
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}

state = load(state_path)
if not state:
    out("stop", "state-unreadable-or-empty")

# Disarmed is the default in every ambiguous case: only a literal true arms it.
if state.get("enabled") is not True:
    out("stop", f"continuous-mode-disabled(enabled={state.get('enabled')!r})")

directive = load(directive_path)

def as_int(v, fallback=None):
    try:
        return int(v)
    except (TypeError, ValueError):
        return fallback

cur = as_int(state.get("current_iteration"), 0) or 0
max_iter = as_int(directive.get("max_iterations"), as_int(state.get("max_iterations")))
if max_iter is not None and cur + 1 > max_iter:
    out("stop", f"max_iterations-reached({cur + 1}>{max_iter})")

now = datetime.datetime.now(datetime.timezone.utc)

def parse_ts(v):
    if v is None:
        return None
    if isinstance(v, datetime.datetime):
        return v if v.tzinfo else v.replace(tzinfo=datetime.timezone.utc)
    s = str(v).strip()
    if not s:
        return None
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.datetime.fromisoformat(s)
        return dt if dt.tzinfo else dt.replace(tzinfo=datetime.timezone.utc)
    except Exception:
        return None

expires = parse_ts(directive.get("expires_at"))
if expires is None:
    secs = as_int(state.get("expires_after_seconds"))
    filed = parse_ts(directive.get("filed_at"))
    if secs is not None and filed is not None:
        expires = filed + datetime.timedelta(seconds=secs)
if expires is not None and now > expires:
    out("stop", f"expired-at({expires.strftime('%Y-%m-%dT%H:%M:%SZ')})")

out("continue", f"iteration-{cur + 1}")
PY
)

decision="${verdict%% *}"
reason="${verdict#* }"

if [ "$decision" != "continue" ]; then
    log stop "${reason:-no-verdict}"
    yield
fi

# --- Continue: the measured contract, and nothing else ---------------------
log continue "$reason"

# The reason text is what the next turn actually reads, so it carries the
# governance bootstrap rather than a bare "keep going". T-3163 established that
# the model CAN invoke /resume via the Skill tool once a turn exists — the prose
# T-2404 wrote was never unreadable, it simply never got a turn.
next_reason="Continuous mode is armed (${reason}). Continue the run: take the next \
action toward the current arc without waiting for operator input. If you have lost \
context, invoke /resume first. Set focus with bin/fw work-on T-NNNN before any edit — \
the task gate refuses Write/Edit without an active task. Stop and surface to the \
operator if you reach a Tier-0 action, a human-owned decision, or an unchecked \
[REVIEW] acceptance criterion; never force past a gate to keep the loop alive."

python3 - "$next_reason" <<'PY'
import json, sys
# The measured contract (T-3163): decision=block drives a turn. `ok: false` does not.
print(json.dumps({"decision": "block", "reason": sys.argv[1]}))
PY
exit 0
