"""Layer 3 audit cron (T-1443 v1.2).

Pass B: re-runs the reviewer over all completed tasks with the current
catalogue and writes a daily summary to `.context/audits/reviewer/`.

Pass A (drift re-verification — re-run task verification scripts) is deferred
to v1.5 with isolation. Pass A has high blast radius and needs sandboxing.

Antifragile: pure compute, no caching. Runs end-to-end every invocation.
Fail-soft (T3): exceptions caught at task level, reported in YAML output.
"""

from __future__ import annotations

import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import yaml

from lib.reviewer import static_scan as ss


def _load_catalogues(framework_root: Path, project_root: Path) -> tuple[dict, dict | None]:
    cat_path = framework_root / "policy" / "anti-patterns.yaml"
    if not cat_path.exists():
        cat_path = project_root / "policy" / "anti-patterns.yaml"
    catalogue = ss.load_catalogue(cat_path)

    esc_path = framework_root / "policy" / "escalation-patterns.yaml"
    if not esc_path.exists():
        esc_path = project_root / "policy" / "escalation-patterns.yaml"
    escalation = ss.load_catalogue(esc_path) if esc_path.exists() else None

    return catalogue, escalation


def run_pass_b(project_root: Path, catalogue: dict, escalation: dict | None) -> dict:
    """Re-scan all completed tasks. Return summary dict for YAML output."""
    completed_dir = project_root / ".tasks" / "completed"
    completed = sorted(completed_dir.glob("T-*.md"))

    # v1.4: load active overrides; suppressed findings are reported separately
    from lib.reviewer.overrides import load_overrides
    overrides = load_overrides()

    totals = Counter()
    pattern_fires = Counter()
    suppressed_fires = Counter()
    escalation_fires = Counter()
    finding_locations: dict[str, list[str]] = {}
    errors: list[dict] = []
    needs_human_count = 0
    suppressed_total = 0

    for tf in completed:
        try:
            v = ss.scan_task(tf, catalogue, escalation, overrides=overrides)
        except Exception as exc:
            errors.append({"task": tf.name, "error": f"{type(exc).__name__}: {exc}"})
            continue
        totals[v.overall] += 1
        if v.needs_human:
            needs_human_count += 1
        for f in v.findings:
            pattern_fires[f.pattern_id] += 1
            finding_locations.setdefault(f.pattern_id, []).append(v.task_id)
        for f in v.suppressed:
            suppressed_fires[f.pattern_id] += 1
            suppressed_total += 1
        for e in v.escalations:
            escalation_fires[e.trigger_id] += 1

    # top findings: most frequent patterns, with up to 5 example task IDs
    top_findings = []
    for pid, count in pattern_fires.most_common(5):
        top_findings.append(
            {
                "pattern_id": pid,
                "count": count,
                "examples": finding_locations[pid][:5],
            }
        )

    return {
        "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "scan_timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pass": "B",
        "catalogue_version": catalogue.get("catalogue_version", "unknown"),
        "escalation_version": (escalation or {}).get("catalogue_version", "n/a"),
        "tasks_scanned": sum(totals.values()),
        "errors": errors,
        "totals": {
            "PASS": totals.get("PASS", 0),
            "CONCERN": totals.get("CONCERN", 0),
            "FAIL": totals.get("FAIL", 0),
            "needs_human": needs_human_count,
        },
        "pattern_fire_counts": dict(pattern_fires),
        "suppressed_fire_counts": dict(suppressed_fires),
        "suppressed_total": suppressed_total,
        "active_overrides": len(overrides),
        "escalation_fire_counts": dict(escalation_fires),
        "top_findings": top_findings,
    }


def write_audit_yaml(project_root: Path, summary: dict) -> Path:
    out_dir = project_root / ".context" / "audits" / "reviewer"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{summary['scan_date']}.yaml"
    # write atomically
    tmp = out_path.with_suffix(".yaml.tmp")
    with open(tmp, "w") as fh:
        yaml.safe_dump(summary, fh, sort_keys=False)
    tmp.replace(out_path)
    return out_path


def main(argv: list[str] | None = None) -> int:
    import os

    project_root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    framework_root = Path(os.environ.get("FRAMEWORK_ROOT") or project_root)

    try:
        catalogue, escalation = _load_catalogues(framework_root, project_root)
    except Exception as exc:
        print(f"ERROR: catalogue load failed: {exc}", file=sys.stderr)
        return 3

    summary = run_pass_b(project_root, catalogue, escalation)
    out_path = write_audit_yaml(project_root, summary)

    t = summary["totals"]
    print(f"Reviewer audit (Pass B) — {summary['scan_date']}")
    print(f"  Catalogue: {summary['catalogue_version']}")
    print(f"  Escalation: {summary['escalation_version']}")
    print(f"  Scanned: {summary['tasks_scanned']} completed task(s)")
    print(f"  Verdicts: PASS={t['PASS']} CONCERN={t['CONCERN']} FAIL={t['FAIL']} (needs_human={t['needs_human']})")
    if summary["pattern_fire_counts"]:
        print(f"  Pattern fires: {summary['pattern_fire_counts']}")
    if summary.get("suppressed_total", 0) > 0:
        print(f"  Suppressed by override: {summary['suppressed_total']} ({summary['active_overrides']} active overrides)")
    if summary["escalation_fire_counts"]:
        print(f"  Escalation fires: {summary['escalation_fire_counts']}")
    if summary["errors"]:
        print(f"  Errors: {len(summary['errors'])} (see YAML)")
    print(f"  Wrote: {out_path.relative_to(project_root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
