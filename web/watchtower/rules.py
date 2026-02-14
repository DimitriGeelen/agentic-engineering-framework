# web/watchtower/rules.py
"""Watchtower detection rules — challenge, opportunity, and strength rules.

Each rule function takes an `inputs` dict (from scanner.gather_inputs) and
returns a list of recommendation dicts for the appropriate output section.

Rule output format:
    {
        "id": "REC-001",        # Unique per scan
        "type": "stale_task",   # Rule type
        "summary": "...",       # Human-readable
        "recommended_action": {"command": "fw ...", "args": "..."},
        "priority": "high|medium|low",
        "priority_factors": [{"rule": "...", "detail": "..."}],
    }
"""

import re
from datetime import date, datetime, timezone


# ---------------------------------------------------------------------------
# ID counters (reset per scan)
# ---------------------------------------------------------------------------

_counters: dict[str, int] = {}


def _next_id(prefix: str) -> str:
    """Generate next sequential ID for a prefix (REC, FRA, OPP, RSK)."""
    _counters[prefix] = _counters.get(prefix, 0) + 1
    return f"{prefix}-{_counters[prefix]:03d}"


def _reset_counters():
    """Reset ID counters — call at start of each scan."""
    _counters.clear()


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def run_all_rules(inputs: dict) -> tuple[list, list, list, list]:
    """Run all detection rules. Returns (needs_decision, framework_recommends,
    opportunities, risks)."""
    _reset_counters()

    needs_decision = []
    framework_recommends = []
    opportunities = []
    risks = []

    # Challenge rules (§5.1)
    framework_recommends += check_stale_tasks(inputs)
    needs_decision += check_unresolved_healing(inputs)
    risks += check_traceability_drift(inputs)
    risks += check_audit_regression(inputs)
    needs_decision += check_gap_triggers(inputs)
    needs_decision += check_novel_failures(inputs)

    # Opportunity rules (§5.2)
    needs_decision += check_graduation_candidates(inputs)
    needs_decision += check_dead_letter_practices(inputs)
    opportunities += check_pattern_consolidation(inputs)
    opportunities += check_escalation_advancement(inputs)

    # Strength rules (§5.3)
    needs_decision += check_mitigation_ineffectiveness(inputs)

    return needs_decision, framework_recommends, opportunities, risks


# ---------------------------------------------------------------------------
# Challenge rules (§5.1)
# ---------------------------------------------------------------------------

def check_stale_tasks(inputs: dict) -> list:
    """Tasks in started-work with no update > threshold.
    Staleness threshold = 6x avg task velocity, min 7 days, default 14.
    Output section: framework_recommends
    """
    threshold = compute_stale_threshold(inputs)
    results = []
    now = datetime.now(timezone.utc)

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "started-work":
            continue
        last_update = _parse_datetime(task.get("last_update"))
        if not last_update:
            continue
        days = (now - last_update).days
        if days >= threshold:
            results.append({
                "id": _next_id("FRA"),
                "type": "stale_task",
                "summary": f"{task['id']} has had no update for {days} days",
                "recommended_action": {
                    "command": "fw task update",
                    "args": f"{task['id']} --add-note 'Flagged as stale by scan'",
                },
                "priority": "medium",
                "priority_factors": [{
                    "rule": "stale_detection",
                    "detail": (f"{days} days since last update "
                               f"(threshold: {threshold} days)"),
                }],
            })
    return results


def compute_stale_threshold(inputs: dict) -> int:
    """6x average task velocity, min 7, default 14."""
    completed = inputs.get("completed_tasks", [])
    if len(completed) < 3:
        return 14

    durations = []
    for task in completed:
        created = _parse_datetime(task.get("created"))
        finished = _parse_datetime(task.get("date_finished"))
        if created and finished:
            days = (finished - created).days
            if days >= 0:
                durations.append(days)

    if not durations:
        return 14

    avg = sum(durations) / len(durations)
    return max(7, int(avg * 6))


