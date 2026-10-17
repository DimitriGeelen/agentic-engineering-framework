"""T-3083 — held_unsurfaced re-read the sent-receipts ledger once per held message.

`fw doctor`'s TermLink phase spent 30-48 s in fw_sidecar_held_unsurfaced_facts:
inject.held_unsurfaced called seen.withheld([mid]) per message, and every call
re-parsed the whole receipts ledger (90 held x ~36k rows = 3.2M json.loads).
The fix asks withheld() once for the whole set. Same verdict, one ledger read.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, inject, receipts, receiver, seen  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t3083"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3083\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    return root


def _store_old(mid):
    env = {"client_msg_id": mid, "from": "peer", "body": f"body-{mid}",
           "conversation_id": "c"}
    assert receiver.store_message(mid, env)[0]
    path = receiver._message_path(mid)
    msg = json.loads(path.read_text(encoding="utf-8"))
    msg["_stored_at"] = (datetime.now(timezone.utc) - timedelta(hours=30)).isoformat()
    path.write_text(json.dumps(msg), encoding="utf-8")


def test_held_unsurfaced_reads_receipts_ledger_once_and_keeps_verdict(proj, monkeypatch):
    ids = [f"m-{i}" for i in range(6)]
    for mid in ids:
        _store_old(mid)
    seen.mark_shown([("m-0", receiver.read_message("m-0"))], by="hook")

    calls = {"n": 0}
    real = receipts.read_sent

    def counting():
        calls["n"] += 1
        return real()

    monkeypatch.setattr(receipts, "read_sent", counting)
    rows = inject.held_unsurfaced(threshold_hours=24)

    assert sorted(r["msg_id"] for r in rows) == ids[1:], "shown mail drops out, the rest stays"
    assert calls["n"] <= 1, f"receipts ledger parsed {calls['n']}x for {len(ids)} held messages"
