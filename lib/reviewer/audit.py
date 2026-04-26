"""Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b).

Default mode (static-scan re-run): re-runs the reviewer's anti-pattern
catalogue over all completed tasks. Writes daily summary to
`.context/audits/reviewer/YYYY-MM-DD.yaml`.

`--pass-b` mode (v1.5 Pass B reverify, T-1484): for every completed task,
checks out the completion SHA into a single shared git worktree and
re-executes the `## Verification` block (skipping network-dependent
lines per Spike 1 classifier). Writes
`.context/audits/reviewer/YYYY-MM-DD-pass-b.yaml`.

Note on terminology: the v1.0 docstring used "Pass B" for the static
catalogue re-scan. T-1483/v1.5 introduced "Pass A" (drift signal) and
"Pass B" (worktree re-execution). The `--pass-b` flag here selects the
v1.5 meaning. Default behavior is unchanged.

Antifragile: pure compute, no caching. Runs end-to-end every invocation.
Fail-soft (T3): exceptions caught at task level, reported in YAML output.
"""

from __future__ import annotations

import argparse
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


def write_audit_yaml(project_root: Path, summary: dict, suffix: str = "") -> Path:
    """Write summary YAML atomically. `suffix` (e.g. '-pass-b') keeps modes separate."""
    out_dir = project_root / ".context" / "audits" / "reviewer"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{summary['scan_date']}{suffix}.yaml"
    tmp = out_path.with_suffix(".yaml.tmp")
    with open(tmp, "w") as fh:
        yaml.safe_dump(summary, fh, sort_keys=False)
    tmp.replace(out_path)
    return out_path


def _completed_tasks_newest_first(project_root: Path, limit: int | None) -> list[Path]:
    completed_dir = project_root / ".tasks" / "completed"

    def _task_id_num(p: Path) -> int:
        try:
            return int(p.name.split("-")[1])
        except (IndexError, ValueError):
            return 0

    tasks = sorted(completed_dir.glob("T-*.md"), key=_task_id_num, reverse=True)
    if limit is not None:
        tasks = tasks[:limit]
    return tasks


def run_pass_a_baseline(
    project_root: Path,
    limit: int | None = None,
    force: bool = False,
) -> dict:
    """v1.5 Pass A baseline init (T-1485). Writes drift baselines for completed tasks.

    Idempotent: skips tasks that already have a baseline unless `force=True`.
    """
    from lib.reviewer.drift import (
        compute_hashes,
        extract_file_refs,
        read_baseline,
        write_baseline,
    )
    from lib.reviewer.static_scan import extract_section

    tasks = _completed_tasks_newest_first(project_root, limit)
    written = 0
    skipped_existing = 0
    skipped_no_verification = 0
    per_task: list[dict] = []
    errors: list[dict] = []

    for tf in tasks:
        try:
            text = tf.read_text()
            body = text.split("---", 2)[2] if text.startswith("---") else text
            verification = extract_section(body, "Verification") or ""
            if not verification.strip():
                skipped_no_verification += 1
                per_task.append({"task_id": tf.stem.split("-", 2)[0] + "-" + tf.stem.split("-")[1],
                                 "action": "skipped-no-verification", "n_files": 0})
                continue
            existing = read_baseline(text)
            if existing and not force:
                skipped_existing += 1
                per_task.append({"task_id": tf.stem.split("-", 2)[0] + "-" + tf.stem.split("-")[1],
                                 "action": "skipped-has-baseline", "n_files": len(existing)})
                continue
            refs = extract_file_refs(verification, project_root)
            baseline = compute_hashes(refs, project_root)
            new_text = write_baseline(text, baseline)
            tf.write_text(new_text)
            written += 1
            per_task.append({"task_id": tf.stem.split("-", 2)[0] + "-" + tf.stem.split("-")[1],
                             "action": "baseline-written", "n_files": len(baseline)})
        except Exception as exc:
            errors.append({"task": tf.name, "error": f"{type(exc).__name__}: {exc}"})

    return {
        "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "scan_timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": "pass-a-baseline",
        "tasks_scanned": len(tasks),
        "limit": limit,
        "force": force,
        "totals": {
            "written": written,
            "skipped_existing": skipped_existing,
            "skipped_no_verification": skipped_no_verification,
            "errors": len(errors),
        },
        "errors": errors,
        "per_task": per_task,
    }


