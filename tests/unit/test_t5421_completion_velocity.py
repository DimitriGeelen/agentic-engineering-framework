"""T-5421 (050 item 2): D6 completion velocity counts partial-complete tasks.

A task whose agent work is done but whose Human criteria are open stays in
.tasks/active/ with status work-completed and a date_finished. D6 counted only
.tasks/completed/, so a project with many such tasks read a false 0.0 "sustained drop".
"""
from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import completion_velocity as cv  # noqa: E402

NOW = datetime(2026, 11, 25, 12, 0, tzinfo=timezone.utc)


def _task(root: Path, sub: str, n: int, days_ago: float, status: str = "work-completed"):
    d = root / ".tasks" / sub
    d.mkdir(parents=True, exist_ok=True)
    fin = (NOW - timedelta(days=days_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")
    (d / f"T-{n}-x.md").write_text(f"---\nid: T-{n}\nstatus: {status}\ndate_finished: {fin}\n---\n# x\n")


def _earlier_week(root, start=100):
    n = start
    for day in range(3, 10):
        for _ in range(2):
            _task(root, "completed", n, day + 0.1)
            n += 1


def test_recent_partial_completes_are_counted_and_no_false_drop(tmp_path):
    _earlier_week(tmp_path)
    for i, day in enumerate((0.1, 1.1, 2.1)):
        _task(tmp_path, "active", 500 + 2 * i, day)
        _task(tmp_path, "active", 501 + 2 * i, day)
    out = cv.verdict(str(tmp_path), NOW)
    assert out.startswith("PASS"), out
    assert "recent=2.0" in out and "partial-complete counted=6" in out


def test_the_old_reading_was_a_false_drop(tmp_path, monkeypatch):
    """Control: ignoring active/ reproduces 050's 0.0."""
    _earlier_week(tmp_path)
    for i, day in enumerate((0.1, 1.1, 2.1)):
        _task(tmp_path, "active", 500 + i, day)
    real = cv.daily_completions

    def completed_only(root, now, days=14):
        daily, _ = real(root, now, days)
        for i, day in enumerate((0.1, 1.1, 2.1)):
            daily[(now - timedelta(days=day)).strftime("%Y-%m-%d")] -= 1
        return daily, 0
    monkeypatch.setattr(cv, "daily_completions", completed_only)
    assert cv.verdict(str(tmp_path), NOW).startswith("WARN drop recent_avg=0.0")


def test_a_real_drop_still_warns(tmp_path):
    _earlier_week(tmp_path)
    assert cv.verdict(str(tmp_path), NOW).startswith("WARN drop recent_avg=0.0 vs earlier_avg=2.0")


def test_active_tasks_not_work_completed_are_not_counted(tmp_path):
    _earlier_week(tmp_path)
    _task(tmp_path, "active", 900, 0.1, status="started-work")
    daily, partial = cv.daily_completions(str(tmp_path), NOW)
    assert partial == 0 and sum(daily.values()) == 14


def test_audit_calls_the_module():
    src = (ROOT / "agents/audit/audit.sh").read_text()
    assert "lib/completion_velocity.py" in src and "D6EOF" not in src
