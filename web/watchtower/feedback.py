# web/watchtower/feedback.py
"""Feedback and antifragility metrics for the Watchtower scan engine.

Computes:
- Pattern counts and growth since last scan
- Mitigation effectiveness tracking
- Practice adoption rates
- Scan recommendation accuracy (from decisions.yaml)
"""


def compute_feedback(inputs: dict) -> dict:
    """Compute antifragility metrics from project state."""
    patterns = inputs.get("patterns", {})
    practices = inputs.get("practices", {}).get("practices", [])
    learnings = inputs.get("learnings", {}).get("learnings", [])
    decisions = inputs.get("decisions", {}).get("decisions", [])
    previous_scan = inputs.get("previous_scan")

    # Pattern counts
    total_patterns = sum(
        len(patterns.get(k, []))
        for k in ("failure_patterns", "success_patterns",
                   "antifragile_patterns", "workflow_patterns")
    )

    # Patterns added since last scan
    prev_patterns = 0
    if previous_scan and isinstance(previous_scan, dict):
        prev_af = previous_scan.get("antifragility", {})
        prev_patterns = prev_af.get("patterns_total", total_patterns)
    patterns_added = max(0, total_patterns - prev_patterns)

    # Practice adoption
    active_practices = [p for p in practices if p.get("status") == "active"]
    dead_letter = [
        p for p in active_practices
        if p.get("applications", 0) == 0
    ]

    # Learnings graduated (those with 3+ applied_in)
    graduated = [
        l for l in learnings
        if len(l.get("applied_in", [])) >= 3
    ]

    # Scan accuracy from decisions (decisions with source=scan)
    scan_decisions = [
        d for d in decisions
        if d.get("source") == "scan"
    ]
    approved = len([
        d for d in scan_decisions
        if "approved" in d.get("decision", "").lower()
        or "accept" in d.get("decision", "").lower()
    ])
    dismissed = len([
        d for d in scan_decisions
        if "deferred" in d.get("decision", "").lower()
        or "dismiss" in d.get("decision", "").lower()
    ])
    total_scan_decisions = approved + dismissed

    return {
        "patterns_total": total_patterns,
        "patterns_added_since_last_scan": patterns_added,
        "learnings_graduated": len(graduated),
        "dead_letter_practices": len(dead_letter),
        "practice_adoption": {
            "active": len(active_practices),
            "with_applications": len(active_practices) - len(dead_letter),
        },
        "scan_accuracy": {
            "recommendations_approved": approved,
            "recommendations_dismissed": dismissed,
            "approval_rate": (
                round(approved / total_scan_decisions * 100)
                if total_scan_decisions > 0 else None
            ),
        },
    }