def run_pass_a_drift(
    project_root: Path,
    limit: int | None = None,
) -> dict:
    """v1.5 Pass A corpus drift scan (T-1485). Compare current hashes vs baselines."""
    from lib.reviewer.drift import detect_drift, read_baseline
    from lib.reviewer.static_scan import extract_section

    tasks = _completed_tasks_newest_first(project_root, limit)
    totals = Counter()
    per_task: list[dict] = []
    errors: list[dict] = []

    for tf in tasks:
        try:
            text = tf.read_text()
            body = text.split("---", 2)[2] if text.startswith("---") else text
            verification = extract_section(body, "Verification") or ""
            if not verification.strip():
                totals["NO-VERIFICATION"] += 1
                per_task.append({
                    "task_id": tf.stem.split("-", 2)[0] + "-" + tf.stem.split("-")[1],
                    "verdict": "NO-VERIFICATION",
                    "has_drift": False,
                    "n_unchanged": 0, "n_changed": 0,
                    "n_missing": 0, "n_no_baseline": 0,
                })
                continue
            baseline = read_baseline(text)
            if not baseline:
                totals["NO-BASELINE"] += 1
                per_task.append({
                    "task_id": tf.stem.split("-", 2)[0] + "-" + tf.stem.split("-")[1],
                    "verdict": "NO-BASELINE",
                    "has_drift": False,
                    "n_unchanged": 0, "n_changed": 0,
                    "n_missing": 0, "n_no_baseline": 0,
                })
                continue
            rep = detect_drift(tf, project_root)
            verdict = "DRIFTED" if rep.has_drift else "STABLE"
            totals[verdict] += 1
            per_task.append({
                "task_id": rep.task_id,
                "verdict": verdict,
                "has_drift": rep.has_drift,
                "n_unchanged": len(rep.unchanged),
                "n_changed": len(rep.changed),
                "n_missing": len(rep.missing),
                "n_no_baseline": len(rep.no_baseline),
                "changed_files": rep.changed[:10],  # cap for YAML noise
                "missing_files": rep.missing[:10],
            })
        except Exception as exc:
            errors.append({"task": tf.name, "error": f"{type(exc).__name__}: {exc}"})

    return {
        "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "scan_timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": "pass-a",
        "tasks_scanned": len(tasks),
        "limit": limit,
        "totals": {
            "STABLE": totals.get("STABLE", 0),
            "DRIFTED": totals.get("DRIFTED", 0),
            "NO-BASELINE": totals.get("NO-BASELINE", 0),
            "NO-VERIFICATION": totals.get("NO-VERIFICATION", 0),
        },
        "errors": errors,
        "per_task": per_task,
    }


def run_pass_b_reverify(
    project_root: Path,
    limit: int | None = None,
    timeout_per_line: int = 30,
) -> dict:
    """v1.5 Pass B corpus mode (T-1484).

    Re-execute every completed task's `## Verification` block inside a single
    shared git worktree at the task's completion SHA. Network-dependent lines
    skipped. Returns summary dict for YAML output.
    """
    from lib.reviewer.reverify import WorktreePool, reverify_task

    completed_dir = project_root / ".tasks" / "completed"

    def _task_id_num(p: Path) -> int:
        # Sort by numeric task ID descending (newest first) so --limit hits recent tasks.
        try:
            return int(p.name.split("-")[1])
        except (IndexError, ValueError):
            return 0

    completed = sorted(completed_dir.glob("T-*.md"), key=_task_id_num, reverse=True)
    if limit is not None:
        completed = completed[:limit]

    totals = Counter()
    per_task: list[dict] = []
    errors: list[dict] = []

    with WorktreePool(project_root) as pool:
        for tf in completed:
            try:
                rep = reverify_task(tf, pool, timeout_per_line=timeout_per_line)
            except Exception as exc:
                errors.append({"task": tf.name, "error": f"{type(exc).__name__}: {exc}"})
                totals["ERROR"] += 1
                continue
            n_pass = sum(1 for r in rep.results if r.status == "PASS")
            n_fail = sum(1 for r in rep.results if r.status == "FAIL")
            n_skip = sum(1 for r in rep.results if r.status == "SKIPPED")
            n_error = sum(1 for r in rep.results if r.status == "ERROR")
            totals[rep.overall] += 1
            per_task.append({
                "task_id": rep.task_id,
                "sha": rep.sha,
                "overall": rep.overall,
                "n_pass": n_pass,
                "n_fail": n_fail,
                "n_skipped": n_skip,
                "n_error": n_error,
                "error": rep.error,
            })

    return {
        "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "scan_timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": "pass-b",
        "tasks_scanned": len(per_task),
        "limit": limit,
        "timeout_per_line": timeout_per_line,
        "totals": {
            "PASS": totals.get("PASS", 0),
            "FAIL": totals.get("FAIL", 0),
            "NO-VERIFICATION": totals.get("NO-VERIFICATION", 0),
            "ERROR": totals.get("ERROR", 0),
        },
        "errors": errors,
        "per_task": per_task,
    }


