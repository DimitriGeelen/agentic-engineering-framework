"""T-5151: a changed blueprint's GET route that answers a bare GET with 4xx (/ask, /ask/stream,
/search/load-conversation) is not a page on its own; requiring a screenshot of it made every
reviewer seat return not-evaluated on T-3786. Such routes are dropped from the required pages
unless a criterion names them, and the brief says which were left out and why.
"""
from __future__ import annotations

import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.reviewer import judge_cli  # noqa: E402

CODES = {"/ok": 200, "/redir": 302, "/ask": 404, "/stream": 400, "/boom": 500}


class _H(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        code = CODES.get(self.path, 404)
        self.send_response(code)
        if code == 302:
            self.send_header("Location", "/ok")
        self.end_headers()

    def log_message(self, *a):
        pass


@pytest.fixture()
def server():
    srv = HTTPServer(("127.0.0.1", 0), _H)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{srv.server_port}"
    srv.shutdown()


def test_only_4xx_are_refusals(server):
    out = judge_cli._bare_get_refusals(server, ["/ok", "/redir", "/ask", "/stream", "/boom"])
    assert out == {"/ask": "HTTP 404", "/stream": "HTTP 400"}


def test_unreachable_server_keeps_every_page():
    assert judge_cli._bare_get_refusals("http://127.0.0.1:9", ["/ask"]) == {}
    assert judge_cli._bare_get_refusals("", ["/ask"]) == {}


def _evidence(monkeypatch, server, pages, named):
    monkeypatch.setattr(judge_cli, "_pages_for", lambda *a, **k: list(pages))
    monkeypatch.setattr(judge_cli, "_criterion_pages", lambda root, body: list(named))
    monkeypatch.setattr(judge_cli, "_watchtower_url", lambda root: server)
    monkeypatch.setattr(judge_cli, "_gather_visual", lambda *a, **k: {})
    crit = [{"index": 1, "ac_index": 1, "body": "x", "render": True}]
    return judge_cli._gather_evidence(Path("."), "T-9999", {"text": ""}, crit, None, dry_run=True)


def test_derived_4xx_route_dropped(monkeypatch, server):
    ev = _evidence(monkeypatch, server, ["/ok", "/ask"], named=[])
    assert ev["pages"] == ["/ok"] and ev["not_pages"] == {"/ask": "HTTP 404"}


def test_named_page_kept_even_when_4xx(monkeypatch, server):
    ev = _evidence(monkeypatch, server, ["/ok", "/ask"], named=["/ask"])
    assert ev["pages"] == ["/ok", "/ask"] and ev["not_pages"] == {}


def test_brief_names_what_was_left_out():
    ev = {"needed": True, "shots": [], "error": "x", "pages": ["/ok"],
          "not_pages": {"/ask": "HTTP 404"}}
    b = judge_cli._build_brief("T-9999", [{"index": 1, "ac_index": 1, "body": "x", "render": True}],
                               evidence=ev)
    assert "not a page on its own" in b and "`/ask` (HTTP 404)" in b


def test_brief_silent_when_nothing_left_out():
    ev = {"needed": True, "shots": [], "error": "x", "pages": ["/ok"], "not_pages": {}}
    b = judge_cli._build_brief("T-9999", [{"index": 1, "ac_index": 1, "body": "x", "render": True}],
                               evidence=ev)
    assert "not a page on its own" not in b