def check_unresolved_healing(inputs: dict) -> list:
    """Tasks in issues status with no resolution > 7 days.
    Output section: needs_decision
    """
    results = []
    now = datetime.now(timezone.utc)

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "issues":
            continue
        last_update = _parse_datetime(task.get("last_update"))
        if not last_update:
            continue
        days = (now - last_update).days
        if days >= 7:
            results.append({
                "id": _next_id("REC"),
                "type": "unresolved_healing",
                "summary": (f"{task['id']} has been in issues status "
                            f"for {days} days with no resolution"),
                "evidence": {"task": task["id"], "days_in_issues": days},
                "suggested_action": {
                    "command": "fw healing diagnose",
                    "args": task["id"],
                },
                "priority": "high",
                "priority_factors": [{
                    "rule": "unresolved_healing",
                    "detail": f"{days} days in issues (threshold: 7 days)",
                }],
            })
    return results


def check_traceability_drift(inputs: dict) -> list:
    """Last N commits lack task references. Output section: risks"""
    git_log = inputs.get("git_log", [])
    if not git_log:
        return []

    task_pattern = re.compile(r"T-\d{3}")

    # Check last 5 commits for drift
    recent = git_log[:5]
    untraced = [line for line in recent if not task_pattern.search(line)]

    if len(untraced) >= 2:
        return [{
            "id": _next_id("RSK"),
            "type": "traceability_drift",
            "summary": (f"Last {len(recent)} commits: {len(untraced)} "
                        f"lack task references"),
            "severity": "medium" if len(untraced) < 4 else "high",
            "suggested_action": (
                "Run fw audit to verify; ensure git hooks are installed"
            ),
        }]
    return []


def check_audit_regression(inputs: dict) -> list:
    """Current audit score worse than previous. Output section: risks"""
    audits = inputs.get("audits", [])
    if len(audits) < 2:
        return []

    current = audits[0].get("summary", {})
    previous = audits[1].get("summary", {})

    curr_fail = current.get("fail", 0)
    prev_fail = previous.get("fail", 0)
    curr_warn = current.get("warn", 0)
    prev_warn = previous.get("warn", 0)

    if curr_fail > prev_fail or (curr_fail == prev_fail and
                                  curr_warn > prev_warn):
        return [{
            "id": _next_id("RSK"),
            "type": "audit_regression",
            "summary": (f"Audit regression: {curr_fail}F/{curr_warn}W "
                        f"(was {prev_fail}F/{prev_warn}W)"),
            "severity": "high" if curr_fail > prev_fail else "medium",
            "suggested_action": "Run fw audit to see details",
        }]
    return []


def check_gap_triggers(inputs: dict) -> list:
    """Gap evidence approaching decision trigger threshold (>80%).
    Output section: needs_decision
    """
    results = []
    gaps = inputs.get("gaps", {})
    if isinstance(gaps, dict):
        gaps = gaps.get("gaps", [])

    for gap in gaps:
        if gap.get("status") != "watching":
            continue

        trigger_check = gap.get("trigger_check", {})
        if not isinstance(trigger_check, dict):
            continue

        if trigger_check.get("type") == "percentage":
            current = trigger_check.get("current", 0)
            threshold = trigger_check.get("threshold", 100)
            if threshold > 0 and current >= threshold * 0.8:
                pct = round(current / threshold * 100)
                results.append({
                    "id": _next_id("REC"),
                    "type": "gap_escalation",
                    "summary": (f"{gap['id']} at {pct}% trigger threshold"
                                f" — {gap.get('title', '')}"),
                    "evidence": {
                        "current": current,
                        "threshold": threshold,
                    },
                    "suggested_action": {
                        "command": "fw task create",
                        "args": (f"--name 'Address gap {gap['id']}' "
                                 f"--type build --owner human"),
                    },
                    "priority": "high" if pct >= 90 else "medium",
                    "priority_factors": [{
                        "rule": "gap_trigger_approaching",
                        "detail": f"{pct}% of threshold (>80% triggers rec)",
                    }],
                })
    return results


