#!/usr/bin/env python3
"""Single-pass scan of active task files for audit checks.

Replaces five separate bash loops (1, 2, 5, 9, 10) that each iterate 130+ files.
Reads each file once, extracts all needed data, outputs JSON results.

Usage: python3 active-task-scan.py <tasks_dir> <reports_dir>

T-955: Merge loops 1/2/5/9/10 into single-pass Python scan.
"""

import json
import os
import re
import sys
from datetime import datetime, timezone


def scan_active_tasks(tasks_dir, reports_dir):
    active_dir = os.path.join(tasks_dir, "completed/../active").replace("completed/../", "")
    active_dir = os.path.join(tasks_dir, "active")
    if not os.path.isdir(active_dir):
        return {"compliance": {}, "quality": {}, "research": {}, "ownership": {}, "review_queue": {}, "stats": {}}

    # Results
    compliance_issues = []  # Loop 1
    quality_issues = []     # Loop 2
    research_issues = []    # Loop 5
    ownership_issues = []   # Loop 9
    review_queue = []       # Loop 10

    total = 0
    valid_count = 0
    quality_issue_count = 0
    c001_missing = 0
    inception_active = 0

    required_fields = ["id", "name", "description", "status", "workflow_type", "owner", "created", "last_update"]
    valid_statuses = {"captured", "refined", "started-work", "issues", "blocked", "work-completed"}
    valid_types = {"specification", "design", "build", "test", "refactor", "decommission", "inception"}

    # Pre-build report file list
    report_basenames = set()
    if os.path.isdir(reports_dir):
        for f in os.listdir(reports_dir):
            if f.endswith(".md"):
                report_basenames.add(f.lower())

    now = datetime.now(timezone.utc)

    for fname in sorted(os.listdir(active_dir)):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(active_dir, fname)
        if not os.path.isfile(fpath):
            continue

        total += 1

        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
        except (OSError, IOError):
            continue

        lines = content.split("\n")

        # Extract frontmatter
        fields = {}
        in_frontmatter = False
        for line in lines:
            if line.strip() == "---":
                if in_frontmatter:
                    break
                in_frontmatter = True
                continue
            if in_frontmatter and ":" in line:
                key = line.split(":", 1)[0].strip()
                val = line.split(":", 1)[1].strip().strip('"')
                fields[key] = val

        task_id = fields.get("id", "")
        status = fields.get("status", "")
        workflow_type = fields.get("workflow_type", "")
        owner = fields.get("owner", "")
        created = fields.get("created", "")

        # ============ Loop 1: Compliance ============
        task_valid = True

        for field in required_fields:
            if field not in fields or not fields[field]:
                compliance_issues.append({"task": fname, "issue": f"missing field: {field}"})
                task_valid = False

        if status and status not in valid_statuses:
            compliance_issues.append({"task": fname, "issue": f"invalid status: {status}"})
            task_valid = False

        if workflow_type and workflow_type not in valid_types:
            compliance_issues.append({"task": fname, "issue": f"invalid workflow_type: {workflow_type}"})
            task_valid = False

        if "## Updates" not in content:
            compliance_issues.append({"task": fname, "issue": "missing Updates section"})
            task_valid = False

        if task_valid:
            valid_count += 1

        # ============ Loop 2: Quality ============
        # Description length
        desc = fields.get("description", "")
        if desc == ">":
            # Multi-line YAML folded scalar — get from content
            m = re.search(r"^description:\s*>\s*\n((?:\s+.*\n)*)", content, re.MULTILINE)
            if m:
                desc = m.group(1).strip()
        if len(desc) < 30:  # T-956: raised from 50 (42-char descriptions are acceptable)
            quality_issues.append({"id": task_id, "issue": f"short description ({len(desc)} chars)", "file": fname})
            quality_issue_count += 1

        # Update count
        updates_count = content.count("\n### ")

        if status == "started-work" and updates_count == 0:
            quality_issues.append({"id": task_id, "issue": "no updates but status is started-work", "file": fname})
            quality_issue_count += 1

        # Age check
        if created:
            try:
                created_str = created.split("T")[0]
                created_dt = datetime.strptime(created_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
                age_days = (now - created_dt).days
                if age_days > 14 and status != "work-completed" and updates_count < 2:  # T-956: raised from 7
                    quality_issues.append({"id": task_id, "issue": f"{age_days} days old with only {updates_count} updates", "file": fname})
                    quality_issue_count += 1
            except (ValueError, IndexError):
                pass

        # AC checkboxes
        if status != "captured" and workflow_type != "inception":
            ac_count = len(re.findall(r"- \[[ x]\]", content))
            if ac_count == 0:
                quality_issues.append({"id": task_id, "issue": "no acceptance criteria checkboxes", "file": fname})
                quality_issue_count += 1

        # Verification section
        if status in ("started-work", "issues"):
            if "## Verification" not in content:
                quality_issues.append({"id": task_id, "issue": "no ## Verification section", "file": fname})
                quality_issue_count += 1

        # Template placeholder
        if status != "captured" and "[Link to design docs" in content:
            quality_issues.append({"id": task_id, "issue": "unfilled placeholder in Context section", "file": fname})
            quality_issue_count += 1

        # ============ Loop 5: C-001 Research (active inceptions) ============
        if workflow_type == "inception" and status == "started-work":
            inception_active += 1
            has_artifact = False
            artifact_name = ""

            for rb in report_basenames:
                if task_id.lower() in rb:
                    has_artifact = True
                    artifact_name = rb
                    break

            if not has_artifact:
                research_issues.append({"id": task_id, "type": "missing"})
                c001_missing += 1
            else:
                # Check if referenced in task
                if "docs/reports/" not in content:
                    research_issues.append({"id": task_id, "type": "unreferenced", "artifact": artifact_name})

        # ============ Loop 9: CTL-025 Ownership ============
        if status == "work-completed":
            ownership_issues.append({"id": task_id, "owner": owner, "valid": owner == "human"})

        # ============ Loop 10: D2 Human Review Queue ============
        if status == "work-completed" and owner == "human":
            finished = fields.get("date_finished", "")
            updated = fields.get("last_update", "")
            date_str = finished if finished and finished != "null" else updated
            if date_str and date_str != "null":
                try:
                    ts = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                    age_hours = int((now - ts).total_seconds() / 3600)
                    age_days = age_hours // 24
                    review_queue.append({"id": task_id, "age_hours": age_hours, "age_days": age_days})
                except (ValueError, TypeError):
                    pass

    return {
        "compliance": {
            "issues": compliance_issues,
            "total": total,
            "valid": valid_count,
        },
        "quality": {
            "issues": quality_issues,
            "issue_count": quality_issue_count,
        },
        "research": {
            "issues": research_issues,
            "c001_missing": c001_missing,
            "inception_active": inception_active,
        },
        "ownership": {
            "issues": ownership_issues,
        },
        "review_queue": {
            "tasks": review_queue,
        },
        "stats": {
            "total": total,
            "valid": valid_count,
        },
    }


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <tasks_dir> <reports_dir>", file=sys.stderr)
        sys.exit(1)

    result = scan_active_tasks(sys.argv[1], sys.argv[2])
    json.dump(result, sys.stdout)
