"""T-4468: the /search/ask SSE generator must import cleanly and stream an answer.

Origin: T-3012 renamed web.embeddings._db_built_at to _db_opened_at; the lazy
import inside discovery.search_ask's generator still named the old symbol, so
every Ask answer died with ImportError after the page had loaded. The import
only runs when the stream body is iterated, so this test iterates it.
"""
from __future__ import annotations

import time

import pytest


@pytest.fixture
def client():
    from web.app import app

    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_ask_stream_reaches_the_answer(client, monkeypatch):
    import web.ask as ask_mod
    import web.embeddings as E

    # Stub index: a live in-memory handle opened just now, and a retrieval hit.
    monkeypatch.setattr(E, "_db", object())
    monkeypatch.setattr(E, "_db_opened_at", time.time())
    monkeypatch.setattr(E, "rag_retrieve", lambda q, limit=10: [
        {"category": "Agent Docs", "text": "stub", "path": "x.md"}])

    def fake_stream_answer(query, chunks, history=None, model_override=None):
        yield "event: token\ndata: {\"text\": \"STUB-ANSWER\"}\n\n"

    monkeypatch.setattr(ask_mod, "stream_answer", fake_stream_answer)

    resp = client.post("/search/ask", json={"query": "what is the release train?"})
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)  # iterates the generator — the import runs here
    assert "generating" in body
    assert "STUB-ANSWER" in body
