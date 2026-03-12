"""Cron registry blueprint — scheduled job visibility for Watchtower (T-447)."""

import glob
import os
import re
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("cron", __name__)

# Cron files managed by the framework
CRON_DIR = "/etc/cron.d"
CRON_PREFIX = "agentic-"

# Where cron audit output lands
AUDIT_CRON_DIR = PROJECT_ROOT / ".context" / "audits" / "cron"


def _parse_cron_files():
    """Parse /etc/cron.d/agentic-* files into job entries."""
    jobs = []
    pattern = os.path.join(CRON_DIR, CRON_PREFIX + "*")
    for filepath in sorted(glob.glob(pattern)):
        source_file = os.path.basename(filepath)
        try:
            content = Path(filepath).read_text(errors="replace")
        except (OSError, PermissionError):
            continue

        # Extract metadata from comments
        is_local = "LOCAL ONLY" in content
        task_refs = re.findall(r"T-\d+", content)
        origin = ", ".join(sorted(set(task_refs))) if task_refs else "unknown"

        # Parse cron lines (skip comments, blanks, variable assignments)
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" in line.split()[0] if line.split() else True:
                continue

            # Match: min hour dom mon dow user command
            m = re.match(
                r"^([\d,*/\-]+\s+[\d,*/\-]+\s+[\d,*/\-]+\s+"
                r"[\d,*/\-]+\s+[\d,*/\-]+)\s+(\S+)\s+(.+)$",
                line,
            )
            if not m:
                continue

            schedule = m.group(1).strip()
            user = m.group(2)
            command = m.group(3).strip()

            # Derive a readable name from the command
            name = _derive_job_name(command)

            jobs.append({
                "name": name,
                "schedule": schedule,
                "schedule_human": _humanize_schedule(schedule),
                "command": command,
                "user": user,
                "source_file": source_file,
                "origin": origin,
                "is_local": is_local,
                "next_run": _next_run_approx(schedule),
            })

    return jobs


def _derive_job_name(command):
    """Generate a readable name from a cron command."""
    # fw audit --section X --cron
    m = re.search(r"fw.*audit\s+--section\s+(\S+)", command)
    if m:
        sections = m.group(1).replace(",", ", ")
        return f"Audit: {sections}"

    if "find" in command and "-delete" in command:
        return "Cron file retention cleanup"

    if "onedev-pr-sync" in command:
        return "OneDev PR sync"

    if "audit" in command and "--section" not in command:
        return "Audit: full"

    # Fallback: last component of path
    parts = command.split()
    return os.path.basename(parts[0]) if parts else command[:40]


def _humanize_schedule(schedule):
    """Convert a cron expression to a human-readable approximation."""
    parts = schedule.split()
    if len(parts) != 5:
        return schedule

    minute, hour, dom, mon, dow = parts

    # Common patterns
    if minute.startswith("*/") and hour == "*":
        interval = minute.replace("*/", "")
        return f"Every {interval} min"
    if "," in minute and hour == "*":
        count = len(minute.split(","))
        return f"{count}x per hour"
    if minute.isdigit() and hour == "*":
        return f"Hourly (:{minute.zfill(2)})"
    if minute.isdigit() and hour.isdigit() and dow == "*":
        return f"Daily at {hour.zfill(2)}:{minute.zfill(2)}"
    if minute.isdigit() and hour.isdigit() and dow.isdigit():
        days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        day = days[int(dow)] if int(dow) < 7 else dow
        return f"{day} at {hour.zfill(2)}:{minute.zfill(2)}"
    if minute.isdigit() and hour.startswith("*/"):
        interval = hour.replace("*/", "")
        return f"Every {interval}h (:{minute.zfill(2)})"

    return schedule