def check_novel_failures(inputs: dict) -> list:
    """Tasks in issues with no matching pattern in patterns.yaml.
    Output section: needs_decision
    """
    results = []
    patterns = inputs.get("patterns", {})
    known_mitigations = set()

    for key in ("failure_patterns", "success_patterns",
                "antifragile_patterns", "workflow_patterns"):
        for p in patterns.get(key, []):
            pattern_text = p.get("pattern", "").lower()
            mitigation = p.get("mitigation", "").lower()
            if pattern_text:
                known_mitigations.add(pattern_text)
            if mitigation:
                known_mitigations.add(mitigation)

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "issues":
            continue

        task_text = (
            task.get("name", "") + " " + task.get("_body", "")
        ).lower()

        matched = any(
            pattern in task_text
            for pattern in known_mitigations
            if len(pattern) > 3
        )

        if not matched:
            results.append({
                "id": _next_id("REC"),
                "type": "novel_failure",
                "summary": (f"{task['id']} entered issues with failure "
                            f"not matching any known pattern"),
                "evidence": {
                    "task": task["id"],
                    "name": task.get("name", ""),
                },
                "suggested_action": "Diagnose and capture as new pattern",
                "priority": "high",
                "priority_factors": [{
                    "rule": "novel_failure_detection",
                    "detail": "No pattern in patterns.yaml matches",
                }],
            })
    return results


# ---------------------------------------------------------------------------
# Opportunity rules (§5.2)
# ---------------------------------------------------------------------------

def check_graduation_candidates(inputs: dict) -> list:
    """Learnings that appeared in 3+ tasks — ready to graduate to practice.
    Output section: needs_decision
    """
    results = []
    learnings = inputs.get("learnings", {}).get("learnings", [])

    for learning in learnings:
        applied_in = learning.get("applied_in", [])
        if len(applied_in) >= 3:
            results.append({
                "id": _next_id("REC"),
                "type": "graduation",
                "summary": (f"Learning {learning['id']} appeared in "
                            f"{len(applied_in)} tasks — ready to graduate"),
                "evidence": applied_in,
                "rationale": "Framework threshold is 3+ for graduation",
                "suggested_action": {
                    "command": "fw task create",
                    "args": (f"--name 'Graduate {learning['id']} to practice'"
                             f" --type refactor --owner human"),
                },
                "priority": "medium",
                "priority_factors": [{
                    "rule": "graduation_threshold",
                    "detail": (f"{len(applied_in)} occurrences "
                               f"(threshold: 3+)"),
                }],
            })
    return results


def check_dead_letter_practices(inputs: dict) -> list:
    """Practices with 0 applications and created >14 days ago.
    Output section: needs_decision
    """
    results = []
    practices = inputs.get("practices", {}).get("practices", [])
    now = datetime.now(timezone.utc)

    for practice in practices:
        if practice.get("applications", 1) > 0:
            continue
        if practice.get("status") != "active":
            continue

        origin_date = _parse_datetime(practice.get("origin_date"))
        if not origin_date:
            continue

        days = (now - origin_date).days
        if days >= 14:
            results.append({
                "id": _next_id("REC"),
                "type": "dead_letter_practice",
                "summary": (f"Practice {practice['id']} has 0 applications "
                            f"since creation {days} days ago"),
                "evidence": {
                    "practice_id": practice["id"],
                    "name": practice.get("name", ""),
                    "created": str(practice.get("origin_date", "")),
                    "applications": 0,
                },
                "suggested_action": (f"Review {practice['id']} — "
                                     f"is it wrong, irrelevant, or unenforced?"),
                "priority": "low",
                "priority_factors": [{
                    "rule": "practice_adoption",
                    "detail": (f"0 applications, {days} days since "
                               f"graduation (threshold: 14 days)"),
                }],
            })
    return results


