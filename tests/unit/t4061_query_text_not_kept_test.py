"""T-4061 (arc-001 F-9): the operator's query text is not kept outside the answer.

Three leaks, one test group each:
  1. resolver.capture_dispatch wrote the rendered fw ask prompt (query included)
     to <blob>/prompt.txt.
  2. Watchtower /api/v1/search, /api/v1/ask, /api/v1/ask/stream and /search took
     the query only from GET ?q=, so it landed in the request target.
  3. werkzeug's access-log line carries the request target, query string included.
"""

from __future__ import annotations

import logging
import re
import sys
from pathlib import Path

import pytest
import yaml

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))

QUERY = "zebra-marmalade-4061"


@pytest.fixture
def resolver_root(tmp_path, monkeypatch):
    """Isolated project root, resolver reloaded against it (test_resolver pattern)."""
    (tmp_path / ".context" / "project" / "workflows").mkdir(parents=True)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("FW_CAPTURE_QUERY_TEXT", raising=False)
    if "resolver" in sys.modules:
        del sys.modules["resolver"]
    import resolver as r

    return tmp_path, r


def _blob_text(root: Path, row: dict) -> str:
    """Every byte the capture left in the blob directory."""
    blob = root / row["blob_dir"]
    return "".join(p.read_text(errors="replace") for p in blob.rglob("*") if p.is_file())


def test_user_query_capture_leaves_no_query_text(resolver_root):
    root, r = resolver_root
    prompt = f"## Context\nRAG chunks\n\n## Question\n\n{QUERY}"
    _, row = r.capture_dispatch(
        task_id="ask-adhoc",
        workflow={"task_type": "ask", "carries_user_query": True, "worker_kind": "ollama-direct"},
        rendered_prompt=prompt,
    )
    assert QUERY not in _blob_text(root, row)
    assert QUERY not in (root / ".context" / "dispatches.jsonl").read_text()
    assert not (root / row["blob_dir"] / "prompt.txt").exists()
    assert row["prompt_chars"] == len(prompt)
    assert len(row["prompt_sha256"]) == 64


def test_user_query_capture_keeps_text_when_opted_in(resolver_root, monkeypatch):
    root, r = resolver_root
    monkeypatch.setenv("FW_CAPTURE_QUERY_TEXT", "1")
    _, row = r.capture_dispatch(
        task_id="ask-adhoc",
        workflow={"task_type": "ask", "carries_user_query": True},
        rendered_prompt=f"## Question\n\n{QUERY}",
    )
    assert QUERY in (root / row["blob_dir"] / "prompt.txt").read_text()


def test_opt_in_read_from_framework_yaml(resolver_root):
    root, r = resolver_root
    (root / ".framework.yaml").write_text(yaml.safe_dump({"config": {"CAPTURE_QUERY_TEXT": 1}}))
    assert r._capture_query_text_opted_in() is True
    (root / ".framework.yaml").write_text(yaml.safe_dump({"CAPTURE_QUERY_TEXT": 0}))
    assert r._capture_query_text_opted_in() is False


def test_task_worker_capture_still_writes_prompt(resolver_root):
    root, r = resolver_root
    prompt = f"Build the thing. {QUERY}"
    _, row = r.capture_dispatch(
        task_id="T-4061",
        workflow={"task_type": "build", "worker_kind": "TermLink"},
        rendered_prompt=prompt,
    )
    assert (root / row["blob_dir"] / "prompt.txt").read_text() == prompt
    assert "prompt_sha256" not in row


@pytest.fixture
def web_client():
    from web.app import app

    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def _csrf(client) -> str:
    client.get("/search")
    with client.session_transaction() as sess:
        return sess["_csrf_token"]


def test_api_search_accepts_query_in_post_body(web_client, monkeypatch):
    import web.search as search_mod

    seen = {}

    def fake_search(query, limit=30):
        seen["query"] = query
        return {"categories": {}}

    monkeypatch.setattr(search_mod, "search", fake_search)
    monkeypatch.setattr(search_mod, "index_stats", lambda: {})
    resp = web_client.post(
        "/api/v1/search", json={"query": QUERY, "mode": "keyword"},
        headers={"X-CSRF-Token": _csrf(web_client)},
    )
    assert resp.status_code == 200
    assert seen["query"] == QUERY


def test_api_get_search_still_works(web_client, monkeypatch):
    import web.search as search_mod

    monkeypatch.setattr(search_mod, "search", lambda q, limit=30: {"categories": {}})
    monkeypatch.setattr(search_mod, "index_stats", lambda: {})
    resp = web_client.get(f"/api/v1/search?q={QUERY}&mode=keyword")
    assert resp.status_code == 200


def test_search_page_accepts_post_form(web_client, monkeypatch):
    import web.blueprints.discovery as discovery

    seen = {}

    def fake_execute(query, mode):
        seen["query"] = query
        return ({}, None, None)

    monkeypatch.setattr(discovery, "_execute_search", fake_execute)
    resp = web_client.post(
        "/search", data={"q": QUERY, "mode": "hybrid", "_csrf_token": _csrf(web_client)},
    )
    assert resp.status_code == 200
    assert seen["query"] == QUERY


def test_request_log_line_redacts_query(caplog):
    from web.app import QueryRedactFilter  # noqa: F401  (import attaches the filter)

    caplog.set_level(logging.INFO, logger="werkzeug")
    logging.getLogger("werkzeug").info(
        '"%s" %s %s', f"GET /search?q={QUERY}&mode=hybrid HTTP/1.1", "200", "-"
    )
    logging.getLogger("werkzeug").info(
        '"%s" %s %s', f"GET /api/v1/ask?query={QUERY} HTTP/1.1", "200", "-"
    )
    assert QUERY not in caplog.text
    assert "q=[redacted]&mode=hybrid" in caplog.text
    assert "query=[redacted]" in caplog.text


def test_query_redaction_leaves_other_request_lines_alone(caplog):
    from web.app import QueryRedactFilter  # noqa: F401

    caplog.set_level(logging.INFO, logger="werkzeug")
    logging.getLogger("werkzeug").info('"%s" %s %s', "GET /static/app.css HTTP/1.1", "200", "-")
    assert "GET /static/app.css HTTP/1.1" in caplog.text
    assert not re.search(r"\[redacted\]", caplog.text)


def test_watchtower_ui_callers_use_post():
    search_input = (FRAMEWORK_ROOT / "web/templates/_partials/search_input.html").read_text()
    assert 'method="post"' in search_input
    assert 'hx-post="' in search_input
    assert 'name="_csrf_token"' in search_input

    palette = (FRAMEWORK_ROOT / "web/static/command-palette.js").read_text()
    assert "post: { q: query" in palette
    assert '"/search?q="' not in palette

    chips = (FRAMEWORK_ROOT / "web/static/js/search-qa.js").read_text()
    assert "'hx-get', '/search?q='" not in chips
    assert "'hx-post', '/search'" in chips
