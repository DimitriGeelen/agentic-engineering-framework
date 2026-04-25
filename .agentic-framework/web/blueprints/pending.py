"""Pending-updates registry blueprint — Watchtower UI for T-1268 B3.

Reads `.context/working/pending-updates.yaml` and lets humans resolve entries
that an agent registered via `fw pending register`.
"""

import logging

import yaml
from flask import Blueprint, jsonify, request

from web.shared import PROJECT_ROOT, render_page

logger = logging.getLogger(__name__)

bp = Blueprint("pending", __name__)

PENDING_FILE = PROJECT_ROOT / ".context" / "working" / "pending-updates.yaml"


def _load() -> dict:
    if not PENDING_FILE.exists():
        return {"pending_updates": []}
    with open(PENDING_FILE) as f:
        return yaml.safe_load(f) or {"pending_updates": []}


def _save(data: dict) -> None:
    PENDING_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(PENDING_FILE, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)


@bp.route("/pending")
def pending_page():
    """Pending-updates registry page."""
    data = _load()
    entries = data.get("pending_updates") or []

    # Split into pending vs resolved for display
    pending = [e for e in entries if (e.get("status") or "pending") == "pending"]
    resolved = [e for e in entries if e.get("status") == "resolved"]

    return render_page(
        "pending.html",
        page_title="Pending Updates",
        pending=pending,
        resolved=resolved,
        total_pending=len(pending),
        total_resolved=len(resolved),
    )


@bp.route("/api/v1/pending/<entry_id>/resolve", methods=["POST"])
def resolve_entry(entry_id: str):
    """Flip a pending entry to status=resolved."""
    from datetime import datetime, timezone

    note = ""
    if request.is_json:
        body = request.get_json(silent=True) or {}
        note = body.get("note", "") or ""

    data = _load()
    entries = data.get("pending_updates") or []
    found = None
    for e in entries:
        if e.get("id") == entry_id:
            found = e
            break

    if not found:
        return jsonify({"error": f"Entry '{entry_id}' not found"}), 404

    if found.get("status") == "resolved":
        return jsonify({"status": "already_resolved", "entry": found})

    found["status"] = "resolved"
    found["resolved_date"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if note:
        found["resolution_note"] = note

    _save({"pending_updates": entries})

    return jsonify({"status": "resolved", "entry": found})
