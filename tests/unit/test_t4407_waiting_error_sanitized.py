"""T-4407 — the sidecar "waiting" card's error is sanitized at its source.

`_load_waiting_messages` used to cut a 300-char tail from RAW stderr and only
sanitize in the except. A stderr whose reason comes first and whose bypass
instructions follow lost the reason to the cut, the sanitizer then dropped every
remaining line, and the operator saw a bare `RuntimeError`.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from web.blueprints import approvals  # noqa: E402

REASON = "sidecar receiver unreachable on 127.0.0.1"


@pytest.fixture
def failing_cli(tmp_path, monkeypatch):
    (tmp_path / ".context" / "sidecar").mkdir(parents=True)
    monkeypatch.setattr(approvals, "PROJECT_ROOT", tmp_path)
    approvals._WAITING_CACHE.clear()

    def set_stderr(stderr, rc=2):
        def run(argv, **_):
            return subprocess.CompletedProcess(argv, rc, "", stderr)
        monkeypatch.setattr(subprocess, "run", run)
    yield set_stderr
    approvals._WAITING_CACHE.clear()


def test_reason_survives_a_long_tail_of_bypass_instructions(failing_cli):
    bypass = "".join(f"  re-run with --skip-receiver-gate-{i} (logged Tier-2)\n" for i in range(20))
    failing_cli(f"{REASON}\n{bypass}")
    err = approvals._load_waiting_messages()["error"]
    assert REASON in err
    assert "exit 2" in err
    assert "--skip-" not in err


def test_plain_failure_stays_visible_to_the_operator(failing_cli):
    failing_cli(f"{REASON}\n", rc=3)
    value = approvals._load_waiting_messages()
    assert value["items"] == []
    assert value["error"] == f"exit 3: {REASON}"