def check_pattern_consolidation(inputs: dict) -> list:
    """3+ success patterns sharing theme keywords.
    Output section: opportunities
    """
    results = []
    patterns = inputs.get("patterns", {})
    success = patterns.get("success_patterns", [])

    if len(success) < 3:
        return []

    words_per_pattern = {}
    for p in success:
        text = (p.get("pattern", "") + " " + p.get("description", "")).lower()
        words = set(w for w in re.findall(r"\w+", text) if len(w) > 4)
        words_per_pattern[p.get("id", "")] = words

    ids = list(words_per_pattern.keys())
    for i, id_a in enumerate(ids):
        overlapping = [id_a]
        for id_b in ids[i + 1:]:
            overlap = words_per_pattern[id_a] & words_per_pattern[id_b]
            if len(overlap) >= 2:
                overlapping.append(id_b)
        if len(overlapping) >= 3:
            results.append({
                "id": _next_id("OPP"),
                "type": "pattern_consolidation",
                "summary": (f"{len(overlapping)} success patterns share "
                            f"common theme — candidate for practice"),
                "evidence": overlapping,
                "suggested_action": "Review patterns for practice extraction",
                "priority": "low",
            })
            break

    return results


def check_escalation_advancement(inputs: dict) -> list:
    """Patterns at current escalation step for 3+ occurrences.
    Output section: opportunities
    Requires patterns to have: escalation_step, occurrences_at_step fields.
    """
    results = []
    patterns = inputs.get("patterns", {})
    step_order = ["A", "B", "C", "D"]

    for key in ("failure_patterns", "success_patterns",
                "antifragile_patterns", "workflow_patterns"):
        for p in patterns.get(key, []):
            step = p.get("escalation_step")
            occurrences = p.get("occurrences_at_step", 0)
            if not step or occurrences < 3:
                continue
            step_idx = step_order.index(step) if step in step_order else -1
            if step_idx < 0 or step_idx >= len(step_order) - 1:
                continue
            next_step = step_order[step_idx + 1]
            results.append({
                "id": _next_id("OPP"),
                "type": "escalation_advancement",
                "summary": (f"Pattern {p.get('id', '?')} at step {step} "
                            f"for {occurrences} occurrences — advance "
                            f"to step {next_step}"),
                "evidence": {
                    "pattern": p.get("id"),
                    "current_step": step,
                    "occurrences_at_step": occurrences,
                },
                "suggested_action": (f"Advance {p.get('id', '?')} to "
                                     f"step {next_step}"),
                "priority": "low",
            })
    return results


# ---------------------------------------------------------------------------
# Strength rules (§5.3)
# ---------------------------------------------------------------------------

def check_mitigation_ineffectiveness(inputs: dict) -> list:
    """Patterns where mitigation was applied but failure recurred.
    Output section: needs_decision
    """
    results = []
    patterns = inputs.get("patterns", {})
    failure_patterns = patterns.get("failure_patterns", [])

    if not failure_patterns:
        return results

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "issues":
            continue
        task_text = (task.get("_body", "")).lower()

        for fp in failure_patterns:
            mitigation = fp.get("mitigation", "").lower()
            pattern_text = fp.get("pattern", "").lower()
            if (mitigation and len(mitigation) > 5 and
                    mitigation in task_text and
                    pattern_text and pattern_text in task_text):
                results.append({
                    "id": _next_id("REC"),
                    "type": "mitigation_ineffective",
                    "summary": (f"Pattern {fp['id']} mitigation applied in "
                                f"{task['id']} but failure recurred"),
                    "evidence": {
                        "task": task["id"],
                        "pattern": fp["id"],
                    },
                    "suggested_action": (f"Review {fp['id']} mitigation — "
                                         f"may need escalation"),
                    "priority": "medium",
                    "priority_factors": [{
                        "rule": "mitigation_ineffectiveness",
                        "detail": (f"{fp['id']} mitigation was applied "
                                   f"but failure recurred"),
                    }],
                })
    return results


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_datetime(value) -> datetime | None:
    """Parse a datetime value from YAML (string, datetime, or date object)."""
    if value is None or value == "null":
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, date) and not isinstance(value, datetime):
        # YAML parses bare dates (e.g. 2026-01-20) as date objects
        return datetime(value.year, value.month, value.day, tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except (ValueError, TypeError):
            return None
    return None
