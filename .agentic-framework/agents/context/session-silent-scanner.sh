#!/bin/bash
# REFERENCE ONLY — not registered in .claude/settings.json (see T-1459)
# Silent-session scanner — S3 antifragility fallback for SessionEnd (T-1212)
#
# Invoked via cron every 15 min. Walks $HOME/.claude/projects/<slug>/<session>.jsonl
# for THIS project's slug (and its worktree slugs) only (T-4699),
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
# T-1222 / G-016: cap per-invocation to prevent runaway handover storm.
# A large backlog of ancient agent-acompact-* sessions would otherwise spawn
# N git commits + pushes serially. Cap at 10/run; re-run to continue.
MAX_RECOVERIES=${SESSION_SILENT_MAX_RECOVERIES:-10}
# T-1222 / G-016: age ceiling. Sessions older than this carry zero useful
# context — a banner handover is worthless. Default 7 days.
MAX_AGE_DAYS=${SESSION_SILENT_MAX_AGE_DAYS:-7}
# T-4700: log size cap; above it the log is rotated to <log>.1 (one copy kept).
LOG_MAX_BYTES=${SESSION_SILENT_LOG_MAX_BYTES:-1048576}

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
HANDOVERS_DIR="${PROJECT_ROOT}/.context/handovers"
LOG_FILE="${WORKING_DIR}/.session-silent-scanner.log"

mkdir -p "$WORKING_DIR" 2>/dev/null || true

CLAUDE_PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

python3 - "$THRESHOLD_MIN" "$PROJECT_ROOT" "$HANDOVERS_DIR" "$LOG_FILE" "$CLAUDE_PROJECTS_DIR" "$DRY_RUN" "$MAX_RECOVERIES" "$MAX_AGE_DAYS" "$LOG_MAX_BYTES" <<'PYEOF'
import sys, os, time, pathlib, subprocess, json, re

threshold_s, project_root, handovers_dir_s, log_p, claude_projects_s, dry_run_s, max_recoveries_s, max_age_days_s, log_max_bytes_s = sys.argv[1:]
dry_run = dry_run_s != "0"
threshold_secs = int(threshold_s) * 60
max_recoveries = int(max_recoveries_s)
max_age_secs = int(max_age_days_s) * 86400
project_root_p = pathlib.Path(project_root)
handovers_dir = pathlib.Path(handovers_dir_s)
claude_projects = pathlib.Path(claude_projects_s)

# T-4700: rotate once per run, before the first write, so the log stays bounded.
try:
    if os.path.getsize(log_p) > int(log_max_bytes_s):
        os.replace(log_p, log_p + ".1")
except Exception:
    pass

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

# T-4699: scan only THIS project's transcripts. Claude Code names a project's
# transcript dir by replacing every non-alphanumeric char of the absolute path
# with '-'; worktrees under <root>/.claude/worktrees/<name> slug to
# <slug>--claude-worktrees-<name>. Every other dir is another project's.
project_real = os.path.realpath(project_root)
project_slug = re.sub(r'[^A-Za-z0-9]', '-', project_real)
project_dirs = []
for d in sorted(claude_projects.iterdir()):
    if d.is_dir() and (d.name == project_slug or d.name.startswith(project_slug + "--claude-worktrees-")):
        project_dirs.append(d)

def transcript_cwd(path, max_lines=200):
    """First cwd recorded in a transcript, or None."""
    try:
        with open(path, errors="ignore") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                try:
                    cwd = json.loads(line).get("cwd")
                except Exception:
                    continue
                if isinstance(cwd, str) and cwd:
                    return cwd
    except Exception:
        pass
    return None

def cwd_in_project(cwd):
    if not cwd:
        return False
    real = os.path.realpath(cwd)
    return real == project_real or real.startswith(project_real.rstrip("/") + "/")

log(f"scan-scope slug={project_slug} dirs={len(project_dirs)}")

now = time.time()
candidates = []
skipped_too_old = 0
for jsonl in (p for d in project_dirs for p in d.rglob("*.jsonl")):
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
    # T-1222 / G-016: age ceiling — ancient sessions' banner handovers are noise.
    if age > max_age_secs:
        # T-4700: counted only — one line per old transcript per run grew the log ~30 MB/day.
        skipped_too_old += 1
        continue
    # T-4699: never recover a session that did not run in this project.
    cwd = transcript_cwd(jsonl)
    if not cwd_in_project(cwd):
        log(f"skip-foreign-cwd session={session_id} cwd={cwd} transcript={jsonl}")
        continue
    candidates.append((jsonl, session_id, age))

if skipped_too_old:
    log(f"skip-too-old-total count={skipped_too_old} max-age-days={max_age_days_s}")

if not candidates:
    log(f"scan-end no-recoveries dry_run={dry_run}")
    sys.exit(0)

if dry_run:
    for jsonl, session_id, age in candidates[:max_recoveries]:
        log(f"DRY-RUN would-recover session={session_id} age-min={int(age/60)} transcript={jsonl}")
    if len(candidates) > max_recoveries:
        log(f"DRY-RUN cap-would-hit candidates={len(candidates)} max={max_recoveries} remaining={len(candidates)-max_recoveries}")
    log(f"scan-end candidates={len(candidates)} dry_run=1 (set DRY_RUN=0 to trigger fw handover)")
    sys.exit(0)

recovered = 0
fw_bin = os.path.join(project_root, ".agentic-framework/bin/fw")
if not os.path.exists(fw_bin):
    log(f"fw-bin-missing cannot-recover path={fw_bin}")
    sys.exit(0)

for jsonl, session_id, age in candidates:
    # T-1222 / G-016: per-invocation cap. Re-run to drain remaining backlog.
    if recovered >= max_recoveries:
        remaining = len(candidates) - recovered
        log(f"cap-reached N={recovered} remaining={remaining} max={max_recoveries}")
        break
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
