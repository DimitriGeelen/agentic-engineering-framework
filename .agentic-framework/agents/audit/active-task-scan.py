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
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# T-3061: the unclosed-but-satisfied rule lives in lib/task_satisfaction.py — the
# one definition, and the one with tests (tests/unit/test_task_satisfaction.py).
# `parents[2]` is the framework root in both layouts: agents/audit/x.py in the
# framework repo, and .agentic-framework/agents/audit/x.py in a vendored consumer.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
from task_satisfaction import analyse_text  # noqa: E402

_FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]

# T-3073: cheap Python pre-filter for "this inception looks like it carries a
# substantive ## Recommendation". Deliberately a SUPERSET of the authoritative
# bash predicate `audit_inception_recommendation` (lib/task-audit.sh):
#   * it does not restrict the search to the ## Recommendation section, and
#   * its comment-stripper removes only the span between <!-- and -->, where
#     bash drops whole lines,
# so anything bash would accept, this accepts too. False positives are fine —
# bash decides. False negatives would be invisible, hence the superset rule.
_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_RECOMMENDATION_RE = re.compile(
    r"^[ \t]*[-*]?[ \t]*\*\*Recommendation:\*\*[ \t]*\*{0,2}[A-Za-z]",
    re.MULTILINE,
)


def _looks_recommendation_bearing(content):
    """Cheap in-process pre-filter — no subprocess, no file re-read."""
    if "## Recommendation" not in content:
        return False
    return bool(_RECOMMENDATION_RE.search(_HTML_COMMENT_RE.sub("", content)))


def _has_substantive_recommendation(task_path):
    """Authoritative confirmation — the one definition, in bash.

    Shells out to `audit_inception_recommendation` (lib/task-audit.sh:117), the
    same predicate `fw inception decide`, `fw task review` and `fw task
    review-batch` gate on. It carries three regression fixes (T-1528 heading
    termination, T-1510 bulleted form, T-1746 emphasised verdict); re-expressing
    it in Python would create a second definition of the same rule, which is
    what T-3061 was opened to remove.

    Called once per *candidate*, never per task — T-955 built this scan to read
    each of ~130 files exactly once and a subprocess per task would undo that.
    """
    lib = _FRAMEWORK_ROOT / "lib" / "task-audit.sh"
    if not lib.is_file():
        # Degraded: predicate unavailable. Stay silent rather than guess — a
        # second guess here is the thing the Decisions section rules out.
        return False
    try:
        rc = subprocess.run(
            ["bash", "-c", 'source "$1" && audit_inception_recommendation "$2"',
             "_", str(lib), str(task_path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20,
        ).returncode
    except (OSError, subprocess.SubprocessError):
        return False
    return rc == 0


def scan_active_tasks(tasks_dir, reports_dir):
    active_dir = os.path.join(tasks_dir, "completed/../active").replace("completed/../", "")
    active_dir = os.path.join(tasks_dir, "active")
    if not os.path.isdir(active_dir):
        return {"compliance": {}, "quality": {}, "research": {}, "ownership": {}, "review_queue": {}, "unclosed_satisfied": {}, "stats": {}}

    # Results
    compliance_issues = []  # Loop 1
    quality_issues = []     # Loop 2
    research_issues = []    # Loop 5
    ownership_issues = []   # Loop 9
    review_queue = []       # Loop 10
    unclosed_satisfied = [] # Loop 11 (T-3061)

    total = 0
    valid_count = 0
    quality_issue_count = 0
    c001_missing = 0
    c001_missing_started = 0
    c001_missing_recommendation = 0
    inception_active = 0
    inception_recommendation = 0

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

        # ============ Loop 5: C-001 Research (inceptions being worked OR decided) ============
        # T-3073: the set was `status == "started-work"`, which is the population
        # being *worked*. C-001's failure mode lands on the population being
        # *decided*: an inception carrying a substantive `## Recommendation` has
        # by definition finished researching — it is asking the operator for a
        # go/no-go — and nothing forces a status change to file one, so five of
        # the six pending decisions measured on 2026-08-18 were still `captured`
        # and invisible to this rail. L-539's shape: check the SET, not just the
        # predicate.
        #
        # Two populations, tracked separately so widening the set does not
        # silently inflate a count the operator reads one way (A4).
        if workflow_type == "inception":
            reason = ""
            if status == "started-work":
                inception_active += 1
                reason = "started-work"
            elif _looks_recommendation_bearing(content) and _has_substantive_recommendation(fpath):
                # Pre-filter narrows in-process; bash confirms once per candidate.
                inception_recommendation += 1
                reason = "recommendation"

            if reason:
                has_artifact = False
                artifact_name = ""

                for rb in report_basenames:
                    if task_id.lower() in rb:
                        has_artifact = True
                        artifact_name = rb
                        break

                if not has_artifact:
                    research_issues.append({"id": task_id, "type": "missing", "reason": reason})
                    c001_missing += 1
                    if reason == "started-work":
                        c001_missing_started += 1
                    else:
                        c001_missing_recommendation += 1
                else:
                    # Check if referenced in task
                    if "docs/reports/" not in content:
                        research_issues.append({"id": task_id, "type": "unreferenced", "reason": reason, "artifact": artifact_name})

        # ============ Loop 11: Unclosed-but-satisfied (T-3061, OBS-316/317) ============
        # The judgement is `lib/task_satisfaction.analyse_text` — imported, not
        # restated. An earlier pass carried a second copy of the rule here; the two
        # agreed on all 18 hits at the time, which is exactly why a divergence
        # would have gone unnoticed later.
        satisfied = analyse_text(content)
        if satisfied:
            unclosed_satisfied.append({
                "id": task_id,
                "status": status,
                "workflow_type": workflow_type,
                "name": fields.get("name", "").strip('"'),
                "agent_ac_count": satisfied["agent_acs"],
                "has_verification": satisfied["gated"],
                "file": fname,
            })

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
            # T-3073: the two populations, reported separately (A4).
            # inception_active  = inceptions with status started-work (being worked)
            # inception_recommendation = inceptions carrying a substantive
            #   ## Recommendation but NOT started-work (being decided)
            "c001_missing_started": c001_missing_started,
            "c001_missing_recommendation": c001_missing_recommendation,
            "inception_active": inception_active,
            "inception_recommendation": inception_recommendation,
        },
        "ownership": {
            "issues": ownership_issues,
        },
        "review_queue": {
            "tasks": review_queue,
        },
        "unclosed_satisfied": {
            "tasks": unclosed_satisfied,
            "count": len(unclosed_satisfied),
            "no_verification_count": sum(1 for t in unclosed_satisfied if not t["has_verification"]),
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
