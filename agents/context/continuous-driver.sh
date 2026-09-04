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

# TARGET RESOLUTION IS A LADDER, NOT A SINGLE CONFIG KEY.
#
# T-3255. The first version read CONTINUOUS_SESSION and nothing else. NOTHING in the
# framework ever SETS that key -- no verb writes it, `fw init` does not seed it, and
# the wrapper that launches a session does not register it -- so on any real install
# the driver refused forever with "no target session". Same inert-by-construction
# shape as the injector path and the `info` check: a mechanism that cannot fire in
# the environment it ships to, whose failure reads as a tidy refusal, not a defect.
#
# So the target is DISCOVERED, with configuration as an override rather than a
# prerequisite:
#   1. --session          explicit, wins outright
#   2. CONTINUOUS_SESSION operator pin, for when several sessions qualify
#   3. tag project:<name> the tag the wrapper applies
#   4. name claude-*      the wrapper's naming convention (claude-master-<PID>)
#
# A TIE IS NOT BROKEN BY GUESSING. Multiple candidates refuse and name them:
# injecting a continuation turn into the wrong agent is worse than not injecting,
# and "first in list order" is not a decision anyone made.
_candidates() {
    local proj; proj="$(basename "$ROOT")"
    local by_tag
    by_tag="$(timeout 20 termlink discover --tag "project:${proj}" --names --no-header 2>/dev/null)"
    if [ -n "$by_tag" ]; then printf '%s\n' "$by_tag"; return 0; fi
    timeout 20 termlink discover --name "claude-" --names --no-header 2>/dev/null
}

if [ -z "$SESSION" ]; then
    SESSION="$("$FW" config get CONTINUOUS_SESSION 2>/dev/null | tr -d '[:space:]')"
    [ "$SESSION" = "null" ] && SESSION=""
fi

if [ -z "$SESSION" ]; then
    CAND="$(_candidates)"
    N="$(printf '%s' "$CAND" | grep -c . || true)"
    if [ "${N:-0}" -eq 1 ]; then
        SESSION="$(printf '%s' "$CAND" | head -1)"
        _log "resolved" "auto-resolved target session '${SESSION}' (no CONTINUOUS_SESSION pin needed)"
    elif [ "${N:-0}" -gt 1 ]; then
        _bail "refused" "${N} candidate sessions and no pin — refusing to guess which agent to drive: $(printf '%s' "$CAND" | tr '\n' ' '). Pin one: fw config set CONTINUOUS_SESSION <name>"
    fi
fi

# THE REFUSAL NAMES THE FIX. "no target session" was true and useless: a reader
# cannot tell from it whether they forgot to configure something or whether the
# session they are sitting in was never registered at all. It is almost always the
# second -- registration is a PRECONDITION of this whole mechanism, not a setting --
# and the fix is to relaunch under the wrapper.
[ -n "$SESSION" ] || _bail "refused" "no target session for project '$(basename "$ROOT")': it has NO TermLink-registered session. Registration is a precondition, not a setting -- the driver injects into a registered PTY session and there is nothing here to inject into. Fix: relaunch with 'claude-fw --termlink', or pin an existing session with 'fw config set CONTINUOUS_SESSION <name>'"

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

if ! timeout 30 termlink inject "$SESSION" --enter "$DIRECTIVE" >/dev/null 2>&1 \
   && ! timeout 30 termlink pty inject "$SESSION" --enter "$DIRECTIVE" >/dev/null 2>&1; then
    _bail "refused" "termlink inject failed for session '${SESSION}'"
fi

# ---------------------------------------------------------------------------
# 5. Confirm the turn actually LANDED. G-101.
# ---------------------------------------------------------------------------
# A zero exit status from the transport is not evidence of delivery. G-097:
# `termlink inject` returns 0 and delivers nothing into an ink-based raw-mode TUI
# — measured three ways at two points, with `tmux send-keys` succeeding against
# the identical pane at the identical moment. A driver that trusts the exit code
# therefore writes `"reason": "injected"` every tick, forever, while the agent
# never receives a turn. Same class as L-346 (claude -p exit=0 is NOT a tool-use
# signal): a clean exit says the call was accepted, never that the work happened.
#
# THE PRIMITIVE WAS ALREADY HERE. `_pty_snapshot` is called twice above for busy
# detection. This is the third call — the one that closes the loop.
#
# FAIL CLOSED, AND KEY ON THE TEXT — NOT ON "THE PANE CHANGED". Change-detection
# alone would read a spinner, clock or progress line as delivery, which
# reintroduces the exact false green this guard exists to remove. So confirmation
# requires the directive's own text to appear. The asymmetry justifies it: a wrong
# refusal costs ONE tick and says so loudly in the ledger; a wrong success costs
# every tick after it and says nothing.
#
# WHITESPACE IS STRIPPED FROM BOTH SIDES because a TUI wraps long input across
# lines, and a wrap inserted mid-word ("backl\nog") defeats a substring match that
# only collapses runs. Stripping all whitespace makes the needle wrap-immune.
#
# NO PIPE INTO `grep -q` (L-387). Under `set -o pipefail` an early-exiting grep
# SIGPIPEs its upstream and the pipeline returns 141 — a false refusal produced by
# the guard's own plumbing. `case` on a captured variable has no such failure mode.
CONFIRM_TRIES="${FW_DRIVER_CONFIRM_TRIES:-3}"
_squash() { printf '%s' "${1:-}" | tr -d '[:space:]'; }
NEEDLE="$(_squash "$DIRECTIVE" | cut -c1-32)"

if [ "${FW_DRIVER_SKIP_DELIVERY_CONFIRM:-0}" = 1 ]; then
    _log "injected" "session=${SESSION} confirmed=SKIPPED-BY-ENV directive=${DIRECTIVE:0:200}"
    echo "continuous-driver: injected into '${SESSION}' (delivery confirmation SKIPPED)"
    exit 0
fi

[ -n "$NEEDLE" ] || _bail "refused" \
    "cannot confirm delivery for session '${SESSION}': the directive is all whitespace once stripped, so there is no text to look for. Refusing rather than logging an unverifiable success."

CONFIRMED=0
for _try in $(seq 1 "$CONFIRM_TRIES"); do
    SNAP_C="$(_pty_snapshot)" || SNAP_C=""
    case "$(_squash "$SNAP_C")" in
        *"$NEEDLE"*) CONFIRMED=1; break ;;
    esac
    [ "$_try" -lt "$CONFIRM_TRIES" ] && sleep 1
done

if [ "$CONFIRMED" != 1 ]; then
    _bail "refused" "delivery UNCONFIRMED for session '${SESSION}': the transport returned success but the directive's text never appeared in the pane across ${CONFIRM_TRIES} samples. This is the G-097 shape — inject exits 0 and delivers nothing into an ink-based raw-mode TUI. NOT logging 'injected', because that would be a false success and the loop would look alive while doing nothing. Check by hand: termlink pty output '${SESSION}' --strip-ansi. If this target legitimately consumes input without echoing it, set FW_DRIVER_SKIP_DELIVERY_CONFIRM=1 (which restores the pre-G-101 blind behaviour — prefer fixing the transport)."
fi

_log "injected" "session=${SESSION} confirmed=text-in-pane directive=${DIRECTIVE:0:200}"
echo "continuous-driver: injected a continuation turn into '${SESSION}' (delivery confirmed)"
exit 0
