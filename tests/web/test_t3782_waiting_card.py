"""T-3782: /approvals lists messages waiting for a recipient, with Recover and Drop.

A fixture project holds one stored peer message with a WAITING_NO_RECIPIENT
event; the blueprint's PROJECT_ROOT points at it, so the real
`sidecar_cli.py waiting --json` subprocess reads it. Recover's launcher is
never reached here: the POSTs run with CLAUDECODE stripped (the operator's
click) and the recover test asserts on the refusal path for an unknown id and
on the drop path end to end.
"""
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web.app import app  # noqa: E402
import web.blueprints.approvals as ap  # noqa: E402

FW_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture()
def waiting_project(tmp_path, monkeypatch):
    root = tmp_path / "wt-b"
    msgs = root / ".context/sidecar/receiver/messages"
    msgs.mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: wt-b\n")
    mid = "wtmsg-0001-aaaa"
    stored = datetime.now(timezone.utc).isoformat()
    (msgs / f"{mid}.json").write_text(json.dumps({
        "client_msg_id": mid, "from": "peer-alpha", "conversation_id": "conv-card-9",
        "body": "<script>alert(1)</script> please answer", "urgent": False,
        "_stored_at": stored}))
    (msgs / f"{mid}.ready").write_text("")
    (root / ".context/sidecar/receiver/events.jsonl").write_text(json.dumps({
        "msg_id": mid, "event": "WAITING_NO_RECIPIENT", "ts": stored,
        "reason": "no TermLink session for this project"}) + "\n")
    monkeypatch.setattr(ap, "PROJECT_ROOT", root)
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "reg"))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(tmp_path / "no-hub"))
    ap._WAITING_CACHE.clear()
    app.config["TESTING"] = True
    yield root, mid
    ap._WAITING_CACHE.clear()


def _client_with_token():
    c = app.test_client()
    with c.session_transaction() as s:
        s["_csrf_token"] = "tok"
    return c


def test_card_shows_sender_age_conversation_and_both_actions(waiting_project):
    root, mid = waiting_project
    data = ap._load_waiting_messages()
    assert data["error"] is None and [i["id"] for i in data["items"]] == [mid]
    html = _client_with_token().get("/approvals/content").get_data(as_text=True)
    assert 'id="section-waiting"' in html and "Messages waiting for a recipient" in html
    assert "peer-alpha" in html and "conv-card-9" in html and "min" in html
    assert 'hx-post="/api/sidecar/recover"' in html and 'hx-post="/api/sidecar/drop"' in html
    assert f'value="{mid}"' in html
    assert "<script>alert(1)</script>" not in html      # the body is never rendered
    ctx_total = None
    with app.test_request_context("/"):
        ctx_total = ap._build_approvals_context()["total_count"]
        summary = ap.approval_summary()["total_count"]
    assert ctx_total == summary and ctx_total >= 1


def test_listing_failure_is_an_error_card_not_an_empty_list(waiting_project, monkeypatch):
    monkeypatch.setattr(ap, "FRAMEWORK_ROOT", Path("/nonexistent-framework"))
    data = ap._load_waiting_messages()
    assert data["items"] == [] and data["error"]
    html = _client_with_token().get("/approvals/content").get_data(as_text=True)
    assert "The waiting list could not be read" in html


def test_drop_button_closes_it_with_reason_and_is_csrf_checked(waiting_project):
    root, mid = waiting_project
    c = _client_with_token()
    assert c.post("/api/sidecar/drop", data={"msg_id": mid, "reason": "x"}).status_code == 403
    r = c.post("/api/sidecar/drop", data={"_csrf_token": "tok", "msg_id": mid, "reason": ""})
    assert "a reason is required" in r.get_data(as_text=True)
    r = c.post("/api/sidecar/drop", data={"_csrf_token": "tok", "msg_id": "../etc", "reason": "x"})
    assert r.status_code == 400
    r = c.post("/api/sidecar/drop", data={"_csrf_token": "tok", "msg_id": mid,
                                          "reason": "obsolete question"})
    body = r.get_data(as_text=True)
    assert "Dropped" in body and "obsolete question" in body, body
    rows = [json.loads(l) for l in (root / ".context/sidecar/waiting/closures.jsonl").read_text().splitlines()]
    assert rows[-1]["by"] == "watchtower" and rows[-1]["reason"] == "obsolete question"
    assert ap._load_waiting_messages()["items"] == []


def test_recover_button_refusal_is_shown(waiting_project):
    c = _client_with_token()
    r = c.post("/api/sidecar/recover", data={"_csrf_token": "tok", "msg_id": "no-such-message"})
    assert "Recover refused" in r.get_data(as_text=True)
