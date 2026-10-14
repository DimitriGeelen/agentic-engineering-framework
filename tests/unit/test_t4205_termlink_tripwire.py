"""T-4205 — regression for the TermLink tripwire (G-115).

Test traffic reached the host's real TermLink outbound queue and fleet channel:
the old receipt tests called `receipts.send` with the default runner, which runs
`termlink channel post` by name, and `termlink` resolved to the host binary. The
tripwire in tests/unit/conftest.py puts a refusing fake first on PATH for every
unit test. These tests prove the old shape now lands on the fake and that the
fixture fails a test which leaves a non-probe call on the record.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import receipts  # noqa: E402

TRIPWIRE = FW_ROOT / "tests" / "lib" / "termlink-tripwire" / "termlink"


def test_termlink_resolves_to_the_tripwire_not_a_host_binary(termlink_tripwire):
    assert shutil.which("termlink") == str(TRIPWIRE)
    assert termlink_tripwire.calls() == []


def test_old_receipt_shape_is_refused_by_the_fake_not_posted_to_a_hub(termlink_tripwire, tmp_path, monkeypatch):
    # The shape the T-3684 / T-3745 tests used: default runner, no injected hub.
    project = tmp_path / "rcpt-b"
    (project / ".context").mkdir(parents=True)
    monkeypatch.setenv("PROJECT_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "rcpt-b")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "0123456789abcdef")
    env = {"client_msg_id": "legacy-1", "from": "old-peer", "conversation_id": "legacy-c"}

    row = receipts.send(env, "RECEIVED", by="t4205")

    assert row["ok"] is False, row  # refused (exit 97), never delivered
    calls = termlink_tripwire.calls()
    assert any(c.startswith("call channel post inbox:0123456789abcdef/rcpt-b/old-peer") for c in calls), calls
    # This test's purpose is that the call was refused; clear the record so the
    # fixture does not fail it for making the call.
    termlink_tripwire.forgive()
