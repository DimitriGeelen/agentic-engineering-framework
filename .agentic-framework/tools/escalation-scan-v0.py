#!/usr/bin/env python3
"""
T-1549 — Layer B v0 spike: scan completed tasks for symptom-fix candidates.

Heuristics (intentionally simple for the spike):
  H1: Bug-class task with no `## RCA` (or equivalent root-cause) content
  H2: Tasks sharing the same learning-ID across multiple completions in N days
       (the "L-294/D-036/D-038 pattern" — same learning re-discovered)
  H3: Commit references "fix" but task has no `## RCA` block AND no learning
       captured (fix shipped without escalation residue)

Output: write report to docs/reports/T-1549-escalation-scan-v0.md
Read-only. Does not block, modify, or alert.
"""
from __future__ import annotations

import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPLETED = ROOT / ".tasks" / "completed"
REPORT = ROOT / "docs" / "reports" / "T-1549-escalation-scan-v0.md"
# T-1555 Layer B v1: stable machine-readable summary for cron consumers.
# Watchtower / metrics / drift dashboards read this; the .md remains for humans.
LATEST_YAML = ROOT / ".context" / "working" / "escalation-drift-LATEST.yaml"

BUG_TITLE_RE = re.compile(
    r"\b(fix|bug|rca|broken|crash|error|regression|fail|hotfix)\b", re.I
)
BUG_TAG_RE = re.compile(r"\b(bug|bugfix|hotfix|rca|incident)\b", re.I)
RCA_SECTION_RE = re.compile(
    r"^##+\s*(RCA|Root\s*Cause|Why\s*This\s*Happened)\b", re.I | re.M
)
LEARNING_REF_RE = re.compile(r"\b([LP]L?-\d{3,4})\b")


def parse_frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 4)
    if end == -1:
        return {}
    fm = {}
    for line in text[4:end].splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm


def is_bug_class(fm: dict, title: str, body: str) -> bool:
    tags = fm.get("tags", "") or ""
    if BUG_TAG_RE.search(tags):
        return True
    wf = fm.get("workflow_type", "")
    if wf in {"inception", "specification", "design"}:
        return False
    if BUG_TITLE_RE.search(title):
        return True
    return False


def has_rca(body: str) -> bool:
    """Body has a non-trivial RCA-equivalent section?"""
    m = RCA_SECTION_RE.search(body)
    if not m:
        return False
    after = body[m.end(): m.end() + 800]
    cleaned = re.sub(r"<!--.*?-->", "", after, flags=re.S).strip()
    real_lines = [
        l for l in cleaned.splitlines()
        if l.strip() and not l.strip().startswith("#")
    ]
    return any(len(l) > 30 for l in real_lines[:5])


def has_learning_capture(body: str) -> bool:
    return bool(LEARNING_REF_RE.search(body))


