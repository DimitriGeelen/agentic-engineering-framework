#!/usr/bin/env python3
"""T-5121 — fw reviewer judge's wait for 'Worker spawned' is a config key, not a hard 120 s.

010 report (msg 341c592f, their T-3777): on a host where dispatch took 60-80 s, reviews ended
'no seat was dispatched' because judge_cli ran `fw termlink dispatch` with timeout=120 and a
TimeoutExpired escaped. The key is REVIEWER_JUDGE_DISPATCH_TIMEOUT (default 120, range 30-3600).
"""
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from lib.reviewer import judge_cli as jc  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / ".framework.yaml").write_text("project_name: t5121\n")
    monkeypatch.delenv("FW_REVIEWER_JUDGE_DISPATCH_TIMEOUT", raising=False)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(ROOT))
    return tmp_path


def test_default_is_120(proj):
    assert jc._dispatch_spawn_timeout(proj) == 120


def test_project_config_overrides(proj):
    (proj / ".framework.yaml").write_text("project_name: t5121\nREVIEWER_JUDGE_DISPATCH_TIMEOUT: 300\n")
    assert jc._dispatch_spawn_timeout(proj) == 300


def test_env_overrides_config(proj, monkeypatch):
    (proj / ".framework.yaml").write_text("project_name: t5121\nREVIEWER_JUDGE_DISPATCH_TIMEOUT: 300\n")
    monkeypatch.setenv("FW_REVIEWER_JUDGE_DISPATCH_TIMEOUT", "450")
    assert jc._dispatch_spawn_timeout(proj) == 450


@pytest.mark.parametrize("bad", ["abc", "0", "-5", "29", "3601", "12.5"])
def test_invalid_or_out_of_range_falls_back_to_120(proj, monkeypatch, bad):
    monkeypatch.setenv("FW_REVIEWER_JUDGE_DISPATCH_TIMEOUT", bad)
    assert jc._dispatch_spawn_timeout(proj) == 120


def test_a_spawn_timeout_names_the_key(proj, monkeypatch):
    monkeypatch.setenv("FW_REVIEWER_JUDGE_DISPATCH_TIMEOUT", "45")
    seen = {}

    def fake_run(argv, **kw):
        seen["timeout"] = kw.get("timeout")
        raise subprocess.TimeoutExpired(argv, kw.get("timeout"))

    monkeypatch.setattr(jc.subprocess, "run", fake_run)
    with pytest.raises(RuntimeError) as e:
        jc._dispatch_real(task_id="T-1", brief="b", root=proj, name="judge-t-1-r1", vendor="claude")
    assert seen["timeout"] == 45
    assert "REVIEWER_JUDGE_DISPATCH_TIMEOUT" in str(e.value) and "45 s" in str(e.value)


def test_registered_in_both_registries():
    assert '"REVIEWER_JUDGE_DISPATCH_TIMEOUT|120|' in (ROOT / "lib/config.sh").read_text()
    assert '("REVIEWER_JUDGE_DISPATCH_TIMEOUT", "120",' in (ROOT / "web/blueprints/config.py").read_text()
