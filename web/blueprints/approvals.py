"""Approvals blueprint — Tier 0 approval queue and Human AC approvals (T-611)."""

import os
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("approvals", __name__)

APPROVALS_DIR = PROJECT_ROOT / ".context" / "approvals"
APPROVAL_FILE = PROJECT_ROOT / ".context" / "working" / ".tier0-approval"

# Approvals older than this are considered expired (seconds)
EXPIRY_SECONDS = 3600  # 1 hour


def _load_pending_approvals():
    """Load all pending approval YAML files. Returns list of dicts."""
    approvals = []
    if not APPROVALS_DIR.exists():
        return approvals

    now = time.time()
    for f in sorted(APPROVALS_DIR.glob("pending-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if not isinstance(data, dict):
                continue
            data["_file"] = f.name

            # Check expiry
            ts = data.get("timestamp", "")
            if ts:
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    age = now - dt.timestamp()
                    if age > EXPIRY_SECONDS:
                        data["status"] = "expired"
                except (ValueError, OSError):
                    pass

            approvals.append(data)
        except yaml.YAMLError:
            continue
    return approvals


def _load_resolved_approvals():
    """Load recently resolved (approved/rejected) approvals."""
    resolved = []
    if not APPROVALS_DIR.exists():
        return resolved

    for f in sorted(APPROVALS_DIR.glob("resolved-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if isinstance(data, dict):
                resolved.append(data)
        except yaml.YAMLError:
            continue
    return resolved[:20]  # Last 20


@bp.route("/approvals")
def approvals():
    pending = _load_pending_approvals()
    resolved = _load_resolved_approvals()

    # Count by status
    active_count = sum(1 for a in pending if a.get("status") == "pending")

    return render_page(
        "approvals.html",
        page_title="Approvals",
        pending=pending,
        resolved=resolved,
        active_count=active_count,
    )


@bp.route("/api/approvals/decide", methods=["POST"])
def decide_approval():
    """Approve or reject a pending Tier 0 request.

    This endpoint is the unfakeable surface — only the web UI (human) can POST here.
    It writes the approval token that check-tier0.sh reads on retry.
    """
    command_hash = request.form.get("command_hash", "").strip()
    decision = request.form.get("decision", "").strip()
    feedback = request.form.get("feedback", "").strip()

    if not command_hash:
        return '<p style="color:var(--pico-del-color);">Missing command hash</p>', 400
    if decision not in ("approved", "rejected"):
        return '<p style="color:var(--pico-del-color);">Invalid decision</p>', 400

    # Find the pending request
    pending_file = APPROVALS_DIR / f"pending-{command_hash[:12]}.yaml"
    if not pending_file.exists():
        return '<p style="color:var(--pico-del-color);">No pending request found</p>', 404

    try:
        with open(pending_file) as fh:
            data = yaml.safe_load(fh)
    except yaml.YAMLError:
        return '<p style="color:var(--pico-del-color);">Cannot read request</p>', 500

    now_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    if decision == "approved":
        # Write the approval token that check-tier0.sh expects
        # Format: <command_hash> <unix_timestamp>
        APPROVAL_FILE.parent.mkdir(parents=True, exist_ok=True)
        APPROVAL_FILE.write_text(f"{command_hash} {int(time.time())}\n")

    # Move pending → resolved
    data["status"] = decision
    data["response"] = {
        "decision": decision,
        "feedback": feedback or None,
        "responded_at": now_ts,
        "mechanism": "watchtower",
    }

    resolved_file = APPROVALS_DIR / f"resolved-{command_hash[:12]}.yaml"
    with open(resolved_file, "w") as fh:
        yaml.dump(data, fh, default_flow_style=False, sort_keys=False)

    # Remove pending file
    pending_file.unlink(missing_ok=True)

    status_color = "var(--pico-ins-color)" if decision == "approved" else "var(--pico-del-color)"
    status_icon = "Approved" if decision == "approved" else "Rejected"
    return f'<p style="color:{status_color};">{status_icon}. Agent can retry the command.</p>'