def parse_finished_date(fm: dict) -> datetime | None:
    s = fm.get("date_finished") or fm.get("last_update")
    if not s or s == "null":
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def main() -> None:
    bug_class_tasks: list[tuple[str, dict, str]] = []
    all_tasks: list[tuple[str, dict, str]] = []
    learning_to_tasks: dict[str, list[str]] = defaultdict(list)

    for path in sorted(COMPLETED.glob("T-*.md")):
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        fm = parse_frontmatter(text)
        body_start = text.find("\n---", 4)
        body = text[body_start + 4:] if body_start != -1 else text
        title = fm.get("name", path.stem)
        all_tasks.append((path.stem, fm, body))
        if is_bug_class(fm, title, body):
            bug_class_tasks.append((path.stem, fm, body))
        for lid in LEARNING_REF_RE.findall(body):
            learning_to_tasks[lid].append(path.stem)

    h1_flagged = [
        (tid, fm, body) for tid, fm, body in bug_class_tasks if not has_rca(body)
    ]

    # H2: learning IDs in ≥3 tasks within 30 days
    fm_by_tid = {tid: fm for tid, fm, _ in all_tasks}
    h2_repeats: list[tuple[str, list[str]]] = []
    for lid, tids in learning_to_tasks.items():
        if len(tids) < 3:
            continue
        dates = []
        for tid in tids:
            fm = fm_by_tid.get(tid)
            if fm:
                d = parse_finished_date(fm)
                if d:
                    dates.append(d)
        if not dates:
            continue
        dates.sort()
        for i in range(len(dates) - 2):
            if dates[i + 2] - dates[i] <= timedelta(days=30):
                h2_repeats.append((lid, tids))
                break

    h3_flagged = [
        (tid, fm, body) for tid, fm, body in bug_class_tasks
        if not has_rca(body) and not has_learning_capture(body)
    ]

    # Self-application (Spike 3)
    t1548_status = "not found in completed/"
    for path in COMPLETED.glob("T-1548-*.md"):
        text = path.read_text(encoding="utf-8")
        fm = parse_frontmatter(text)
        body_start = text.find("\n---", 4)
        body = text[body_start + 4:] if body_start != -1 else text
        bc = is_bug_class(fm, fm.get("name", ""), body)
        rca = has_rca(body)
        lc = has_learning_capture(body)
        t1548_status = (
            f"bug_class={bc} has_rca={rca} learning_captured={lc}"
            f" → flagged_by_H1={bc and not rca}"
        )
        break

    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    recent_flagged = []
    for tid, fm, _ in h1_flagged:
        d = parse_finished_date(fm)
        if d and d >= cutoff:
            recent_flagged.append((tid, fm.get("name", "")[:80]))

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w") as f:
        f.write("# T-1549 — Layer B v0 Heuristic Scan Results\n\n")
        f.write(f"**Run:** {datetime.now(timezone.utc).isoformat()}\n")
        f.write(f"**Corpus:** {len(all_tasks)} completed tasks\n")
        bc_pct = 100 * len(bug_class_tasks) // max(1, len(all_tasks))
        f.write(f"**Bug-class identified:** {len(bug_class_tasks)} ({bc_pct}%)\n\n")

        f.write("## H1 — Bug-class tasks with no `## RCA` section\n\n")
        h1_pct = 100 * len(h1_flagged) // max(1, len(bug_class_tasks))
        f.write(
            f"**Flagged:** {len(h1_flagged)} / {len(bug_class_tasks)} "
            f"bug-class tasks ({h1_pct}%)\n\n"
        )
        f.write("**Last 30 days sample (FP triage candidates):**\n\n")
        for tid, name in recent_flagged[:25]:
            f.write(f"- `{tid}` — {name}\n")
        if len(recent_flagged) > 25:
            f.write(f"- ... +{len(recent_flagged) - 25} more in last 30 days\n")
        f.write("\n")

        f.write("## H2 — Learning IDs referenced across ≥3 tasks within 30 days\n\n")
        if not h2_repeats:
            f.write("_No repeats meeting threshold._\n\n")
        else:
            for lid, tids in sorted(h2_repeats, key=lambda x: -len(x[1]))[:15]:
                preview = ", ".join(tids[:5])
                more = " …" if len(tids) > 5 else ""
                f.write(
                    f"- `{lid}` — referenced by {len(tids)} tasks: "
                    f"{preview}{more}\n"
                )
            f.write("\n")

        f.write("## H3 — Bug-class with no RCA AND no learning captured\n\n")
        h3_pct = 100 * len(h3_flagged) // max(1, len(bug_class_tasks))
        f.write(
            f"**Flagged:** {len(h3_flagged)} / {len(bug_class_tasks)} "
            f"({h3_pct}%)\n\n"
        )
        f.write(
            "This is the strongest symptom-fix signal: fix shipped, "
            "no root cause stated, no learning captured for next time.\n\n"
        )

        f.write("## Self-application (Spike 3 — recursion test)\n\n")
        f.write(f"T-1548 (the inception that birthed this scan): {t1548_status}\n\n")
        f.write(
            "**Reading:** if T-1548 is flagged by H1, the heuristic correctly "
            "identifies even the meta-task itself as lacking an inline `## RCA` "
            "section — though its `docs/reports/T-1548-rca-escalation-structural.md` "
            "artifact carries the RCA. H1's blindness to artifact files is a known "
            "limitation, addressable in v1 by also scanning `docs/reports/T-XXX-*.md`.\n\n"
        )

        f.write("## Headline numbers\n\n")
        f.write("| Metric | Value |\n|---|---|\n")
        f.write(f"| Total completed tasks | {len(all_tasks)} |\n")
        f.write(f"| Bug-class tasks | {len(bug_class_tasks)} ({bc_pct}%) |\n")
        f.write(f"| H1 flagged | {len(h1_flagged)} |\n")
        f.write(f"| H2 repeat-learning patterns | {len(h2_repeats)} |\n")
        f.write(f"| H3 flagged (strongest signal) | {len(h3_flagged)} |\n")
        f.write(f"| Last-30-days bug-class | {len(recent_flagged)} |\n\n")

        f.write("## Read-out — GO/NO-GO for Layer B v1 (cron + register + Watchtower)\n\n")
        f.write(
            "**GO Layer B v1** if (manual triage on a 20-task sample of H1):\n"
            "- Recall ≥ 70%: the scanner finds the symptom-fix instances we *know* exist\n"
            "- FP rate < 30%: most flagged tasks really are bug-fixes-without-RCA, "
            "not docs/refactors miscategorised\n"
            "- H2 produces actionable repeat-class signal (not just generic L-IDs everyone cites)\n\n"
            "**NO-GO / iterate** if:\n"
            "- FP > 30% on the sample → tighten `is_bug_class` filter "
            "(use commit-history + tags more strictly) before promotion\n"
            "- H1 misses obvious past instances → add commit-message scanning to recall\n"
            "- H2 noise dominates → require co-occurrence with H1 to count\n\n"
            "**DEFER** if the data shows the dominant pattern is something v0 doesn't model "
            "(e.g. corrections within a session, not across tasks) → re-scope before building v1.\n"
        )

    # T-1555 Layer B v1: machine-readable summary for cron / Watchtower.
    # Hand-rolled YAML (no PyYAML dependency in framework runtime).
    LATEST_YAML.parent.mkdir(parents=True, exist_ok=True)
    h2_top = sorted(h2_repeats, key=lambda x: -len(x[1]))[:10]
    with LATEST_YAML.open("w") as f:
        f.write("# Escalation drift summary — T-1555 Layer B v1\n")
        f.write("# Re-emitted on every scanner run. Read-only artifact.\n")
        f.write(f"generated: {datetime.now(timezone.utc).isoformat()}\n")
        f.write(f"corpus_total: {len(all_tasks)}\n")
        f.write(f"bug_class_total: {len(bug_class_tasks)}\n")
        f.write(f"bug_class_pct: {bc_pct}\n")
        f.write(f"h1_flagged: {len(h1_flagged)}\n")
        f.write(f"h1_pct_of_bug_class: {h1_pct}\n")
        f.write(f"h2_repeat_patterns: {len(h2_repeats)}\n")
        f.write(f"h3_flagged: {len(h3_flagged)}\n")
        f.write(f"h3_pct_of_bug_class: {h3_pct}\n")
        f.write(f"recent_30d_flagged: {len(recent_flagged)}\n")
        f.write(f"report_md: {REPORT.relative_to(ROOT)}\n")
        f.write("recent_sample:\n")
        for tid, name in recent_flagged[:10]:
            safe_name = name.replace('"', "'")
            f.write(f'  - tid: "{tid}"\n')
            f.write(f'    name: "{safe_name}"\n')
        f.write("h2_top:\n")
        for lid, tids in h2_top:
            f.write(f'  - learning: "{lid}"\n')
            f.write(f"    task_count: {len(tids)}\n")

    print(f"Report written: {REPORT}")
    print(f"Latest YAML:    {LATEST_YAML}")
    print(
        f"Corpus: {len(all_tasks)} tasks; "
        f"bug-class: {len(bug_class_tasks)}; "
        f"H1: {len(h1_flagged)}; "
        f"H2: {len(h2_repeats)}; "
        f"H3: {len(h3_flagged)}"
    )
    print(f"Self-application: {t1548_status}")


if __name__ == "__main__":
    main()
