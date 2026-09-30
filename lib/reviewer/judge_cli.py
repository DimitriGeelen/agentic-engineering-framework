#!/usr/bin/env python3
"""Dispatch independent reviewer on REVIEWER_JUDGES criteria (T-3580, slice 3).

fw reviewer judge T-XXX [--criterion N] [--dry-run] [--json]
  Task ID (T-XXXX)
  --criterion N: Specific criterion index (default: all REVIEWER_JUDGES)
  --dry-run: Print criteria and brief without dispatching
  --json: Output as JSON
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from lib.delegation import REVIEWER_JUDGES, classify, human_criteria  # noqa: E402


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_task(task_id: str, root: Path) -> dict | None:
    """Load a task file; return frontmatter + body or None if not found."""
    matches = list(root.glob(f".tasks/active/{task_id}-*.md"))
    if not matches:
        return None

    path = matches[0]
    text = path.read_text(encoding="utf-8", errors="replace")

    if not text.startswith("---"):
        return None

    lines = text.split("\n")
    end_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break

    if end_idx is None:
        return None

    try:
        import yaml

        fm = yaml.safe_load("\n".join(lines[1:end_idx]))
        body = "\n".join(lines[end_idx + 1 :])
        return {"frontmatter": fm or {}, "body": body, "path": path}
    except Exception as e:
        print(f"Error parsing task {task_id}: {e}", file=sys.stderr)
        return None


def _select_criteria(task_data: dict, criterion_n: int | None = None) -> list[dict]:
    """Select REVIEWER_JUDGES criteria from the task body.

    Returns list of {index, ac_index, text} dicts.
    """
    body = task_data["body"]
    fm = task_data["frontmatter"]

    try:
        human_crit = human_criteria(body)
    except Exception as e:
        print(f"Error extracting criteria: {e}", file=sys.stderr)
        return []

    selected = []
    for ac_idx, crit in enumerate(human_crit):
        try:
            workflow_type = fm.get("workflow_type", "")
            render_surface = False  # TODO: implement render surface detection
            classification = classify(crit, workflow_type=workflow_type, render_surface=render_surface)
            delegation_cls = classification.delegation_class
        except Exception:
            delegation_cls = None

        if delegation_cls == REVIEWER_JUDGES:
            if criterion_n is None or ac_idx == criterion_n:
                selected.append(
                    {"index": len(selected) + 1, "ac_index": ac_idx, "text": crit.title}
                )

    return selected


def _calculate_rung(task_data: dict) -> tuple[int, str]:
    """Calculate rung per IW-7 impact-risk model. Returns (rung, reason)."""
    fm = task_data["frontmatter"]

    cost_estimate = fm.get("cost_estimate", {}) or {}
    blast_radius = cost_estimate.get("blast_radius")

    bvp_scores = fm.get("bvp_scores", {}) or {}
    has_bvp = len(bvp_scores) > 0

    reason_parts = []

    if blast_radius and isinstance(blast_radius, (int, float)) and blast_radius > 5:
        rung = 5
        reason_parts.append(f"blast_radius={blast_radius}")
    elif has_bvp and (bvp_scores.get("D1", 0) > 3 or bvp_scores.get("D2", 0) > 3):
        rung = 5
        reason_parts.append("D1/D2 > 3")
    else:
        rung = 1
        reason_parts.append("default")

    return rung, "; ".join(reason_parts)


def _build_brief(task_id: str, criteria: list[dict]) -> str:
    """Build a reviewer brief (spike prompt shape) for the given criteria."""
    lines = [
        "You are an INDEPENDENT REVIEWER for the Agentic Engineering Framework.",
        "You did not produce any of the work below and owe its authors nothing.",
        "You are read-only EXCEPT for your one report file.",
        "",
        "## Your role",
        "",
        "The operator has ruled that a human is needed only for RISK:",
        "- Tier 0 / consequential actions;",
        "- irreversible actions (publishing, deploying, paying, credentials);",
        "- sovereignty and project-direction calls.",
        "",
        "Everything else goes to you. For each criterion return exactly one verdict:",
        "- **green:** verified it is met. Say how with evidence.",
        "- **amber:** mostly met. Say exactly what is needed.",
        "- **red:** not met. Say what is needed.",
        "- **escalate:** needs the human. Say why.",
        "",
        "## The criteria",
        "",
        f"Task: {task_id}",
        "",
    ]

    for crit in criteria:
        lines.append(f"{crit['index']}. [{crit['ac_index']}] {crit['text'][:80]}")

    lines.extend(
        [
            "",
            "## Output format",
            "",
            "For each criterion, write:",
            "```",
            "N. [AC] <criterion short>",
            "VERDICT: green | amber | red | escalate",
            "WHY: <what you checked, with evidence; or why a human is needed>",
            "GUIDANCE: <what is needed next, mandatory for non-green>",
            "```",
            "",
            "End with: 'Summary: N green, M amber, K red, J escalate'.",
        ]
    )

    return "\n".join(lines)


def _dispatch_reviewer(
    task_id: str, brief: str, rung: int, dry_run: bool, root: Path
) -> str | None:
    """Dispatch the reviewer via fw termlink dispatch. Returns dispatch_id or None."""
    if dry_run:
        return "dry-run-id"

    # TODO: Implement actual dispatch
    # For now, return a placeholder
    return f"dispatch-{task_id}-{_now()}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Dispatch independent reviewer on REVIEWER_JUDGES criteria"
    )
    parser.add_argument("task_id", help="Task ID (T-XXXX)")
    parser.add_argument(
        "--criterion", type=int, default=None, help="Specific criterion index"
    )
    parser.add_argument("--dry-run", action="store_true", help="Dry-run mode")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()
    root = _root()

    # Load task
    task_data = _load_task(args.task_id, root)
    if not task_data:
        print(f"Error: Task {args.task_id} not found", file=sys.stderr)
        return 1

    # Select criteria
    criteria = _select_criteria(task_data, args.criterion)

    if not criteria:
        print(f"No REVIEWER_JUDGES criteria found for {args.task_id}", file=sys.stderr)
        return 1

    # Calculate rung
    rung, rung_reason = _calculate_rung(task_data)

    # Build brief
    brief = _build_brief(args.task_id, criteria)

    # Dispatch
    dispatch_id = _dispatch_reviewer(args.task_id, brief, rung, args.dry_run, root)

    if args.json:
        result = {
            "task_id": args.task_id,
            "criteria_count": len(criteria),
            "rung": rung,
            "rung_reason": rung_reason,
            "dispatch_id": dispatch_id,
            "dry_run": args.dry_run,
        }
        print(json.dumps(result, indent=2))
    else:
        print(f"Task: {args.task_id}")
        print(f"Criteria: {len(criteria)} REVIEWER_JUDGES")
        print(f"Rung: {rung} ({rung_reason})")
        if dispatch_id and dispatch_id != "dry-run-id":
            print(f"Dispatch ID: {dispatch_id}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
