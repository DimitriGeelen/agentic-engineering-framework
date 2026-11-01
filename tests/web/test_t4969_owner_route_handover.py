"""T-4969: Watchtower's ownership field hands a human-owned task over.

The route writes a short-lived record of the operator's request, calls `fw task update --owner X
--from-watchtower`, and removes the record afterwards. update-task.sh accepts the human → agent
change only when that record matches (tests/unit/t4969_owner_handover.bats); typing the flag
alone is refused.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, ".")


@pytest.fixture()
def client(tmp_path, monkeypatch):
    from web.app import app
    from web.blueprints import tasks

    monkeypatch.setattr(tasks, "PROJECT_ROOT", tmp_path)
    app.config["TESTING"] = True
    c = app.test_client()
    with c.session_transaction() as s:
        s["_csrf_token"] = "t4969"
    return c, tasks, tmp_path


def test_route_records_the_request_passes_the_flag_and_cleans_up(client, monkeypatch):
    c, tasks, root = client
    seen = {}

    def fake(args, **_k):
        rec = root / ".context" / "working" / "owner-handover" / "T-9950.json"
        seen["args"] = args
        seen["record"] = json.loads(rec.read_text()) if rec.exists() else None
        return "Owner:   human → agent", "", True
    monkeypatch.setattr(tasks, "run_fw_command", fake)
    resp = c.post("/api/task/T-9950/owner", data={"owner": "agent", "_csrf_token": "t4969"})
    assert resp.status_code == 200 and "Owner set to agent" in resp.get_data(as_text=True)
    assert seen["args"] == ["task", "update", "T-9950", "--owner", "agent", "--from-watchtower"]
    assert seen["record"]["task"] == "T-9950" and seen["record"]["owner"] == "agent"
    assert not (root / ".context" / "working" / "owner-handover" / "T-9950.json").exists()


def test_failed_update_still_removes_the_record_and_shows_the_error(client, monkeypatch):
    c, tasks, root = client
    monkeypatch.setattr(tasks, "run_fw_command",
                        lambda args, **_k: ("", "ERROR: refused (R-033)", False))
    resp = c.post("/api/task/T-9950/owner", data={"owner": "agent", "_csrf_token": "t4969"})
    assert resp.status_code == 500 and "R-033" in resp.get_data(as_text=True)
    assert not (root / ".context" / "working" / "owner-handover" / "T-9950.json").exists()


def test_without_csrf_nothing_is_recorded_or_run(client, monkeypatch):
    c, tasks, root = client
    called = []
    monkeypatch.setattr(tasks, "run_fw_command", lambda *a, **k: called.append(a) or ("", "", True))
    resp = c.post("/api/task/T-9950/owner", data={"owner": "agent"})
    assert resp.status_code == 403
    assert not called
    assert not (root / ".context" / "working" / "owner-handover").exists()
