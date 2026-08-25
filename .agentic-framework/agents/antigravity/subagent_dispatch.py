#!/usr/bin/env python3
"""
subagent_dispatch.py — AEF Subagent Governance & Dispatch Helper for Antigravity

Automates preparing, scoping, and reconciling subagents spawned in Antigravity
under full AEF governance rules (P-002, task-locking, TermLink tracking).

Usage:
  python3 subagent_dispatch.py prepare --task T-XXX --role "Researcher" --prompt "Investigate auth"
  python3 subagent_dispatch.py reconcile --task T-XXX --summary "Research complete"
"""

import sys
import os
import json
import argparse
from pathlib import Path

def prepare_dispatch(task_id: str, role: str, prompt: str, project_root: Path):
    # Verify task is active
    task_file = None
    for d in ["active", "completed"]:
        candidate = project_root / ".tasks" / d / f"{task_id}*.md"
        matches = list(project_root.glob(f".tasks/{d}/{task_id}*.md"))
        if matches:
            task_file = matches[0]
            break

    if not task_file or "active" not in str(task_file):
        return {
            "ok": False,
            "error": f"Task {task_id} is not active in .tasks/active/."
        }

    # Prepare TermLink session tag if termlink is available
    tl_session = f"subagent-{task_id.lower()}"

    enriched_prompt = f"""=== AEF SUBAGENT BOUNDARY ===
Task ID: {task_id}
Role: {role}
Project Root: {project_root}
TermLink Session: {tl_session}

=== INSTRUCTIONS ===
1. All changes must reference task {task_id}.
2. Comply with Tier-0 safety (no destructive commands).
3. Log major findings or learnings.

=== WORK PROMPT ===
{prompt}
"""

    return {
        "ok": True,
        "task_id": task_id,
        "role": role,
        "termlink_session": tl_session,
        "subagent_invoke_args": {
            "TypeName": "self",
            "Role": role,
            "Prompt": enriched_prompt,
            "Workspace": "share"
        }
    }

def reconcile_dispatch(task_id: str, summary: str, project_root: Path):
    # Post result to AEF bus
    bus_dir = project_root / ".context" / "bus"
    bus_dir.mkdir(parents=True, exist_ok=True)
    
    bus_event = {
        "event": "subagent_complete",
        "task_id": task_id,
        "summary": summary,
        "timestamp": os.environ.get("TIMESTAMP", "")
    }
    
    event_file = bus_dir / f"event-{task_id}.json"
    with open(event_file, "w") as f:
        json.dump(bus_event, f, indent=2)

    return {
        "ok": True,
        "reconciled_task": task_id,
        "bus_event": str(event_file)
    }

def main():
    parser = argparse.ArgumentParser(description="AEF Antigravity Subagent Governance")
    subparsers = parser.add_subparsers(dest="command")

    prep_p = subparsers.add_parser("prepare")
    prep_p.add_argument("--task", required=True, help="Task ID (e.g. T-071)")
    prep_p.add_argument("--role", default="Worker", help="Subagent role")
    prep_p.add_argument("--prompt", required=True, help="Work instructions")
    prep_p.add_argument("--project", default=os.getcwd(), help="Project root")

    rec_p = subparsers.add_parser("reconcile")
    rec_p.add_argument("--task", required=True, help="Task ID")
    rec_p.add_argument("--summary", required=True, help="Outcome summary")
    rec_p.add_argument("--project", default=os.getcwd(), help="Project root")

    args = parser.parse_args()
    proj = Path(args.project).resolve()

    if args.command == "prepare":
        res = prepare_dispatch(args.task, args.role, args.prompt, proj)
        print(json.dumps(res, indent=2))
    elif args.command == "reconcile":
        res = reconcile_dispatch(args.task, args.summary, proj)
        print(json.dumps(res, indent=2))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
