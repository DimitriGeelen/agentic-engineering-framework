#!/usr/bin/env python3
"""Single-pass scan of completed task files for audit checks.

Replaces three separate bash loops (3, 4, 7) that each iterate 740+ files.
Reads each file once, extracts all needed data, outputs JSON results.

Usage: python3 completed-task-scan.py <tasks_dir> <episodic_dir> <reports_dir>

Output (JSON):
  {
    "missing_episodic": ["T-123", ...],
    "missing_research": ["T-456", ...],
    "unchecked_ac": [{"id": "T-789", "line": "- [ ] criterion", "class": "drift"}],
    "status_desync": [{"id": "T-1846", "status": "started-work"}],
    "horizon_drift": [{"id": "T-1234", "horizon": "now"}],
    "stats": {"total": N, "inception_count": M}
  }

T-955: Merge loops 3/4/7 into single-pass Python scan.
T-1870: Add status_desync — completed/ tasks whose frontmatter status != work-completed
        (L-390: git-mv bypasses fw task update --status work-completed → desync).
T-2162 (arc-009 Slice 3): Add horizon_drift — completed/ tasks whose stored
        horizon is non-null/non-empty/non-~ (i.e. carries stale "now"/"next"/"later"
        from before T-2160 derived-past + T-2161 migration). Empty/absent horizon
        is legitimate (pre-frontmatter-template-era) and NOT flagged.
T-2202 (PL-212 closure): CTL-012 3-class taxonomy refinement.
        - Skip prose-DEFERRED prefix lines ("- [ ] **DEFERRED**", "- [ ] **Deferred to")
          — these are scope-cut markers, not real outstanding ACs. False-positives
          observed on T-1213 and T-1299.
        - Tag unchecked ACs with class: "missing-decide" when the preceding line is
          `<!-- @auto-tick-on-decide -->` AND the task's `## Decision` section is
          empty. This is the T-1993 pattern: direct frontmatter-flip to work-completed
          bypassed `fw inception decide`, so the auto-tick path never ran. Distinct
          from the genuine AC-drift class so the auditor can render a different hint.
        - Class field on every entry: "drift" (default, real CTL-012) or "missing-decide"
          (new CTL-012-MISSING-DECIDE sub-class).
"""

import json
import os
import re
import sys


def scan_completed_tasks(tasks_dir, episodic_dir, reports_dir):
    completed_dir = os.path.join(tasks_dir, "completed")
    if not os.path.isdir(completed_dir):
        return {"missing_episodic": [], "missing_research": [], "unchecked_ac": [], "status_desync": [], "horizon_drift": [], "stats": {"total": 0, "inception_count": 0}}

    missing_episodic = []
    missing_research = []
    unchecked_ac = []
    status_desync = []
    horizon_drift = []
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
        status = ""
        horizon = ""
        horizon_seen = False
        for line in content.split("\n"):
            if line.startswith("id:"):
                task_id = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("workflow_type:"):
                workflow_type = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("status:"):
                status = line.split(":", 1)[1].strip().strip('"')
            elif line.startswith("horizon:"):
                horizon_seen = True
                # Strip inline comment if present
                raw = line.split(":", 1)[1]
                if "#" in raw:
                    raw = raw.split("#", 1)[0]
                horizon = raw.strip().strip('"').strip("'")
            elif line.startswith("---") and task_id:
                break  # past frontmatter

        if not task_id:
            continue

        # T-1870 (L-390): completed/ task with status != work-completed indicates
        # git-mv bypass of `fw task update --status work-completed` state machine.
        if status and status != "work-completed":
            status_desync.append({"id": task_id, "status": status})

        # T-2162 (arc-009 Slice 3): completed/ task with non-null stored horizon.
        # Empty/absent/null/~ are all legitimate after T-2161 migration. Anything
        # else is drift — render derives `past` from _location regardless, but a
        # stored "now"/"next"/"later" on a completed file is a YAML lie.
        if horizon_seen and horizon and horizon.lower() not in ("null", "~"):
            horizon_drift.append({"id": task_id, "horizon": horizon})

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
        # T-2202: CTL-012 3-class taxonomy refinement.
        #   - Skip prose-DEFERRED prefix (scope-cut markers, not real ACs).
        #   - Detect missing-decide class (auto-tick marker + empty Decision section).
        in_ac = False
        in_human = False
        prev_was_auto_tick = False
        # Pre-compute Decision-section emptiness for the missing-decide classifier.
        # An empty Decision section is just the heading + optional whitespace/comments
        # before the next `## ` heading or end-of-file. Render-time decision: the
        # auto-tick path writes a structured Decision block; its absence means the
        # decide ceremony never ran.
        decision_empty = True
        in_decision = False
        for line in content.split("\n"):
            if line.startswith("## Decision") and not line.startswith("## Decisions"):
                in_decision = True
                continue
            if in_decision and line.startswith("## "):
                break
            if in_decision:
                stripped = line.strip()
                if not stripped:
                    continue
                if stripped.startswith("<!--") or stripped.startswith("-->") or stripped.endswith("-->"):
                    continue
                # Any non-blank, non-comment content means the section has been filled.
                decision_empty = False
                break
        for line in content.split("\n"):
            if line.startswith("## Acceptance Criteria"):
                in_ac = True
                in_human = False
                prev_was_auto_tick = False
                continue
            if line.startswith("## ") and in_ac:
                break
            if in_ac and line.startswith("### Human"):
                in_human = True
                prev_was_auto_tick = False
                continue
            if in_ac and line.startswith("### "):
                in_human = False
                prev_was_auto_tick = False
                continue
            if in_ac and not in_human:
                # Track @auto-tick-on-decide marker for the missing-decide classifier.
                if "@auto-tick-on-decide" in line:
                    prev_was_auto_tick = True
                    continue
                if re.match(r"^- \[ \]", line):
                    # Skip prose-DEFERRED scope-cut markers (T-1213, T-1299 class).
                    # Match "- [ ] **DEFERRED" and "- [ ] **Deferred" prefixes.
                    if re.match(r"^- \[ \]\s+\*\*(DEFERRED|Deferred)", line):
                        prev_was_auto_tick = False
                        continue
                    # Classify: missing-decide if the marker line preceded AND
                    # the Decision section is empty (T-1993 class).
                    ac_class = "drift"
                    if prev_was_auto_tick and decision_empty:
                        ac_class = "missing-decide"
                    unchecked_ac.append({"id": task_id, "line": line[:80], "class": ac_class})
                    break  # One unchecked AC is enough to flag
                # Reset marker after a non-marker, non-AC line (prevents stale stick).
                if line.strip() and not line.startswith("<!--"):
                    prev_was_auto_tick = False

    return {
        "missing_episodic": missing_episodic,
        "missing_research": missing_research,
        "unchecked_ac": unchecked_ac,
        "status_desync": status_desync,
        "horizon_drift": horizon_drift,
        "stats": {"total": total, "inception_count": inception_count},
    }


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <tasks_dir> <episodic_dir> <reports_dir>", file=sys.stderr)
        sys.exit(1)

    result = scan_completed_tasks(sys.argv[1], sys.argv[2], sys.argv[3])
    json.dump(result, sys.stdout)
