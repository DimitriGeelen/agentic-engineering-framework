#!/bin/bash
# Silent-session scanner — S3 antifragility fallback for SessionEnd (T-1212)
#
# Invoked via cron every 15 min. Walks $HOME/.claude/projects/*/<session>.jsonl,
# finds session transcripts whose mtime is older than SESSION_SILENT_THRESHOLD_MIN
# (default 30 min) AND whose session_id does NOT appear in any file under
# .context/handovers/. For matches, runs `fw handover` with RECOVERED=1 so the
# generated handover carries a `[recovered, no agent context]` banner.
#
# Together with session-end.sh this closes the SessionEnd gap for:
#   - Claude Code #17885 (/exit skips SessionEnd)
#   - Claude Code #20197 (API 500 kills before hook fires)
#   - SIGKILL / laptop sleep / network drops
#
# Non-blocking, idempotent. Safe to run as often as desired (no-op if nothing
# needs recovery).
#
# Part of: Agentic Engineering Framework — T-1212 / T-1208 GO.

set -uo pipefail

THRESHOLD_MIN=${SESSION_SILENT_THRESHOLD_MIN:-30}
# DRY_RUN defaults to 1 (safe). Cron stanza opts in with DRY_RUN=0.
# A non-dry run triggers fw handover (which commits + pushes) — destructive.
DRY_RUN=${DRY_RUN:-1}

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
HANDOVERS_DIR="${PROJECT_ROOT}/.context/handovers"
LOG_FILE="${WORKING_DIR}/.session-silent-scanner.log"

mkdir -p "$WORKING_DIR" 2>/dev/null || true

CLAUDE_PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

python3 - "$THRESHOLD_MIN" "$PROJECT_ROOT" "$HANDOVERS_DIR" "$LOG_FILE" "$CLAUDE_PROJECTS_DIR" "$DRY_RUN" <<'PYEOF'
import sys, os, time, pathlib, subprocess, json, re

threshold_s, project_root, handovers_dir_s, log_p, claude_projects_s, dry_run_s = sys.argv[1:]
dry_run = dry_run_s != "0"
threshold_secs = int(threshold_s) * 60
project_root_p = pathlib.Path(project_root)
handovers_dir = pathlib.Path(handovers_dir_s)
claude_projects = pathlib.Path(claude_projects_s)

def log(msg):
    try:
        with open(log_p, "a") as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {msg}\n")
    except Exception:
        pass

if not claude_projects.is_dir():
    log(f"no-claude-projects-dir {claude_projects} — nothing to scan")
    sys.exit(0)

if not handovers_dir.is_dir():
    log(f"no-handovers-dir {handovers_dir} — nothing to compare against")
    sys.exit(0)

# Build index of known session_ids from handover files (scans once per run)
known_sessions = set()
for md in handovers_dir.glob("*.md"):
    try:
        text = md.read_text(errors="ignore")
        m = re.search(r'^session_id:\s*(\S+)', text, re.MULTILINE)
        if m:
            known_sessions.add(m.group(1).strip('"').strip("'"))
    except Exception:
        continue

log(f"scan-start known-handovers={len(known_sessions)} threshold-min={threshold_s}")

now = time.time()
candidates = []
for jsonl in claude_projects.rglob("*.jsonl"):
    try:
        mtime = jsonl.stat().st_mtime
    except Exception:
        continue
    age = now - mtime
    if age < threshold_secs:
        continue
    session_id = jsonl.stem
    if session_id in known_sessions:
        continue
    candidates.append((jsonl, session_id, age))

if not candidates:
    log(f"scan-end no-recoveries dry_run={dry_run}")
    sys.exit(0)

if dry_run:
    for jsonl, session_id, age in candidates:
        log(f"DRY-RUN would-recover session={session_id} age-min={int(age/60)} transcript={jsonl}")
    log(f"scan-end candidates={len(candidates)} dry_run=1 (set DRY_RUN=0 to trigger fw handover)")
    sys.exit(0)

recovered = 0
fw_bin = os.path.join(project_root, ".agentic-framework/bin/fw")
if not os.path.exists(fw_bin):
    log(f"fw-bin-missing cannot-recover path={fw_bin}")
    sys.exit(0)

for jsonl, session_id, age in candidates:
    age_min = int(age / 60)
    env = os.environ.copy()
    env["RECOVERED"] = "1"
    env["RECOVERED_SESSION_ID"] = session_id
    env["RECOVERED_AGE_MIN"] = str(age_min)
    env["RECOVERED_TRANSCRIPT"] = str(jsonl)
    try:
        result = subprocess.run(
            [fw_bin, "handover"],
            cwd=project_root,
            capture_output=True, text=True, timeout=30, env=env,
        )
        if result.returncode == 0:
            recovered += 1
            log(f"recovered session={session_id} age-min={age_min} transcript={jsonl}")
        else:
            log(f"recover-failed session={session_id} rc={result.returncode} stderr={result.stderr[:200]}")
    except Exception as e:
        log(f"recover-exception session={session_id} {e}")

log(f"scan-end candidates={len(candidates)} recovered={recovered}")
sys.exit(0)
PYEOF
