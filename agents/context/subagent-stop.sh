#!/bin/bash
# SubagentStop hook — capture sub-agent returns, auto-migrate to fw bus (T-1213)
#
# Fires when a Task-tool sub-agent finishes. Reads the sub-agent transcript from
# disk (payload.transcript_path), measures the last assistant message in bytes,
# and:
#   1. ALWAYS appends a telemetry JSON line to .context/working/subagent-returns.jsonl
#      for size-distribution analysis (S2 data stream from T-1209).
#   2. If bytes > THRESHOLD, posts the full message to `fw bus` as a blob so
#      subsequent turns can read it via R-NNN without re-ingesting the raw blob.
#
# SubagentStop cannot mutate the orchestrator-visible response (Claude Code docs:
# hooks cannot modify subagent behavior; exit 2 only forces re-execution). So this
# is a capture-and-log hook, not an interceptor. Information is preserved on disk
# and in the bus; the orchestrator still sees whatever the sub-agent returned in
# the current turn. Future turns benefit from the structural memory.
#
# Supersedes: check-dispatch.sh (PostToolUse advisory). Exits 0 always.
#
# Payload fields used (Claude Code documented):
#   - transcript_path : path to sub-agent JSONL transcript
#   - agent_type      : e.g. "Explore", "general-purpose"
#   - agent_id        : unique per dispatch
#   - session_id      : parent session
#
# Part of: Agentic Engineering Framework — T-1213 / T-1209 GO

set -uo pipefail

# Tunables (initial values per T-1209 GO decision)
THRESHOLD_BYTES=${SUBAGENT_STOP_THRESHOLD:-8192}

# Resolve project root via env set by fw wrapper
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
TELEMETRY_FILE="${WORKING_DIR}/subagent-returns.jsonl"
LOG_FILE="${WORKING_DIR}/subagent-stop.log"

mkdir -p "$WORKING_DIR" 2>/dev/null || true

INPUT=$(cat)

python3 - "$INPUT" "$THRESHOLD_BYTES" "$TELEMETRY_FILE" "$LOG_FILE" "$PROJECT_ROOT" <<'PYEOF'
import sys, json, os, time, subprocess, tempfile, pathlib

raw, threshold_s, telemetry_path, log_path, project_root = sys.argv[1:]
threshold = int(threshold_s)

def log(msg):
    try:
        with open(log_path, "a") as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {msg}\n")
    except Exception:
        pass

try:
    payload = json.loads(raw)
except Exception as e:
    log(f"bad-payload {e}")
    sys.exit(0)

transcript_path = payload.get("transcript_path", "")
agent_type = payload.get("agent_type", "unknown")
agent_id = payload.get("agent_id", "")
session_id = payload.get("session_id", "")

last_msg = ""
if transcript_path and os.path.exists(transcript_path):
    try:
        with open(transcript_path) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                if entry.get("type") == "assistant" or entry.get("role") == "assistant":
                    content = entry.get("message", {}).get("content") or entry.get("content") or ""
                    if isinstance(content, list):
                        parts = []
                        for block in content:
                            if isinstance(block, dict) and block.get("type") == "text":
                                parts.append(block.get("text", ""))
                        content = "\n".join(parts)
                    if isinstance(content, str) and content:
                        last_msg = content
    except Exception as e:
        log(f"transcript-read-error {e}")

bytes_len = len(last_msg.encode("utf-8"))
migrated = False
bus_ref = None

if bytes_len > threshold:
    focus_file = pathlib.Path(project_root) / ".context/working/focus.yaml"
    task_id = None
    if focus_file.exists():
        try:
            for line in focus_file.read_text().splitlines():
                stripped = line.strip()
                if stripped.startswith("current_task:") or stripped.startswith("task:"):
                    task_id = stripped.split(":", 1)[1].strip().strip('"').strip("'")
                    break
        except Exception:
            pass

    if task_id:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False, dir="/tmp") as tf:
            tf.write(last_msg)
            blob_path = tf.name
        try:
            first_line = last_msg.splitlines()[0] if last_msg else ""
            summary = f"[{agent_type}] {first_line[:100]}"
            fw_bin = os.path.join(project_root, ".agentic-framework/bin/fw")
            if not os.path.exists(fw_bin):
                fw_bin = "fw"
            result = subprocess.run(
                [fw_bin, "bus", "post",
                 "--task", task_id,
                 "--agent", f"subagent-{agent_type}",
                 "--summary", summary,
                 "--blob", blob_path],
                capture_output=True, text=True, timeout=15
            )
            if result.returncode == 0:
                migrated = True
                bus_ref = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else "posted"
                log(f"migrated {task_id} agent={agent_type} bytes={bytes_len} ref={bus_ref}")
            else:
                log(f"bus-post-failed rc={result.returncode} stderr={result.stderr[:200]}")
        except Exception as e:
            log(f"bus-post-exception {e}")
        finally:
            try:
                os.unlink(blob_path)
            except Exception:
                pass
    else:
        log(f"over-threshold-no-focus bytes={bytes_len} agent={agent_type}")

telemetry = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "session_id": session_id,
    "agent_type": agent_type,
    "agent_id": agent_id,
    "bytes": bytes_len,
    "threshold": threshold,
    "migrated": migrated,
    "bus_ref": bus_ref,
}
try:
    with open(telemetry_path, "a") as f:
        f.write(json.dumps(telemetry) + "\n")
except Exception as e:
    log(f"telemetry-write-error {e}")

if migrated:
    sys.stderr.write(
        f"[T-1213] Sub-agent ({agent_type}) return of {bytes_len} bytes > {threshold} "
        f"threshold — archived to fw bus ({bus_ref}). Next turn can read via: "
        f"fw bus manifest\n"
    )

sys.exit(0)
PYEOF