def main(argv: list[str] | None = None) -> int:
    import os

    parser = argparse.ArgumentParser(prog="fw reviewer audit")
    parser.add_argument(
        "--pass-a",
        dest="pass_a",
        action="store_true",
        help="v1.5 Pass A corpus drift scan (cheap signal, file-hash compare vs baseline)",
    )
    parser.add_argument(
        "--baseline",
        action="store_true",
        help="With --pass-a: write drift baselines instead of comparing (one-shot init)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="With --pass-a --baseline: overwrite existing baselines (default is idempotent)",
    )
    parser.add_argument(
        "--pass-b",
        dest="pass_b",
        action="store_true",
        help="v1.5 Pass B corpus reverify (worktree-reuse re-execution of ## Verification)",
    )
    parser.add_argument("--limit", type=int, default=None, help="Cap tasks scanned (cron budget)")
    parser.add_argument("--timeout", type=int, default=30, help="Per-line timeout seconds (default 30)")
    parser.add_argument("--quiet", action="store_true", help="Suppress per-task summary lines")
    args = parser.parse_args(argv)

    project_root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    framework_root = Path(os.environ.get("FRAMEWORK_ROOT") or project_root)

    if args.pass_a and args.baseline:
        summary = run_pass_a_baseline(project_root, limit=args.limit, force=args.force)
        out_path = write_audit_yaml(project_root, summary, suffix="-pass-a-baseline")
        t = summary["totals"]
        print(f"Reviewer audit (v1.5 Pass A baseline init) — {summary['scan_date']}")
        print(f"  Scanned: {summary['tasks_scanned']} task(s)"
              + (f" (limited to {args.limit})" if args.limit else "")
              + (" [force]" if args.force else ""))
        print(f"  Written: {t['written']}  Skipped (had baseline): {t['skipped_existing']}  "
              f"Skipped (no verification): {t['skipped_no_verification']}  Errors: {t['errors']}")
        print(f"  Wrote: {out_path.relative_to(project_root)}")
        return 0

    if args.pass_a:
        summary = run_pass_a_drift(project_root, limit=args.limit)
        out_path = write_audit_yaml(project_root, summary, suffix="-pass-a")
        t = summary["totals"]
        print(f"Reviewer audit (v1.5 Pass A drift scan) — {summary['scan_date']}")
        print(f"  Scanned: {summary['tasks_scanned']} task(s)"
              + (f" (limited to {args.limit})" if args.limit else ""))
        print(f"  Verdicts: STABLE={t['STABLE']} DRIFTED={t['DRIFTED']} "
              f"NO-BASELINE={t['NO-BASELINE']} NO-VERIFICATION={t['NO-VERIFICATION']}")
        if not args.quiet:
            for row in summary["per_task"]:
                if row["verdict"] == "DRIFTED":
                    print(f"    [DRIFTED] {row['task_id']}  "
                          f"changed={row['n_changed']} missing={row['n_missing']}")
        if summary["errors"]:
            print(f"  Errors: {len(summary['errors'])} (see YAML)")
        print(f"  Wrote: {out_path.relative_to(project_root)}")
        return 0 if t["DRIFTED"] == 0 else 1

    if args.pass_b:
        summary = run_pass_b_reverify(
            project_root, limit=args.limit, timeout_per_line=args.timeout
        )
        out_path = write_audit_yaml(project_root, summary, suffix="-pass-b")
        t = summary["totals"]
        print(f"Reviewer audit (v1.5 Pass B reverify) — {summary['scan_date']}")
        print(f"  Scanned: {summary['tasks_scanned']} completed task(s)"
              + (f" (limited to {args.limit})" if args.limit else ""))
        print(f"  Verdicts: PASS={t['PASS']} FAIL={t['FAIL']} "
              f"NO-VERIFICATION={t['NO-VERIFICATION']} ERROR={t['ERROR']}")
        if not args.quiet:
            for row in summary["per_task"]:
                if row["overall"] != "PASS":
                    print(f"    [{row['overall']}] {row['task_id']} "
                          f"sha={(row['sha'] or 'none')[:8]} "
                          f"PASS={row['n_pass']} FAIL={row['n_fail']} "
                          f"SKIPPED={row['n_skipped']} ERROR={row.get('n_error', 0)}")
        if summary["errors"]:
            print(f"  Errors: {len(summary['errors'])} (see YAML)")
        print(f"  Wrote: {out_path.relative_to(project_root)}")
        return 0 if (t["FAIL"] == 0 and t["ERROR"] == 0) else 1

    try:
        catalogue, escalation = _load_catalogues(framework_root, project_root)
    except Exception as exc:
        print(f"ERROR: catalogue load failed: {exc}", file=sys.stderr)
        return 3

    summary = run_pass_b(project_root, catalogue, escalation)
    out_path = write_audit_yaml(project_root, summary)

    t = summary["totals"]
    print(f"Reviewer audit (static-scan re-run) — {summary['scan_date']}")
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
