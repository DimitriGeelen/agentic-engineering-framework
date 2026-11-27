"""D6 completion velocity (T-248), made testable and corrected by T-5421.

050-email-archive (msg 398260cc item 2) saw "D6: Completion velocity — sustained drop"
with recent_avg 0.0 while it was completing tasks. D6 counted only files in
.tasks/completed/. A partial-complete task (agent work done, Human criteria still open)
stays in .tasks/active/ with `status: work-completed` and a `date_finished`; it reaches
completed/ only when the operator closes it, carrying its original finish date into
the past window. Recent days read low, earlier days high: a false drop wherever many
tasks wait for human review.

A task now counts on its `date_finished` wherever the file sits, when it is in
completed/ or is `status: work-completed` in active/.

    python3 lib/completion_velocity.py <project_root>   -> "PASS …" | "WARN …"
"""
from __future__ import annotations

import os
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone

_FM = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def _frontmatter(path: str) -> dict:
    try:
        import yaml
        with open(path, encoding="utf-8", errors="replace") as fh:
            m = _FM.match(fh.read())
        return (yaml.safe_load(m.group(1)) or {}) if m else {}
    except Exception:
        return {}


def _instant(value):
    if not value:
        return None
    try:
        ts = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None
    return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)


def daily_completions(project_root: str, now: datetime, days: int = 14) -> tuple[Counter, int]:
    """(completions per UTC day in the window, how many came from partial-completes)."""
    cutoff = now - timedelta(days=days)
    daily: Counter = Counter()
    partial = 0
    for sub in ("completed", "active"):
        d = os.path.join(project_root, ".tasks", sub)
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for name in names:
            if not (name.startswith("T-") and name.endswith(".md")):
                continue
            fm = _frontmatter(os.path.join(d, name))
            if sub == "active" and str(fm.get("status") or "") != "work-completed":
                continue
            ts = _instant(fm.get("date_finished"))
            if ts is None or ts < cutoff or ts > now:
                continue
            daily[ts.strftime("%Y-%m-%d")] += 1
            if sub == "active":
                partial += 1
    return daily, partial


def verdict(project_root: str, now: datetime | None = None) -> str:
    now = now or datetime.now(timezone.utc)
    daily, partial = daily_completions(project_root, now)
    if len(daily) < 4:
        return "PASS insufficient_data"
    recent = [daily.get((now - timedelta(days=i)).strftime("%Y-%m-%d"), 0) for i in range(3)]
    earlier = [daily.get((now - timedelta(days=i)).strftime("%Y-%m-%d"), 0) for i in range(3, 10)]
    recent_avg = sum(recent) / len(recent)
    earlier_avg = sum(earlier) / len(earlier)
    note = f", partial-complete counted={partial}"
    if earlier_avg > 0 and recent_avg < earlier_avg * 0.3:
        return f"WARN drop recent_avg={recent_avg:.1f} vs earlier_avg={earlier_avg:.1f}{note}"
    return f"PASS recent={recent_avg:.1f} earlier={earlier_avg:.1f}{note}"


if __name__ == "__main__":
    print(verdict(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PROJECT_ROOT", ".")))
