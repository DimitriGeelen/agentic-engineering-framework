#!/bin/bash
# REFERENCE ONLY — not registered in .claude/settings.json (see T-1459)
# Stop hook — conversation-capture nudge (T-1211)
#
# Fires after every assistant response. Never blocks (exits 0). Emits an
# agent-visible stderr nudge when a "pure conversation" session has accumulated
# N exchanges without using any tools, making any commits, or setting a focus.
#
# The nudge is a one-line stderr message that becomes additional context on the
# agent's next turn (per Claude Code hooks semantics). On seeing it, the agent
# proactively asks the user a y/n:
#   "We've been talking for N exchanges without capturing anything. Should I
#    create a task to summarize this conversation so far? (y/n)"
#
# On 'y': agent creates a task via `fw work-on "summary" --type spec` and
#         continues — conversation is now governed.
# On 'n': agent writes a dismissal marker; nudge re-fires N exchanges later.
#
# State files (under <project>/.context/working/):
#   .stop-counter         : monotonic count of Stop hook fires this session
#   .stop-next-nudge-at   : the stop_counter value at which the next nudge fires
#   .stop-dismissed       : timestamp of last dismissal ('n' answer), set by agent
#
# Source signals the hook reads:
#   .tool-counter   : 0 means no tool use this session (pure conversation)
#   focus.yaml      : current_task: null means no task governance active
#
# Threshold: N=15 exchanges (tunable via STOP_NUDGE_EVERY env).
#
# Payload fields (documented in Claude Code hooks docs):
#   session_id, transcript_path, stop_hook_active, hook_event_name
#
# Part of: Agentic Engineering Framework — T-1211 / T-1207 GO (closes G-005)

set -uo pipefail

NUDGE_EVERY=${STOP_NUDGE_EVERY:-15}

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
STOP_COUNTER="${WORKING_DIR}/.stop-counter"
STOP_NEXT_NUDGE="${WORKING_DIR}/.stop-next-nudge-at"
TOOL_COUNTER="${WORKING_DIR}/.tool-counter"
FOCUS_FILE="${WORKING_DIR}/focus.yaml"
LOG_FILE="${WORKING_DIR}/stop-guard.log"

mkdir -p "$WORKING_DIR" 2>/dev/null || true

# Drain stdin (hook convention); we don't use the payload fields here.
cat > /dev/null

python3 - "$STOP_COUNTER" "$STOP_NEXT_NUDGE" "$TOOL_COUNTER" "$FOCUS_FILE" "$LOG_FILE" "$NUDGE_EVERY" <<'PYEOF'
import sys, os, time, pathlib

stop_counter_p, next_nudge_p, tool_counter_p, focus_p, log_p, every_s = sys.argv[1:]
every = int(every_s)

def read_int(path, default=0):
    try:
        return int(pathlib.Path(path).read_text().strip())
    except Exception:
        return default

def write_int(path, v):
    try:
        pathlib.Path(path).write_text(str(v) + "\n")
    except Exception:
        pass

def log(msg):
    try:
        with open(log_p, "a") as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {msg}\n")
    except Exception:
        pass

stop_counter = read_int(stop_counter_p, 0) + 1
write_int(stop_counter_p, stop_counter)

next_nudge = read_int(next_nudge_p, every)

if stop_counter < next_nudge:
    sys.exit(0)

tool_counter = read_int(tool_counter_p, 0)

current_task = None
fp = pathlib.Path(focus_p)
if fp.exists():
    try:
        for line in fp.read_text().splitlines():
            stripped = line.strip()
            if stripped.startswith("current_task:"):
                v = stripped.split(":", 1)[1].strip().strip('"').strip("'")
                if v and v.lower() not in ("null", "none", "~"):
                    current_task = v
                break
    except Exception:
        pass

if tool_counter == 0 and current_task is None:
    sys.stderr.write(
        f"[T-1211 stop-guard] {stop_counter} exchanges with 0 tools and no focus "
        f"task. Ask the user: 'We've been talking for a while without capturing "
        f"anything. Should I create a task to summarize this conversation so far? "
        f"(y/n)' On y: run `fw work-on \"<summary>\" --type spec` and include a "
        f"brief context dump. On n: write `.context/working/.stop-dismissed` with "
        f"current timestamp; nudge re-fires in {every} exchanges.\n"
    )
    log(f"nudge-fired count={stop_counter} next_was={next_nudge}")
else:
    log(f"conditions-not-met count={stop_counter} tools={tool_counter} task={current_task}")

write_int(next_nudge_p, stop_counter + every)

sys.exit(0)
PYEOF
