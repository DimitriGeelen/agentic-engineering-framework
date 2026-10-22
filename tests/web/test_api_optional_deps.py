"""T-4657: /api/v1 endpoints degrade cleanly when an optional stack is missing.

The LLM (web.llm + ollama), embeddings (web.embeddings: ollama, sqlite_vec)
and keyword search (web.search: tantivy) stacks are optional installs. When one
cannot be imported the API answers in JSON: health 200 "degraded", ask and
ask/stream 503, search falls back to keyword. Before the fix every one of
these was a 500 HTML page (ring20 patches #28, #30).

A module is made unimportable by setting its sys.modules entry to None, which
makes `import x` raise ImportError the same way a missing package does.
"""

import sys

import pytest


@pytest.fixture()
def client():
    from web.app import app
    app.config["TESTING"] = True
    app.config["PROPAGATE_EXCEPTIONS"] = False
    c = app.test_client()
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "t4657"
    return c


CSRF = {"X-CSRF-Token": "t4657"}


def _hide(monkeypatch, *names):
    for name in names:
        monkeypatch.setitem(sys.modules, name, None)


def _json(resp):
    assert resp.is_json, resp.data[:200]
    return resp.get_json()


def test_health_degraded_when_llm_missing(client, monkeypatch):
    _hide(monkeypatch, "web.llm")
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    body = _json(resp)
    assert body["status"] == "degraded"
    assert "llm" in body["missing"]


def test_health_degraded_when_ollama_package_missing(client, monkeypatch):
    import web.llm

    def no_ollama():
        raise ModuleNotFoundError("No module named 'ollama'", name="ollama")

    monkeypatch.setattr(web.llm, "get_manager", no_ollama)
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    body = _json(resp)
    assert body["status"] == "degraded"
    assert "llm" in body["missing"]


def test_health_names_missing_embeddings_and_search(client, monkeypatch):
    _hide(monkeypatch, "web.embeddings", "web.search")
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    body = _json(resp)
    assert body["status"] == "degraded"
    assert {"embeddings", "search"} <= set(body["missing"])


@pytest.mark.parametrize("hidden", ["web.llm", "web.ask", "web.embeddings"])
def test_ask_503_json_when_stack_missing(client, monkeypatch, hidden):
    _hide(monkeypatch, hidden)
    resp = client.post("/api/v1/ask", json={"query": "what is healing"}, headers=CSRF)
    assert resp.status_code == 503
    body = _json(resp)
    assert body["error"]
    assert body["missing"]


@pytest.mark.parametrize("hidden", ["web.llm", "web.ask", "web.embeddings"])
def test_ask_stream_503_json_when_stack_missing(client, monkeypatch, hidden):
    _hide(monkeypatch, hidden)
    resp = client.post("/api/v1/ask/stream", json={"query": "what is healing"}, headers=CSRF)
    assert resp.status_code == 503
    body = _json(resp)
    assert body["error"]
    assert body["missing"]


def test_ask_503_when_ollama_package_missing(client, monkeypatch):
    import web.llm

    def no_ollama():
        raise ModuleNotFoundError("No module named 'ollama'", name="ollama")

    monkeypatch.setattr(web.llm, "get_manager", no_ollama)
    resp = client.post("/api/v1/ask", json={"query": "what is healing"}, headers=CSRF)
    assert resp.status_code == 503
    assert _json(resp)["missing"]


@pytest.mark.parametrize("mode", ["semantic", "hybrid"])
def test_search_falls_back_to_keyword_without_embeddings(client, monkeypatch, mode):
    import web.search

    def fake_bm25(query, *a, **kw):
        return {"categories": {"tasks": [{"title": "T-1", "path": "x"}]}}

    monkeypatch.setattr(web.search, "search", fake_bm25)
    monkeypatch.setattr(web.search, "index_stats", lambda: {"docs": 1})
    _hide(monkeypatch, "web.embeddings")
    resp = client.post("/api/v1/search", json={"query": "healing", "mode": mode}, headers=CSRF)
    assert resp.status_code == 200
    body = _json(resp)
    assert body["degraded"] is True
    assert body["mode"] == "keyword"
    assert "embeddings" in body["missing"]
    assert body["results"][0]["category"] == "tasks"


def test_search_503_json_when_keyword_stack_missing(client, monkeypatch):
    _hide(monkeypatch, "web.search")
    resp = client.post("/api/v1/search", json={"query": "healing", "mode": "keyword"}, headers=CSRF)
    assert resp.status_code == 503
    body = _json(resp)
    assert body["error"]
    assert "search" in body["missing"]
