"""T-4430: lib/task_debt.py parses last_update as YAML and never skips silently.

843 of 929 active tasks carry a single-quoted last_update, which the T-4386 port
(and the bash loop before it) failed to parse and skipped as if fresh.
"""
import importlib.util
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "lib" / "task_debt.py"

_spec = importlib.util.spec_from_file_location("task_debt_t4430", SCRIPT)
td = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(td)

UTC_2026 = int(datetime(2026, 1, 1, tzinfo=timezone.utc).timestamp())


def _task(d, name, line):
    p = d / name
    p.write_text(f"---\nid: x\n{line}\nstatus: started-work\n---\n# body\n")
    return p


@pytest.mark.parametrize("line,expected", [
    ("last_update: '2026-01-01T00:00:00Z'", UTC_2026),
    ('last_update: "2026-01-01T00:00:00Z"', UTC_2026),
    ("last_update: 2026-01-01T00:00:00Z", UTC_2026),
    ("last_update: 2026-01-01T02:00:00+02:00", UTC_2026),
    ("last_update: '2026-01-01T02:00:00+02:00'", UTC_2026),
    ("last_update: 2026-01-01T00:00:00Z  # trailing comment", UTC_2026),
])
def test_every_datetime_form_parses(tmp_path, line, expected):
    p = _task(tmp_path, "T-1-a.md", line)
    assert td.to_epoch(td.last_update_value(p)) == expected


@pytest.mark.parametrize("line", [
    "last_update: 2026-01-01",
    "last_update: '2026-01-01'",
])
def test_date_only_parses_as_midnight(tmp_path, line):
    p = _task(tmp_path, "T-1-a.md", line)
    assert td.to_epoch(td.last_update_value(p)) == int(datetime(2026, 1, 1).timestamp())


@pytest.mark.parametrize("line", ["last_update: not a date", "last_update:", "last_update: ''"])
def test_unparseable_is_none(tmp_path, line):
    p = _task(tmp_path, "T-1-a.md", line)
    assert td.to_epoch(td.last_update_value(p)) is None


def test_reads_frontmatter_not_body(tmp_path):
    p = tmp_path / "T-1-a.md"
    p.write_text("---\nid: x\n---\nlast_update: 2020-01-01T00:00:00Z\n")
    assert td.last_update_value(p) is None


def test_count_includes_quoted_and_reports_unparsed(tmp_path):
    _task(tmp_path, "T-1-a.md", "last_update: '2026-01-01T00:00:00Z'")   # stale (quoted)
    _task(tmp_path, "T-2-a.md", 'last_update: "2026-01-02T00:00:00Z"')   # stale
    _task(tmp_path, "T-3-a.md", "last_update: 2026-01-03")               # stale (date-only)
    _task(tmp_path, "T-4-a.md", "last_update: '2026-10-30T00:00:00Z'")   # recent (quoted)
    _task(tmp_path, "T-5-a.md", "last_update: 2026-10-30T00:00:00+02:00")  # recent
    _task(tmp_path, "T-6-a.md", "last_update: garbage")                  # unparsed
    _task(tmp_path, "T-7-a.md", "name: no timestamp")                    # unparsed (missing)
    cutoff = "1790000000"   # 2026-09-21
    r = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path), cutoff],
                       capture_output=True, text=True, timeout=60)
    assert r.returncode == 0
    assert r.stdout.strip() == "5"
    assert "unparsed: 2" in r.stderr
    assert "T-6-a.md" in r.stderr and "T-7-a.md" in r.stderr


def test_no_stderr_when_everything_parses(tmp_path):
    _task(tmp_path, "T-1-a.md", "last_update: '2026-01-01T00:00:00Z'")
    r = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path), "1790000000"],
                       capture_output=True, text=True, timeout=60)
    assert r.stdout.strip() == "1"
    assert r.stderr == ""
