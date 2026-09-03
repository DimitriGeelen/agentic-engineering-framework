#!/usr/bin/env bash
# T-3254 (arc-012) — drive the loop from OUTSIDE when the agent stops early.
#
# THE HOLE THIS FILLS. The live ledger records three `exit no-signal` entries: the
# loop simply ended, not because the backlog was empty but because the agent stopped
# before filling 285K tokens. Continuity depended on the agent being wasteful enough
# to hit the wall, which is backwards.
#
#   M1 (Stop-hook continuation) is capped at exactly ONE turn — stop_hook_active is
#      honoured ahead of every cap we own, and Claude Code sets it on any stop that
#      follows a hook-driven continuation (measured, T-3239 E2).
#   M2 (budget compact-resume) fires only at budget-critical — the wrong trigger for
#      "the agent stopped early".
#
# This is the third path. An INJECTED prompt is a new USER turn, not a hook-driven
# continuation, so `stop_hook_active` is never set for it. This does not fight the
# vendor's runaway guard, disable it, or depend on it changing — the guard stays
# exactly where it is and keeps governing the M1 path.
#
# THE SAFETY ARGUMENT IS STRUCTURAL, NOT A COUNTER. A hook loop can re-drive itself
# at machine speed. A cron driver injects at most once per tick, bounded by wall
# clock, so the runaway ceiling is a property of the scheduler rather than of logic
# we had to get right.
#
# THE HONEST COST. Going around the guard means WE own the bounding entirely. The
# mitigation is that this driver refuses on exactly the bounds the SessionStart path
# refuses on — and it does not re-type them. `fw continuous status --json` is the
# single evaluator; this reads its verdict. If the bounds ever change, they change
# in one place and this follows automatically.
#
# Never fatal. Every exit is 0 unless --strict: a driver that dies loudly in cron
# mails root every tick and gets disabled, which removes the loop entirely.

set -uo pipefail

DRY_RUN=0; STRICT=0; SESSION=""; ROOT=""; SETTLE="${FW_DRIVER_SETTLE:-2}"
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --strict)  STRICT=1; shift ;;
        --session) SESSION="$2"; shift 2 ;;
        --project-root) ROOT="$2"; shift 2 ;;
        --settle) SETTLE="$2"; shift 2 ;;
        -h|--help)
            echo "usage: continuous-driver.sh [--dry-run] [--strict] [--session NAME] [--project-root DIR] [--settle SECS]"
            exit 0 ;;
        *) echo "continuous-driver: unknown option '$1'" >&2; exit 2 ;;
    esac
done

[ -n "$ROOT" ] || ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FW="$ROOT/bin/fw"; [ -x "$FW" ] || FW="$ROOT/.agentic-framework/bin/fw"
LEDGER="$ROOT/.context/working/continuous-run.jsonl"

# Typed ledger entry. Same schema the wrapper writes (ts/event/reason/detail), so a
# reader reconstructs one history across both paths rather than joining two formats.
# EVERY decision is recorded, refusals included — the AC is that a reader can tell
# why the loop did or did not continue at each tick WITHOUT re-running anything.
_log() {
    local reason="$1" detail="${2:-}"
    [ -d "$ROOT/.context/working" ] || return 0
    python3 - "$LEDGER" "$reason" "$detail" "$$" <<'PY' 2>/dev/null || true
import json, sys, time
logf, reason, detail, pid = sys.argv[1:5]
rec = dict(ts=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           event="drive", reason=reason, restart_count=0,
           wrapper_pid=int(pid) if str(pid).isdigit() else 0)
if detail:
    rec["detail"] = detail[:800]
with open(logf, "a", encoding="utf-8") as f:
    f.write(json.dumps(rec) + "\n")
PY
}

_bail() { _log "$1" "${2:-}"; [ "$STRICT" = 1 ] && exit 1; exit 0; }

# ---------------------------------------------------------------------------
# 1. The bounds. One evaluator, read — never re-typed.
# ---------------------------------------------------------------------------
[ -x "$FW" ] || { echo "continuous-driver: no fw at $FW" >&2; exit 0; }
STATUS_JSON="$("$FW" continuous status --json 2>/dev/null)"
[ -n "$STATUS_JSON" ] || _bail "refused" "fw continuous status --json produced nothing"

