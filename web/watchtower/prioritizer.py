# web/watchtower/prioritizer.py
"""Work queue prioritization for the Watchtower scan engine.

Orders active tasks by: issues > stale > active (by recency) > captured.
Session continuity boosts tasks from the last handover.
"""
from __future__ import annotations


import re
from datetime import datetime, timezone


# Status priority weights (lower = higher priority)
STATUS_PRIORITY = {
    "issues": 0,
    "started-work": 1,
    "captured": 2,
}


def prioritize_work_queue(inputs: dict) -> list:
    """Return a prioritized list of active tasks."""
    tasks = inputs.get("active_tasks", [])
    if not tasks:
        return []

    # Extract session continuity data from handover
    handover_tasks = _extract_handover_tasks(inputs.get("handover"))

    scored = []
    for task in tasks:
        task_id = task.get("id", "")
        status = task.get("status", "captured")
        name = task.get("name", "")

        # Base score from status
        base_score = STATUS_PRIORITY.get(status, 2)

        # Recency score (more recent update = lower score = higher priority)
        last_update = _parse_datetime(task.get("last_update"))
        now = datetime.now(timezone.utc)
        recency_days = (now - last_update).days if last_update else 999

        # Priority factors
        factors = []
        factors.append({
            "rule": "status",
            "detail": f"Status: {status}",
        })

        # Session continuity boost
        continuity_boost = 0
        if task_id in handover_tasks:
            continuity_boost = -0.5  # Boost priority
            factors.append({
                "rule": "session_continuity",
                "detail": "Listed in last handover",
            })

        # Compute final score
        score = base_score + continuity_boost + (recency_days * 0.01)

        scored.append({
            "task_id": task_id,
            "name": name,
            "status": status,
            "priority": len(scored) + 1,  # Will be reassigned after sort
            "priority_factors": factors,
            "_score": score,
        })

    # Sort by score (ascending = higher priority first)
    scored.sort(key=lambda x: x["_score"])

    # Assign final priority numbers
    for i, item in enumerate(scored):
        item["priority"] = i + 1
        del item["_score"]

    return scored


def _extract_handover_tasks(handover: str | None) -> set:
    """Extract task IDs mentioned in the handover."""
    if not handover:
        return set()
    return set(re.findall(r"T-\d{3}", handover))


def _parse_datetime(value) -> datetime | None:
    """Parse datetime from YAML value."""
    if value is None or value == "null":
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            return None
    return None
