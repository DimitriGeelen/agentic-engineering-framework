"""Cron registry blueprint — scheduled job visibility and controls for Watchtower (T-447, T-448)."""

import glob
import json
import logging
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import yaml
from flask import Blueprint, jsonify, request

logger = logging.getLogger(__name__)

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("cron", __name__)

# Cron files managed by the framework
CRON_DIR = "/etc/cron.d"
CRON_PREFIX = "agentic-"

# Registry YAML — structured source of truth (T-448)
REGISTRY_PATH = PROJECT_ROOT / ".context" / "cron-registry.yaml"

# Where cron audit output lands
AUDIT_CRON_DIR = PROJECT_ROOT / ".context" / "audits" / "cron"

# FW binary for generate command
FW_BIN = PROJECT_ROOT / "bin" / "fw"


# ---------------------------------------------------------------------------
# Registry I/O
# ---------------------------------------------------------------------------


def _load_registry() -> dict:
    """Load cron registry YAML. Returns dict with 'jobs' list."""
    if not REGISTRY_PATH.exists():
        return {"jobs": []}
    try:
        data = yaml.safe_load(REGISTRY_PATH.read_text()) or {}
        if "jobs" not in data:
            data["jobs"] = []
        return data
    except Exception as e:
        logger.warning("Failed to parse cron registry %s: %s", REGISTRY_PATH, e)
        return {"jobs": []}


def _save_registry(data: dict) -> None:
    """Write cron registry YAML back to disk."""
    REGISTRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    REGISTRY_PATH.write_text(yaml.dump(data, default_flow_style=False, sort_keys=False))


def _find_job(data: dict, job_id: str) -> Optional[dict]:
    """Find a job by ID in the registry."""
    for job in data.get("jobs", []):
        if job.get("id") == job_id:
            return job
    return None


# ---------------------------------------------------------------------------
# Schedule parsing helpers (kept for fallback / enrichment)
# ---------------------------------------------------------------------------


def _humanize_schedule(schedule: str) -> str:
    """Convert a cron expression to a human-readable approximation."""
    parts = schedule.split()
    if len(parts) != 5:
        return schedule

    minute, hour, dom, mon, dow = parts

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