def _next_run_approx(schedule):
    """Approximate next run time from cron expression (simple heuristic)."""
    parts = schedule.split()
    if len(parts) != 5:
        return None

    now = datetime.now(timezone.utc)
    minute, hour = parts[0], parts[1]

    # Every N minutes
    if minute.startswith("*/") and hour == "*":
        interval = int(minute.replace("*/", ""))
        next_min = ((now.minute // interval) + 1) * interval
        if next_min >= 60:
            delta_min = 60 - now.minute + (next_min - 60)
        else:
            delta_min = next_min - now.minute
        return f"~{delta_min} min"

    # Specific minutes each hour
    if "," in minute and hour == "*":
        mins = sorted(int(m) for m in minute.split(","))
        for m in mins:
            if m > now.minute:
                return f"~{m - now.minute} min"
        return f"~{60 - now.minute + mins[0]} min"

    return None


def _last_run_info():
    """Get last run info from cron audit output files."""
    if not AUDIT_CRON_DIR.exists():
        return {}

    # Get the most recent output files
    files = sorted(AUDIT_CRON_DIR.glob("20*.yaml"), reverse=True)
    if not files:
        return {}

    info = {}
    for f in files[:5]:  # Check last 5 files for section coverage
        try:
            data = yaml.safe_load(f.read_text())
            if not data:
                continue
            sections = data.get("sections", "")
            ts = data.get("timestamp", "")
            summary = data.get("summary", {})
            info[sections] = {
                "timestamp": ts,
                "pass": summary.get("pass", 0),
                "warn": summary.get("warn", 0),
                "fail": summary.get("fail", 0),
                "file": f.name,
            }
        except Exception:
            continue

    return info


def _match_job_to_output(job, run_info):
    """Try to match a job to its last run output."""
    cmd = job.get("command", "")

    # Extract --section value
    m = re.search(r"--section\s+(\S+)", cmd)
    if m:
        section_key = m.group(1)
        # Try exact match first
        if section_key in run_info:
            return run_info[section_key]
        # Try partial match
        for key, val in run_info.items():
            if section_key in key or key in section_key:
                return val

    # Full audit (no --section)
    if "audit" in cmd and "--section" not in cmd and "--cron" in cmd:
        # Full audit writes to main audit file, not cron dir
        audit_file = PROJECT_ROOT / ".context" / "audits" / "2026-03-12.yaml"
        if audit_file.exists():
            try:
                data = yaml.safe_load(audit_file.read_text())
                summary = data.get("summary", {})
                return {
                    "timestamp": data.get("timestamp", ""),
                    "pass": summary.get("pass", 0),
                    "warn": summary.get("warn", 0),
                    "fail": summary.get("fail", 0),
                }
            except Exception:
                pass

    return None


def _time_ago(timestamp_str):
    """Convert ISO timestamp to relative time string."""
    if not timestamp_str:
        return "unknown"
    try:
        ts = datetime.fromisoformat(str(timestamp_str).replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        delta = now - ts
        minutes = int(delta.total_seconds() / 60)
        if minutes < 1:
            return "just now"
        if minutes < 60:
            return f"{minutes} min ago"
        hours = minutes // 60
        if hours < 24:
            return f"{hours}h ago"
        return f"{hours // 24}d ago"
    except (ValueError, TypeError):
        return "unknown"


@bp.route("/cron")
def cron_registry():
    """Cron job registry page."""
    jobs = _parse_cron_files()
    run_info = _last_run_info()

    # Enrich jobs with last run data
    for job in jobs:
        output = _match_job_to_output(job, run_info)
        if output:
            job["last_run"] = _time_ago(output.get("timestamp"))
            job["last_pass"] = output.get("pass", 0)
            job["last_warn"] = output.get("warn", 0)
            job["last_fail"] = output.get("fail", 0)
            job["has_output"] = True
        else:
            job["last_run"] = "no data"
            job["has_output"] = False

    # Summary stats
    total = len(jobs)
    local_count = sum(1 for j in jobs if j.get("is_local"))
    has_output = sum(1 for j in jobs if j.get("has_output"))

    return render_page(
        "cron.html",
        page_title="Scheduled Jobs",
        jobs=jobs,
        total=total,
        local_count=local_count,
        has_output_count=has_output,
    )