# The JSON is piped, never interpolated into the script text. The directive it
# carries is arbitrary operator prose containing quotes, backslashes and newlines,
# and embedding it in a heredoc makes the parse depend on its content (L-408).
_probe() { printf '%s' "$STATUS_JSON" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("0"); print("status-unparseable"); sys.exit(0)
print("1" if d.get("may_inject") else "0")
print("; ".join(d.get("blockers") or []) or "none")
'; }
PROBE="$(_probe)"
MAY="$(printf '%s' "$PROBE" | sed -n '1p')"
BLOCKERS="$(printf '%s' "$PROBE" | sed -n '2p')"

if [ "$MAY" != "1" ]; then
    _bail "refused" "bounds say stop: ${BLOCKERS}"
fi

DIRECTIVE="$(printf '%s' "$STATUS_JSON" | python3 -c "import json,sys; print((json.load(sys.stdin).get('directive') or '').strip())" 2>/dev/null)"
[ -n "$DIRECTIVE" ] || _bail "refused" "armed but the directive is empty — nothing to inject"

# ---------------------------------------------------------------------------
# 2. The target session.
# ---------------------------------------------------------------------------
command -v termlink >/dev/null 2>&1 || _bail "refused" "termlink not on PATH"

if [ -z "$SESSION" ]; then
    SESSION="$("$FW" config get CONTINUOUS_SESSION 2>/dev/null | tr -d '[:space:]')"
fi
[ -n "$SESSION" ] && [ "$SESSION" != "null" ] || _bail "refused" \
    "no target session: set one with 'fw config set CONTINUOUS_SESSION <name>' or pass --session"

# Registration is checked with `discover`, NOT `info`. `termlink info` takes no
# positional target at all -- it reports hub/runtime status -- so `info "$SESSION"`
# exits non-zero with "unexpected argument" for EVERY session, registered or not.
# The driver would have refused every target it was ever pointed at, and the refusal
# message would have said "not registered", which is a plausible-sounding lie.
#
# It survived review because the unit test stubbed `info` to exit 0: the stub was
# written against the driver's assumption instead of against the tool, so the two
# agreed with each other and neither agreed with termlink. Pinned now by a contract
# test that runs against the real binary (t3254 B4).
#
# `--name` is a SUBSTRING match, so the exact name is re-asserted with grep -Fxq --
# otherwise 't3254' would happily match 't3254-other-session'.
timeout 20 termlink discover --name "$SESSION" --names --no-header 2>/dev/null \
    | grep -Fxq "$SESSION" \
    || _bail "refused" "target session '${SESSION}' is not registered"

# ---------------------------------------------------------------------------
# 3. BUSY. Observed, because TermLink does not report it.
#
# `termlink discover --json` reports state="ready" for every registered session —
# measured, 127 of 127 on this host, including sessions mid-work. `ready` means
# REGISTERED, not IDLE, so gating on that field would inject into a working session
# and interleave input with whatever it was doing.
#
# So busy is observed rather than read: sample the pty twice, SETTLE seconds apart,
# and treat any change as "this session is producing output". That is a real
# observation of session state, which is what the AC asks for, and it is testable
# both ways — a session running a print loop must be refused, a quiet one must not.
#
# Deliberately conservative in one direction: output that is merely slow can look
# quiet, so this can occasionally inject into a session that is thinking silently.
# The cost is one interleaved prompt; the cost of the opposite bias is never
# injecting at all. Raise --settle where that trade is wrong.
# ---------------------------------------------------------------------------
# The snapshot PROPAGATES failure instead of swallowing it. A session that is
# registered but not PTY-backed answers `pty output` with an error and no bytes, so
# both samples come back empty, the two compare EQUAL, and the session reads as
# perfectly idle -- the driver then injects into something that cannot receive
# keystrokes and fails at the last step, having reported quiet all the way down.
#
# Measured: a session spawned without --shell returns "No PTY session — output
# capture not available", and `inject` refuses it with "39 byte(s) were resolved but
# never reached a terminal". Neither is an idle session, and neither should look
# like one. This is the same rule the ceiling check already follows: "could not
# evaluate" is not a green light, and letting it collapse into "fine" is how a guard
# stops guarding.
_pty_snapshot() {
    local out rc
    out="$(timeout 15 termlink pty output "$SESSION" --strip-ansi 2>/dev/null)"; rc=$?
    [ "$rc" -eq 0 ] || return "$rc"
    printf '%s' "$out" | tail -c 4000
}
SNAP_A="$(_pty_snapshot)" || _bail "refused" \
    "session '${SESSION}' is not PTY-backed (pty output unavailable) — it cannot receive an injected turn; re-create it with 'termlink spawn --shell'"
sleep "$SETTLE"
SNAP_B="$(_pty_snapshot)" || _bail "refused" \
    "session '${SESSION}' stopped answering pty output mid-check — refusing rather than guessing it is idle"

if [ "$SNAP_A" != "$SNAP_B" ]; then
    _bail "refused" "session '${SESSION}' is BUSY (pty output changed across ${SETTLE}s) — injecting would interleave input"
fi

# ---------------------------------------------------------------------------
# 4. Inject. A new user turn — not a hook continuation.
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
    _log "dry-run" "would inject into '${SESSION}': ${DIRECTIVE:0:200}"
    echo "continuous-driver: DRY RUN — would inject into '${SESSION}'"
    exit 0
fi

if timeout 30 termlink inject "$SESSION" --enter "$DIRECTIVE" >/dev/null 2>&1 \
   || timeout 30 termlink pty inject "$SESSION" --enter "$DIRECTIVE" >/dev/null 2>&1; then
    _log "injected" "session=${SESSION} directive=${DIRECTIVE:0:200}"
    echo "continuous-driver: injected a continuation turn into '${SESSION}'"
    exit 0
fi

_bail "refused" "termlink inject failed for session '${SESSION}'"
