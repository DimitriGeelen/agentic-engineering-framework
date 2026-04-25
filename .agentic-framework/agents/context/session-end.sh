#!/bin/bash
# REFERENCE ONLY — not registered in .claude/settings.json (see T-1459)
# SessionEnd hook — S1 reason logger + S2 handover trigger (T-1212)
#
# Fires on session termination. Always exits 0.
#   S1: appends {ts, session_id, reason} JSON line to
#       .context/working/.session-end-log for reason-field telemetry.
#   S2: if no handover exists for the current session_id
#       (`.context/handovers/LATEST.md` frontmatter session_id mismatch), runs
#       `fw handover` in the background. Background so the hook returns fast
#       (<2s) regardless of handover duration — some session-end reasons
#       (e.g. API 500 kill) give us very little grace period.
#
# Known Claude Code bugs this hook tolerates:
#   #17885 — SessionEnd doesn't fire on /exit in some versions.
#   #20197 — API 500 terminations skip SessionEnd.
# Fallback for both: `session-silent-scanner.sh` via cron, runs every 15 min,
# walks claude session transcripts and generates recovery handovers for
# sessions that skipped this hook.
#
# Payload fields (Claude Code documented):
#   session_id, transcript_path, reason, hook_event_name
#
# Part of: Agentic Engineering Framework — T-1212 / T-1208 GO.

set -uo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
HANDOVERS_DIR="${PROJECT_ROOT}/.context/handovers"
TELEMETRY_FILE="${WORKING_DIR}/.session-end-log"
LOG_FILE="${WORKING_DIR}/session-end.log"
LATEST="${HANDOVERS_DIR}/LATEST.md"

mkdir -p "$WORKING_DIR" 2>/dev/null || true

INPUT=$(cat)

python3 - "$INPUT" "$TELEMETRY_FILE" "$LOG_FILE" "$LATEST" "$PROJECT_ROOT" <<'PYEOF'
import sys, json, time, os, pathlib, subprocess

raw, telemetry_p, log_p, latest_p, project_root = sys.argv[1:]

def log(msg):
    try:
        with open(log_p, "a") as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {msg}\n")
    except Exception:
        pass

try:
    payload = json.loads(raw)
except Exception as e:
    log(f"bad-payload {e}")
    sys.exit(0)

session_id = payload.get("session_id", "unknown")
reason = payload.get("reason", "unknown")

# S1 telemetry
try:
    with open(telemetry_p, "a") as f:
        f.write(json.dumps({
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "session_id": session_id,
            "reason": reason,
        }) + "\n")
except Exception as e:
    log(f"telemetry-write-error {e}")

# S2 idempotency: is there already a handover for this session?
existing_session = None
lp = pathlib.Path(latest_p)
if lp.exists():
    try:
        in_frontmatter = False
        for line in lp.read_text().splitlines():
            if line.strip() == "---":
                if in_frontmatter:
                    break
                in_frontmatter = True
                continue
            if in_frontmatter and line.strip().startswith("session_id:"):
                existing_session = line.split(":", 1)[1].strip().strip('"').strip("'")
                break
    except Exception as e:
        log(f"latest-read-error {e}")

if existing_session and existing_session == session_id:
    log(f"skip-already-handed-over session={session_id} reason={reason}")
    sys.exit(0)

# S2 trigger: run fw handover in the background
fw_bin = os.path.join(project_root, ".agentic-framework/bin/fw")
if not os.path.exists(fw_bin):
    log(f"fw-bin-missing cannot-trigger-handover path={fw_bin}")
    sys.exit(0)

try:
    subprocess.Popen(
        [fw_bin, "handover"],
        cwd=project_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
    )
    log(f"spawned-handover session={session_id} reason={reason}")
except Exception as e:
    log(f"spawn-handover-error {e}")

sys.exit(0)
PYEOF
