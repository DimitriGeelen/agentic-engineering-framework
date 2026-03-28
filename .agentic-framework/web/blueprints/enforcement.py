"""Enforcement blueprint — Tier 0-3 enforcement status dashboard."""

import json
import os
from pathlib import Path

import yaml
from flask import Blueprint

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("enforcement", __name__)


def _hook_status():
    """Check which Claude Code hooks are configured."""
    hooks = {"tier0": False, "tier1": False, "checkpoint": False}
    settings_file = PROJECT_ROOT / ".claude" / "settings.json"
    if settings_file.exists():
        try:
            data = json.loads(settings_file.read_text())
            pre_hooks = data.get("hooks", {}).get("PreToolUse", [])
            post_hooks = data.get("hooks", {}).get("PostToolUse", [])
            for h in pre_hooks:
                cmd = " ".join(
                    hk.get("command", "") for hk in h.get("hooks", [])
                )
                if "check-tier0" in cmd:
                    hooks["tier0"] = True
                if "check-active-task" in cmd:
                    hooks["tier1"] = True
            for h in post_hooks:
                cmd = " ".join(
                    hk.get("command", "") for hk in h.get("hooks", [])
                )
                if "checkpoint" in cmd:
                    hooks["checkpoint"] = True
        except (json.JSONDecodeError, KeyError):
            pass
    return hooks


def _git_hook_status():
    """Check which git hooks are installed."""
    hooks_dir = PROJECT_ROOT / ".git" / "hooks"
    result = {"commit_msg": False, "post_commit": False, "pre_push": False}
    if hooks_dir.exists():
        cm = hooks_dir / "commit-msg"
        if cm.exists() and os.access(cm, os.X_OK):
            content = cm.read_text(errors="replace")
            result["commit_msg"] = "Task Reference" in content
        pc = hooks_dir / "post-commit"
        if pc.exists() and os.access(pc, os.X_OK):
            result["post_commit"] = True
        pp = hooks_dir / "pre-push"
        if pp.exists() and os.access(pp, os.X_OK):
            result["pre_push"] = True
    return result


def _bypass_log():
    """Load bypass log entries."""
    log_file = PROJECT_ROOT / ".context" / "bypass-log.yaml"
    if not log_file.exists():
        return []
    try:
        data = yaml.safe_load(log_file.read_text()) or {}
        entries = data.get("bypasses", [])
        # Sort newest first
        entries.sort(key=lambda e: e.get("timestamp", ""), reverse=True)
        return entries[:20]  # Cap at 20 most recent
    except Exception:
        return []


def _enforcement_config():
    """Load enforcement config for tier descriptions."""
    config_file = PROJECT_ROOT / "011-EnforcementConfig.md"
    if not config_file.exists():
        config_file = FRAMEWORK_ROOT / "011-EnforcementConfig.md"
    if not config_file.exists():
        return {}
    try:
        text = config_file.read_text()
        data = yaml.safe_load(text)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _pending_block():
    """Check if there's a pending Tier 0 block."""
    pending = PROJECT_ROOT / ".context" / "working" / ".tier0-approval.pending"
    approval = PROJECT_ROOT / ".context" / "working" / ".tier0-approval"
    return {
        "pending": pending.exists(),
        "approved": approval.exists(),
    }


@bp.route("/enforcement")
def enforcement_dashboard():
    """Enforcement tier status dashboard."""
    claude_hooks = _hook_status()
    git_hooks = _git_hook_status()
    bypass_entries = _bypass_log()
    config = _enforcement_config()
    tier0_state = _pending_block()

    # Build tier status list
    tiers = [
        {
            "tier": 0,
            "name": "Consequential",
            "description": "Destructive commands (force push, hard reset, catastrophic delete, SQL DROP)",
            "status": "active" if claude_hooks["tier0"] else "not configured",
            "mechanism": "PreToolUse hook on Bash (check-tier0.sh)",
            "bypass": "Human approval via fw tier0 approve (one-time, 5-min expiry)",
        },
        {
            "tier": 1,
            "name": "Strict Default",
            "description": "All file modifications require an active task in focus",
            "status": "active" if claude_hooks["tier1"] else "not configured",
            "mechanism": "PreToolUse hook on Write/Edit (check-active-task.sh)",
            "bypass": "Create task or escalate to Tier 2",
        },
        {
            "tier": 2,
            "name": "Situational Bypass",
            "description": "Human-authorized single-use exceptions with mandatory logging",
            "status": "partial",
            "mechanism": "Git --no-verify + bypass log (manual)",
            "bypass": "Single-use, logged to bypass-log.yaml",
        },
        {
            "tier": 3,
            "name": "Pre-Approved",
            "description": "Read-only diagnostics and context queries (no task needed)",
            "status": "spec only",
            "mechanism": "Defined in 011-EnforcementConfig.md (not enforced by hooks)",
            "bypass": "Configured per category",
        },
    ]

    # Count bypass entries by tier
    tier0_bypasses = [b for b in bypass_entries if b.get("tier") == 0]
    other_bypasses = [b for b in bypass_entries if b.get("tier") != 0]

    return render_page(
        "enforcement.html",
        page_title="Enforcement",
        tiers=tiers,
        claude_hooks=claude_hooks,
        git_hooks=git_hooks,
        tier0_state=tier0_state,
        tier0_bypasses=tier0_bypasses,
        other_bypasses=other_bypasses,
        all_bypasses=bypass_entries,
    )
