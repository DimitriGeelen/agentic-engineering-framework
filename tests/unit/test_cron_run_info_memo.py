"""T-3799: /cron _last_run_info must not re-parse every audit file on each request.

Before the fix, the only cache was a 60 s TTL, so every request after it expired
yaml-parsed all ~800 files in .context/audits/cron/ (13-37 s per render). The tests
force the TTL to 0 to exercise exactly that path: a per-file memo keyed on
(mtime_ns, size) must make the second call parse nothing, and a changed file must
be re-parsed. Nothing under test is mocked except the yaml loader call counter.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
from web.blueprints import cron  # noqa: E402


def _write_audit(d: Path, name: str, section: str, ts: str, pass_: int, mtime: int) -> Path:
    f = d / name
    f.write_text(
        f"timestamp: '{ts}'\n"
        f"sections: {section}\n"
        f"summary:\n  pass: {pass_}\n  warn: 0\n  fail: 0\n"
    )
    os.utime(f, ns=(mtime, mtime))
    return f


@pytest.fixture
def audit_dir(tmp_path, monkeypatch):
    d = tmp_path / "cron"
    d.mkdir()
    for i in range(50):
        # Name order == mtime order == i, because _last_run_info sorts by name.
        _write_audit(d, f"2026-10-01T{i:02d}-00-00Z.yaml",
                     f"sec-{i % 5}", f"2026-10-01T{i:02d}:00:00Z", i,
                     mtime=1_700_000_000_000_000_000 + i * 1_000_000_000)
    monkeypatch.setattr(cron, "AUDIT_CRON_DIR", d)
    monkeypatch.setattr(cron, "_run_info_cache", {"data": None, "count": 0, "ts": 0})
    monkeypatch.setattr(cron, "_audit_memo", {}, raising=False)  # absent pre-fix
    monkeypatch.setattr(cron, "_RUN_INFO_CACHE_TTL", 0)  # force past the TTL every call
    return d


@pytest.fixture
def load_counter(monkeypatch):
    counts = {"n": 0}
    real_load, real_safe = yaml.load, yaml.safe_load

    def counting_load(*a, **k):
        counts["n"] += 1
        return real_load(*a, **k)

    def counting_safe(*a, **k):
        counts["n"] += 1
        return real_safe(*a, **k)

    monkeypatch.setattr(yaml, "load", counting_load)
    monkeypatch.setattr(yaml, "safe_load", counting_safe)
    return counts


def test_second_call_past_ttl_parses_no_files(audit_dir, load_counter):
    first = cron._last_run_info()
    assert load_counter["n"] == 50, "cold call must parse every audit file once"

    load_counter["n"] = 0
    second = cron._last_run_info()
    assert load_counter["n"] == 0, "warm call past the TTL must not re-parse any file"
    assert second == first


def test_changed_file_is_reparsed(audit_dir, load_counter):
    cron._last_run_info()
    target = audit_dir / "2026-10-01T00-00-00Z.yaml"
    # Keep the name; different content and mtime -> stat key changes -> re-parse.
    _write_audit(audit_dir, target.name, "sec-changed", "2026-10-18T00:00:00Z", 99,
                 mtime=1_800_000_000_000_000_000)

    load_counter["n"] = 0
    info = cron._last_run_info()
    assert load_counter["n"] == 1, "only the changed file may be re-parsed"
    assert info["sec-changed"]["pass"] == 99
    assert info["sec-changed"]["file"] == target.name


def test_output_shape_and_newest_wins(audit_dir):
    info = cron._last_run_info()
    # Five sections; each keeps the NEWEST file (highest mtime) for that section.
    assert sorted(info) == [f"sec-{i}" for i in range(5)]
    newest_sec0 = max((i for i in range(50) if i % 5 == 0))
    entry = info["sec-0"]
    assert entry["pass"] == newest_sec0
    assert entry["timestamp"] == f"2026-10-01T{newest_sec0:02d}:00:00Z"
    assert set(entry) == {"timestamp", "pass", "warn", "fail", "file"}
