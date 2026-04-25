#!/usr/bin/env python3
"""Single-pass scan of completed task files for audit checks.

Replaces three separate bash loops (3, 4, 7) that each iterate 740+ files.
Reads each file once, extracts all needed data, outputs JSON results.

Usage: python3 completed-task-scan.py <tasks_dir> <episodic_dir> <reports_dir>

Output (JSON):
  {
    "missing_episodic": ["T-123", ...],
    "missing_research": ["T-456", ...],
    "unchecked_ac": [{"id": "T-789", "line": "- [ ] criterion"}],
    "stats": {"total": N, "inception_count": M}
  }

T-955: Merge loops 3/4/7 into single-pass Python scan.
"""

import json
import os
import re
import sys


def scan_completed_tasks(tasks_dir, episodic_dir, reports_dir):
    completed_dir = os.path.join(tasks_dir, "completed")
    if not os.path.isdir(completed_dir):
        return {"missing_episodic": [], "missing_research": [], "unchecked_ac": [], "stats": {"total": 0, "inception_count": 0}}

    missing_episodic = []
    missing_research = []
    unchecked_ac = []
    total = 0
    inception_count = 0

    # Pre-build report file list for research artifact check
    report_basenames = set()
    if os.path.isdir(reports_dir):
        for f in os.listdir(reports_dir):
            if f.endswith(".md"):
                report_basenames.add(f.lower())

    for fname in os.listdir(completed_dir):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(completed_dir, fname)
        if not os.path.isfile(fpath):
            continue

        total += 1

        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
        except (OSError, IOError):
            continue

        # Extract frontmatter fields (simple grep-equivalent)
        task_id = ""
        workflow_type = ""
        for line in content.split("\n"):
            if line.startswith("id:"):
                task_id = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("workflow_type:"):
                workflow_type = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("---") and task_id:
                break  # past frontmatter

        if not task_id:
            continue

        # Loop 3: Episodic coverage check
        episodic_file = os.path.join(episodic_dir, f"{task_id}.yaml")
        if not os.path.isfile(episodic_file):
            missing_episodic.append(task_id)

        # Loop 4: Research artifact check (inception tasks only)
        # T-1440: skip pickup-auto-created tasks — they're misclassified as
        # inception by the pickup importer but are bug reports / feature
        # proposals (no research artifact expected; the fix landed via commits).
        is_pickup_import = "Auto-created from pickup envelope" in content
        if workflow_type == "inception" and not is_pickup_import:
            inception_count += 1
            has_artifact = False

            # Check if any report file contains the task ID in its name
            for rb in report_basenames:
                if task_id.lower() in rb:
                    has_artifact = True
                    break

            # Check if task body mentions docs/reports/
            if not has_artifact and "docs/reports/" in content:
                has_artifact = True

            # Check episodic for artifact references
            if not has_artifact and os.path.isfile(episodic_file):
                try:
                    with open(episodic_file, "r", encoding="utf-8", errors="replace") as ef:
                        if "docs/reports/" in ef.read():
                            has_artifact = True
                except (OSError, IOError):
                    pass

            if not has_artifact:
                missing_research.append(task_id)

        # Loop 7: AC gate check (unchecked non-Human ACs)
        in_ac = False
        in_human = False
        for line in content.split("\n"):
            if line.startswith("## Acceptance Criteria"):
                in_ac = True
                in_human = False
                continue
            if line.startswith("## ") and in_ac:
                break
            if in_ac and line.startswith("### Human"):
                in_human = True
                continue
            if in_ac and line.startswith("### "):
                in_human = False
                continue
            if in_ac and not in_human and re.match(r"^- \[ \]", line):
                unchecked_ac.append({"id": task_id, "line": line[:80]})
                break  # One unchecked AC is enough to flag

    return {
        "missing_episodic": missing_episodic,
        "missing_research": missing_research,
        "unchecked_ac": unchecked_ac,
        "stats": {"total": total, "inception_count": inception_count},
    }


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <tasks_dir> <episodic_dir> <reports_dir>", file=sys.stderr)
        sys.exit(1)

    result = scan_completed_tasks(sys.argv[1], sys.argv[2], sys.argv[3])
    json.dump(result, sys.stdout)