def _next_run_approx(schedule: str) -> Optional[str]:
    """Approximate next run time from cron expression."""
    parts = schedule.split()
    if len(parts) != 5:
        return None

    now = datetime.now(timezone.utc)
    minute, hour = parts[0], parts[1]

    if minute.startswith("*/") and hour == "*":
        interval = int(minute.replace("*/", ""))
        next_min = ((now.minute // interval) + 1) * interval
        if next_min >= 60:
            delta_min = 60 - now.minute + (next_min - 60)
        else:
            delta_min = next_min - now.minute
        return f"~{delta_min} min"

    if "," in minute and hour == "*":
        mins = sorted(int(m) for m in minute.split(","))
        for m in mins:
            if m > now.minute:
                return f"~{m - now.minute} min"
        return f"~{60 - now.minute + mins[0]} min"

    return None


def _last_run_info() -> dict:
    """Get last run info from cron audit output files."""
    if not AUDIT_CRON_DIR.exists():
        return {}

    files = sorted(AUDIT_CRON_DIR.glob("20*.yaml"), reverse=True)
    if not files:
        return {}

    info = {}
    for f in files[:5]:
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
        except Exception as e:
            logger.warning("Failed to parse cron audit file %s: %s", f, e)
            continue

    return info


def _match_job_to_output(job: dict, run_info: dict) -> Optional[dict]:
    """Try to match a job to its last run output."""
    cmd = job.get("command", "")

    m = re.search(r"--section\s+(\S+)", cmd)
    if m:
        section_key = m.group(1)
        if section_key in run_info:
            return run_info[section_key]
        for key, val in run_info.items():
            if section_key in key or key in section_key:
                return val

    if "audit" in cmd and "--section" not in cmd and "--cron" in cmd:
        audit_dir = PROJECT_ROOT / ".context" / "audits"
        for af in sorted(audit_dir.glob("20*.yaml"), reverse=True):
            try:
                data = yaml.safe_load(af.read_text())
                summary = data.get("summary", {})
                return {
                    "timestamp": data.get("timestamp", ""),
                    "pass": summary.get("pass", 0),
                    "warn": summary.get("warn", 0),
                    "fail": summary.get("fail", 0),
                }
            except Exception as e:
                logger.warning("Failed to parse audit file %s: %s", af, e)
                continue

    return None


def _time_ago(timestamp_str) -> str:
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


# ---------------------------------------------------------------------------
# Page route
# ---------------------------------------------------------------------------


@bp.route("/cron")
def cron_registry():
    """Cron job registry page — reads from registry YAML."""
    data = _load_registry()
    jobs = data.get("jobs", [])
    run_info = _last_run_info()

    # Enrich each job with computed fields
    for job in jobs:
        schedule = job.get("schedule", "")
        job["schedule_human"] = _humanize_schedule(schedule)
        job["next_run"] = _next_run_approx(schedule)

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

    total = len(jobs)
    active_count = sum(1 for j in jobs if j.get("status") == "active")
    paused_count = sum(1 for j in jobs if j.get("status") == "paused")
    has_output = sum(1 for j in jobs if j.get("has_output"))

    return render_page(
        "cron.html",
        page_title="Scheduled Jobs",
        jobs=jobs,
        total=total,
        active_count=active_count,
        paused_count=paused_count,
        has_output_count=has_output,
    )


# ---------------------------------------------------------------------------
# API endpoints (T-448)
# ---------------------------------------------------------------------------


@bp.route("/api/v1/cron/jobs/<job_id>/pause", methods=["POST"])
def pause_job(job_id: str):
    """Pause a cron job — sets status to 'paused' in registry."""
    data = _load_registry()
    job = _find_job(data, job_id)
    if not job:
        return jsonify({"error": f"Job '{job_id}' not found"}), 404

    if job.get("status") == "paused":
        return jsonify({"status": "already_paused", "job": job})

    job["status"] = "paused"
    _save_registry(data)
    _regenerate_cron()

    return jsonify({"status": "paused", "job": job})


@bp.route("/api/v1/cron/jobs/<job_id>/resume", methods=["POST"])
def resume_job(job_id: str):
    """Resume a paused cron job — sets status to 'active' in registry."""
    data = _load_registry()
    job = _find_job(data, job_id)
    if not job:
        return jsonify({"error": f"Job '{job_id}' not found"}), 404

    if job.get("status") == "active":
        return jsonify({"status": "already_active", "job": job})

    job["status"] = "active"
    _save_registry(data)
    _regenerate_cron()

    return jsonify({"status": "active", "job": job})


@bp.route("/api/v1/cron/jobs/<job_id>/run", methods=["POST"])
def run_job(job_id: str):
    """Manually trigger a cron job."""
    data = _load_registry()
    job = _find_job(data, job_id)
    if not job:
        return jsonify({"error": f"Job '{job_id}' not found"}), 404

    command = job.get("command", "")
    if not command:
        return jsonify({"error": "Job has no command"}), 400

    # Resolve fw commands to the actual binary
    resolved_cmd = command
    if resolved_cmd.startswith("fw "):
        resolved_cmd = f"{FW_BIN} {resolved_cmd[3:]}"
    elif resolved_cmd.startswith("find "):
        resolved_cmd = f'cd "{PROJECT_ROOT}" && {resolved_cmd}'

    try:
        result = subprocess.run(
            resolved_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=str(PROJECT_ROOT),
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        return jsonify({
            "status": "completed",
            "exit_code": result.returncode,
            "stdout": result.stdout[-500:] if result.stdout else "",
            "stderr": result.stderr[-500:] if result.stderr else "",
        })
    except subprocess.TimeoutExpired:
        return jsonify({"status": "timeout", "error": "Command timed out after 120s"}), 504


@bp.route("/api/v1/cron/jobs/<job_id>/describe", methods=["GET"])
def describe_job(job_id: str):
    """Generate an LLM description for a cron job via Ollama."""
    data = _load_registry()
    job = _find_job(data, job_id)
    if not job:
        return jsonify({"error": f"Job '{job_id}' not found"}), 404

    # Return cached description if exists
    if job.get("description"):
        return jsonify({"description": job["description"], "cached": True})

    # Generate via Ollama
    try:
        from web.config import Config
        from web.llm.ollama_provider import OllamaProvider

        provider = OllamaProvider(host=Config.OLLAMA_HOST)
        prompt = (
            f"Describe this cron job in one sentence. Be specific about what it does.\n"
            f"Name: {job.get('name', 'unknown')}\n"
            f"Schedule: {job.get('schedule', 'unknown')}\n"
            f"Command: {job.get('command', 'unknown')}\n"
            f"Description:"
        )
        description = ""
        for chunk in provider.chat_stream(
            model=Config.PRIMARY_MODEL,
            messages=[{"role": "user", "content": prompt}],
        ):
            if chunk.type == "token":
                description += chunk.content
            elif chunk.type == "done":
                break

        description = description.strip()
        if description:
            job["description"] = description
            _save_registry(data)

        return jsonify({"description": description, "cached": False})
    except Exception as e:
        return jsonify({
            "description": job.get("description", ""),
            "error": f"Ollama unavailable: {e}",
            "cached": True,
        })


# ---------------------------------------------------------------------------
# Cron file generation
# ---------------------------------------------------------------------------


def _regenerate_cron() -> None:
    """Regenerate the crontab file from registry YAML.

    Active jobs get normal cron lines. Paused jobs are commented out.
    Writes to .context/cron/agentic-audit.crontab, then copies to /etc/cron.d/.
    """
    data = _load_registry()
    jobs = data.get("jobs", [])
    if not jobs:
        return

    project_slug = os.path.basename(str(PROJECT_ROOT)).lower()
    project_slug = re.sub(r"[^a-z0-9_-]", "-", project_slug)
    fw_path = str(FW_BIN)
    cron_source = PROJECT_ROOT / ".context" / "cron" / "agentic-audit.crontab"
    cron_install = f"/etc/cron.d/agentic-audit-{project_slug}"

    lines = [
        f"# Agentic Engineering Framework — Scheduled Jobs (managed by cron-registry.yaml)",
        f"# Source of truth: {cron_source} (git-tracked)",
        f"# Installed to: {cron_install} (copy — use 'fw audit schedule install' to sync)",
        f"# Project: {PROJECT_ROOT}",
        f"SHELL=/bin/bash",
        f"PATH=/usr/local/bin:/usr/bin:/bin",
        "",
    ]

    for job in jobs:
        schedule = job.get("schedule", "")
        command = job.get("command", "")
        name = job.get("name", "")
        status = job.get("status", "active")

        # Resolve fw commands
        if command.startswith("fw "):
            resolved = f'PROJECT_ROOT="{PROJECT_ROOT}" "{fw_path}" {command[3:]}'
        elif command.startswith("find "):
            resolved = f'cd "{PROJECT_ROOT}" && {command}'
        else:
            resolved = command

        # Add 2>/dev/null to suppress noise
        if "2>/dev/null" not in resolved:
            resolved += " 2>/dev/null"

        lines.append(f"# {name}")
        if status == "paused":
            lines.append(f"# PAUSED: {schedule} root {resolved}")
        else:
            lines.append(f"{schedule} root {resolved}")
        lines.append("")

    cron_source.parent.mkdir(parents=True, exist_ok=True)
    cron_source.write_text("\n".join(lines))

    # Try to install to /etc/cron.d/
    try:
        if os.geteuid() == 0:
            import shutil
            shutil.copy2(str(cron_source), cron_install)
            os.chmod(cron_install, 0o644)
    except Exception:
        pass  # Non-root — user must run fw audit schedule install
