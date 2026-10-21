"""T-4164: `lib/estate_recall.py` — the estate read side (T-4091 slice 3).

Fakes only: a fake HTTP layer for the unit tests and a loopback HTTP server for the
`fw recall` end-to-end tests. Nothing here touches the live estate store or embedder.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import estate_ingest as ei  # noqa: E402
import estate_push as ep  # noqa: E402
import estate_recall as er  # noqa: E402

OWN = "aef"
VEC = [0.1] * ei.DIMS
FIELDS = ("project", "ref", "item_type", "recorded", "confirmed", "evidence", "status", "model",
          "version", "guarded_by")


def point(project, score, **payload):
    base = {"tenant": "estate", "project": project, "model": ei.MODEL, "item_type": "learning",
            "task_id": f"T-{int(score * 1000)}", "source_path": "x.md", "observed_on": "2026-10-01",
            "framework_version": "1.8.0", "text": f"{project} text {score}"}
    base.update(payload)
    return {"id": "p", "score": score, "payload": base}


class FakeHttp:
    """Records every call; answers embed and search like Ollama and Qdrant would."""

    def __init__(self, points=(), search_status=200, embed_status=200, store_exc=None, embed_exc=None):
        self.points = list(points)
        self.search_status, self.embed_status = search_status, embed_status
        self.store_exc, self.embed_exc = store_exc, embed_exc
        self.calls = []

    def __call__(self, method, url, token, body=None):
        self.calls.append((method, url, token, body))
        if url.endswith("/api/embed"):
            if self.embed_exc:
                raise self.embed_exc
            return self.embed_status, ({"embeddings": [VEC]} if self.embed_status == 200 else {})
        if self.store_exc:
            raise self.store_exc
        return self.search_status, {"result": self.points}


def run(fake, scope="both", **kw):
    return er.recall("budget", own=OWN, scope=scope, store_url="http://store", embed_host="http://emb",
                     token="tok", http=fake, **kw)


# ── query embedding and request shape ────────────────────────────────────────

def test_query_is_embedded_with_the_pinned_ingest_model():
    fake = FakeHttp([point("other", 0.9)])
    run(fake)
    embed = [c for c in fake.calls if c[1].endswith("/api/embed")]
    assert embed and embed[0][3]["model"] == ei.MODEL
    assert er.ei.MODEL is ei.MODEL  # one constant, shared with ingest — not a copy


def test_search_targets_main_collection_with_token_and_tenant_filter():
    fake = FakeHttp([point("other", 0.9)])
    run(fake, scope="estate")
    _m, url, token, body = [c for c in fake.calls if "/collections/" in c[1]][0]
    assert url == f"http://store/collections/{ei.MAIN}/points/search"
    assert token == "tok"
    assert body["vector"] == VEC
    assert {"key": "tenant", "match": {"value": "estate"}} in body["filter"]["must"]
    assert "must_not" not in body["filter"]  # estate scope includes own items


def test_both_scope_excludes_own_project_from_the_estate_query():
    fake = FakeHttp([point("other", 0.9)])
    run(fake, scope="both")
    body = [c for c in fake.calls if "/collections/" in c[1]][0][3]
    assert body["filter"]["must_not"] == [{"key": "project", "match": {"value": OWN}}]


def test_own_scope_is_not_served_by_the_estate():
    with pytest.raises(ValueError):
        run(FakeHttp(), scope="own")


# ── provenance (R-12, R-33, R-34) ────────────────────────────────────────────

def test_every_hit_carries_every_provenance_field_non_empty():
    bare = {"id": "p", "score": 0.5, "payload": {"text": "t"}}
    hits = run(FakeHttp([point("other", 0.9), bare]), scope="estate")
    assert len(hits) == 2
    for h in hits:
        for f in FIELDS:
            assert h[f], f"{f} empty"
    missing = [h for h in hits if h["project"] == er.UNRECORDED][0]
    assert missing["evidence"] == er.UNRECORDED and missing["status"] == er.UNRECORDED


def test_provenance_line_names_version_when_never_reconfirmed():
    h = er.normalise(point("other", 0.8), OWN)
    line = er.provenance(h)
    assert "true at 1.8.0, not re-observed since 2026-10-01" in line
    assert f"model {ei.MODEL}" in line and "score 0.800" in line and "evidence unrecorded" in line
    h2 = er.normalise(point("other", 0.8, last_confirmed="2026-10-20"), OWN)
    assert "confirmed 2026-10-20" in er.provenance(h2)


def test_cross_project_hits_are_labelled_and_own_hits_are_not():
    cross = er.normalise(point("other", 0.8), OWN)
    own = er.normalise(point(OWN, 0.8), OWN)
    assert er.format_hit(cross)[0].startswith("  [cross-project: other] ")
    assert er.format_hit(own)[0].startswith(f"  [own: {OWN}] ")
    chunk = er.as_chunk(cross)
    assert chunk["cross_project"] and chunk["title"].startswith("[cross-project: other]")
    assert chunk["chunk_text"].startswith("Provenance: ")


def test_peer_report_never_shows_evidence_tested():
    h = er.normalise(point("other", 0.8, item_type="peer-report", evidence="tested"), OWN)
    assert h["evidence"] == "peer report"


# ── ranking (R-14) ───────────────────────────────────────────────────────────

def H(project, score, **kw):
    return er.normalise(point(project, score, **kw), OWN)


def order(hits):
    return [(h["project"], h["score"]) for h in hits]


def test_default_keeps_own_first_within_margin():
    out = er.rank([H("other", 0.83), H(OWN, 0.80)], margin=0.05)
    assert order(out) == [(OWN, 0.80), ("other", 0.83)]


def test_default_lets_a_clearly_better_cross_hit_lead():
    out = er.rank([H("other", 0.90), H(OWN, 0.80)], margin=0.05)
    assert order(out) == [("other", 0.90), (OWN, 0.80)]


def test_default_newer_tested_cross_hit_ranks_above_own_within_margin():
    newer = H("other", 0.82, evidence="tested", observed_on="2026-10-20")
    out = er.rank([newer, H(OWN, 0.80, observed_on="2026-10-01")], margin=0.05)
    assert order(out)[0] == ("other", 0.82)
    untested = H("other", 0.82, evidence="observed", observed_on="2026-10-20")
    assert order(er.rank([untested, H(OWN, 0.80)], margin=0.05))[0] == (OWN, 0.80)


def test_solution_finder_puts_other_projects_first():
    out = er.rank([H(OWN, 0.95), H("other", 0.40), H("third", 0.60)], mode="solution-finder")
    assert order(out) == [("third", 0.60), ("other", 0.40), (OWN, 0.95)]


def test_superseded_and_retired_are_out_unless_asked_for():
    hits = [H("other", 0.9, status="superseded"), H("other", 0.8, status="retired"), H(OWN, 0.5)]
    assert order(er.rank(hits)) == [(OWN, 0.5)]
    assert len(er.rank(hits, include_superseded=True)) == 3


def test_unknown_mode_refused():
    with pytest.raises(ValueError):
        er.rank([], mode="random")


def test_recall_caps_at_limit():
    pts = [point("other", 0.1 * i) for i in range(1, 9)]
    assert len(run(FakeHttp(pts), limit=3)) == 3


# ── unavailable (R-16) ───────────────────────────────────────────────────────

@pytest.mark.parametrize("fake,reason", [
    (FakeHttp(store_exc=ConnectionRefusedError()), "estate store unreachable"),
    (FakeHttp(search_status=403), "refused the read token"),
    (FakeHttp(search_status=500), "estate store HTTP 500"),
    (FakeHttp(embed_exc=OSError("down")), "embedder unreachable"),
    (FakeHttp(embed_status=404), "embedder gave no"),
])
def test_store_or_embedder_down_is_estate_unavailable(fake, reason):
    with pytest.raises(er.EstateUnavailable, match=reason):
        run(fake)


def test_missing_read_token_is_estate_unavailable_not_exit(monkeypatch):
    def miss(*_a):
        sys.exit("estate read: no token")
    monkeypatch.setattr(ep, "resolve_token", miss)
    with pytest.raises(er.EstateUnavailable, match="no token"):
        er.read_token()


# ── end to end: fw recall against a loopback estate ──────────────────────────

class _Estate(BaseHTTPRequestHandler):
    points: list = []

    def do_POST(self):  # noqa: N802
        n = int(self.headers.get("Content-Length") or 0)
        self.rfile.read(n)
        if self.path == "/api/embed":
            body = {"embeddings": [VEC]}
        elif self.path == f"/collections/{ei.MAIN}/points/search":
            if self.headers.get("api-key") != "tok":
                self.send_response(403)
                self.end_headers()
                return
            body = {"result": self.points}
        else:
            self.send_response(404)
            self.end_headers()
            return
        raw = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, *_a):
        pass


@pytest.fixture
def estate_server():
    _Estate.points = [point("other-project", 0.91, text="cross project lesson about budget")]
    srv = HTTPServer(("127.0.0.1", 0), _Estate)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{srv.server_address[1]}"
    srv.shutdown()


def recall_cli(url, *args, token="tok"):
    env = dict(os.environ, FW_ESTATE_QDRANT_URL=url, FW_EMBED_HOST=url, FW_RECALL_NO_BANNER="1",
               FW_QDRANT_ESTATE_READ_AEF_API_KEY=token, PROJECT_ROOT=str(ROOT), FRAMEWORK_ROOT=str(ROOT))
    return subprocess.run([sys.executable, str(ROOT / "agents/context/lib/memory-recall.py"),
                           "--no-hybrid", "--query", "context budget", *args],
                          capture_output=True, text=True, env=env, timeout=120)


def test_cli_both_scope_shows_labelled_cross_project_hit(estate_server):
    r = recall_cli(estate_server, "--scope", "both")
    assert r.returncode == 0, r.stderr
    assert "Estate knowledge:" in r.stdout
    assert "[cross-project: other-project] T-910" in r.stdout
    assert f"model {ei.MODEL}" in r.stdout
    assert "estate unavailable" not in r.stdout


def test_cli_estate_unreachable_answers_locally_with_banner():
    r = recall_cli("http://127.0.0.1:9", "--scope", "both")
    assert r.returncode == 0, r.stderr
    assert "estate unavailable:" in r.stdout
    assert "Estate knowledge:" not in r.stdout


def test_cli_store_refuses_token_answers_locally_with_banner(estate_server):
    r = recall_cli(estate_server, "--scope", "estate", token="wrong")
    assert r.returncode == 0, r.stderr
    assert "estate unavailable: estate store refused the read token (HTTP 403)" in r.stdout


def test_cli_own_scope_never_contacts_the_estate():
    r = recall_cli("http://127.0.0.1:9")
    assert r.returncode == 0, r.stderr
    assert "estate" not in r.stdout.lower()


# ── fw ask: estate chunks join the context, fallback keeps the local ones ───

def _ask_module():
    pytest.importorskip("ollama")
    import importlib.util
    spec = importlib.util.spec_from_file_location("fw_ask_t4164", ROOT / "lib" / "ask.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_ask_estate_context_adds_labelled_chunks_and_falls_back():
    ask = _ask_module()
    local = [{"title": "own chunk", "chunk_text": "x"}]
    fake = FakeHttp([point("other", 0.9)])
    kw = dict(store_url="http://store", embed_host="http://emb", token="tok", http=fake)
    chunks, est = ask.estate_context("q", local, scope="both", **kw)
    assert est["available"] is True and chunks[0] is local[0]
    assert chunks[1]["title"].startswith("[cross-project: other]")
    chunks, est = ask.estate_context("q", local, scope="estate", **kw)
    assert [c["project"] for c in chunks] == ["other"]
    down = dict(kw, http=FakeHttp(store_exc=ConnectionRefusedError()))
    chunks, est = ask.estate_context("q", local, scope="estate", **down)
    assert chunks == local and est["available"] is False and "unreachable" in est["reason"]
    chunks, est = ask.estate_context("q", local, scope="own", **kw)
    assert chunks == local and est["available"] is None
