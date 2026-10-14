"""T-4163: `lib/estate_ingest.py` — the central ingest worker (T-4091 slice 2).

Everything runs against fakes: a dict-backed store, a fake embedder and a fake
HTTP layer. Nothing here touches the live estate store.
"""
from __future__ import annotations

import datetime as dt
import json
import sys
import uuid
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import estate_ingest as ei  # noqa: E402
import estate_push as ep  # noqa: E402

PROJECT = "aef"
STAGING = "staging_aef"
DIGEST = "sha256:" + "d" * 64
# ring20's recorded digest for nomic-embed-text-v2-moe:latest (msg f963ca58), as Ollama's /api/tags gives it
RING20_DIGEST = "ff9c2f10ef5e3722623a1b396e1e04efc27a93112c83e9b7b7b9ca1d05620965"
PATTERNS = [("GitHub PAT", r"gh[pousr]_[A-Za-z0-9]{36,}")]
GHP = "gh" + "p_" + "a" * 36  # built at run time: the source never holds a secret shape
DAY = dt.datetime(2026, 10, 13, 14, 0)  # daytime
NIGHT = dt.datetime(2026, 10, 13, 2, 0)


class FakeStore:
    """Dict-backed stand-in for the Qdrant calls the worker makes."""

    def __init__(self, manifest: object = "registered"):
        self.cols = {STAGING: {}, ei.MAIN: {}}
        if manifest == "registered":
            manifest = entry("candidate", None)
        self.manifest = manifest
        self.log = []

    def get_manifest(self, token, collection):
        self.log.append(("manifest", collection))
        return self.manifest

    def scroll(self, token, collection, limit=256):
        self.log.append(("scroll", collection))
        return [{"id": k, "payload": v["payload"]} for k, v in self.cols[collection].items()][:limit]

    def upsert(self, token, collection, points):
        self.log.append(("upsert", collection, len(points)))
        for p in points:
            self.cols[collection][p["id"]] = {"payload": p["payload"], "vector": p["vector"]}

    def delete(self, token, collection, ids):
        self.log.append(("delete", collection, len(ids)))
        for i in ids:
            self.cols[collection].pop(i, None)

    def __getattr__(self, name):  # any other store call (a _manifest write included) fails the test
        raise AssertionError(f"worker made an unexpected store call: {name}")


def entry(state, digest, dims=ei.DIMS):
    """A `_manifest` entry as ring20 writes it (payload keys per msg f963ca58)."""
    return {"id": "m1", "payload": {"collection": ei.MAIN, "alias": "estate_knowledge", "state": state,
                                    "model_id": ei.MODEL, "model_digest": digest, "dims": dims,
                                    "owner": "ring20"}}


class FakeEmbedder:
    def __init__(self, fail_times=0):
        self.calls = []
        self.fail_times = fail_times

    def embed(self, model, inputs):
        self.calls.append((model, len(inputs)))
        if self.fail_times:
            self.fail_times -= 1
            raise RuntimeError("ollama busy")
        return [[0.1] * ei.DIMS for _ in inputs]


def staged(key, text, op="upsert", project=PROJECT):
    h = ep._sha(text)
    payload = {"tenant": "estate", "project": project, "category": "episodic", "item_type": "episodic",
               "source_path": "x.md", "task_id": "T-1", "content_hash": h, "chunk_index": 0,
               "observed_on": "2026-10-13", "framework_version": "1.0", "chunk_key": key, "op": op}
    if op == "upsert":
        payload["text"] = text
    return {"id": str(uuid.uuid5(ep._NS, f"{key}|{h}|{op}")), "payload": payload}


def seed(store, *points):
    for p in points:
        store.cols[STAGING][p["id"]] = {"payload": p["payload"], "vector": {}}


def run(store, *, emb=None, apply=True, now=DAY, allow_daytime=False, killed=(), max_points=50_000, digest=DIGEST):
    return ei.drain(PROJECT, store=store, token="tok", embedder=emb or FakeEmbedder(), digest=digest,
                    staging=STAGING, patterns=PATTERNS, now=now, apply=apply, allow_daytime=allow_daytime,
                    killed=set(killed), max_points=max_points, audit=lambda row: None, sleep=lambda s: None)


def test_drain_writes_main_with_model_and_digest_then_drains_staging():
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"), staged(f"{PROJECT}|b.md|0", "beta"))
    out = run(store)
    assert out["written"] == 2
    assert len(store.cols[ei.MAIN]) == 2
    for p in store.cols[ei.MAIN].values():
        assert p["payload"]["model"] == ei.MODEL and p["payload"]["digest"] == DIGEST
        assert len(p["vector"]) == ei.DIMS
    assert store.cols[STAGING] == {}, "drained staging points must be deleted after the main write"


def test_manifest_is_never_written_and_left_as_ring20_set_it():
    # The ingest token is _manifest:r only: a write would be a 403. The worker only reads.
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    before = json.dumps(store.manifest, sort_keys=True)
    assert run(store)["written"] == 1
    assert json.dumps(store.manifest, sort_keys=True) == before
    assert not hasattr(ei.QdrantStore, "set_manifest_active")


def test_no_http_write_reaches_manifest_through_the_real_store_client():
    """Full drain through QdrantStore over a fake HTTP layer: only a read (scroll) touches _manifest."""
    calls = []
    staged_pt = staged(f"{PROJECT}|a.md|0", "alpha")

    def http(method, url, token, body=None):
        calls.append((method, url))
        if f"/collections/{ei.MANIFEST}/points/scroll" in url:
            return 200, {"result": {"points": [entry("active", RING20_DIGEST)]}}
        if url.endswith(f"/collections/{STAGING}/points/scroll"):
            return 200, {"result": {"points": [staged_pt], "next_page_offset": None}}
        return 200, {"result": {}}

    out = ei.drain(PROJECT, store=ei.QdrantStore("https://q.example", http=http), token="tok",
                   embedder=FakeEmbedder(), digest=RING20_DIGEST, staging=STAGING, patterns=PATTERNS,
                   now=NIGHT, apply=True, allow_daytime=False, killed=set(), max_points=50_000,
                   audit=lambda row: None, sleep=lambda s: None)
    assert out["written"] == 1
    manifest_calls = [c for c in calls if f"/collections/{ei.MANIFEST}/" in c[1]]
    assert manifest_calls == [("POST", f"https://q.example/collections/{ei.MANIFEST}/points/scroll")]


@pytest.mark.parametrize("state", ["candidate", "active"])
def test_candidate_and_active_entries_are_accepted(state):
    store = FakeStore(manifest=entry(state, None))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    assert run(store)["written"] == 1


@pytest.mark.parametrize("state", ["retired", None, "draft"])
def test_retired_or_unknown_state_is_refused(state):
    store = FakeStore(manifest=entry(state, None))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="state"):
        run(store)
    assert store.cols[ei.MAIN] == {} and len(store.cols[STAGING]) == 1


@pytest.mark.parametrize("dims", [384, 1024, None])
def test_entry_with_other_dims_is_refused(dims):
    store = FakeStore(manifest=entry("active", None, dims=dims))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="dims"):
        run(store)
    assert store.cols[ei.MAIN] == {}


@pytest.mark.parametrize("pinned", [RING20_DIGEST, "sha256:" + RING20_DIGEST])
def test_digest_matching_ring20_entry_is_accepted(pinned):
    # Ollama's /api/tags gives bare hex; a sha256: prefix on either side compares equal.
    store = FakeStore(manifest=entry("active", pinned))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    assert run(store, digest=RING20_DIGEST)["written"] == 1


def test_digest_mismatch_with_ring20_entry_is_refused():
    store = FakeStore(manifest=entry("active", RING20_DIGEST))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="digest"):
        run(store, digest="0" * 64)
    assert store.cols[ei.MAIN] == {} and len(store.cols[STAGING]) == 1


@pytest.mark.parametrize("unset", [None, ""])
def test_digest_unset_in_entry_is_accepted(unset):
    store = FakeStore(manifest=entry("candidate", unset))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    assert run(store, digest="0" * 64)["written"] == 1


def test_apply_without_a_local_digest_is_refused_when_entry_pins_one():
    store = FakeStore(manifest=entry("active", RING20_DIGEST))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="no digest"):
        run(store, digest="")
    assert run(store, digest="", apply=False)["pending"] == 1  # a dry run has nothing to compare


def test_unregistered_collection_is_refused_and_nothing_is_written():
    store = FakeStore(manifest=None)  # no _manifest entry for the target
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="not registered"):
        run(store)
    assert store.cols[ei.MAIN] == {} and len(store.cols[STAGING]) == 1


def test_digest_mismatch_with_pinned_manifest_is_refused():
    store = FakeStore(manifest=entry("active", "sha256:" + "e" * 64))
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="digest"):
        run(store)
    assert store.cols[ei.MAIN] == {}


def test_switched_off_project_is_refused():
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(ei.Refused, match="switched off"):
        run(store, killed={PROJECT})
    assert store.cols[ei.MAIN] == {}


def test_point_claiming_another_project_is_refused_not_written():
    store = FakeStore()
    seed(store, staged("other|a.md|0", "alpha", project="other"))
    out = run(store)
    assert out["written"] == 0 and out["refused"] == 1
    assert store.cols[ei.MAIN] == {}


def test_second_secret_scan_refuses_before_write():
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", f"token {GHP}"), staged(f"{PROJECT}|b.md|0", "clean"))
    out = run(store)
    assert out["refused"] == 1 and out["written"] == 1
    assert all(p["payload"]["text"] == "clean" for p in store.cols[ei.MAIN].values())


def test_deletions_remove_main_points_by_stable_id():
    store = FakeStore()
    key = f"{PROJECT}|a.md|0"
    seed(store, staged(key, "alpha"))
    run(store)
    assert len(store.cols[ei.MAIN]) == 1
    seed(store, staged(key, "", op="delete"))
    out = run(store)
    assert out["deleted"] == 1
    assert store.cols[ei.MAIN] == {}


def test_daytime_bulk_embed_is_refused_unless_allowed():
    store = FakeStore()
    seed(store, *[staged(f"{PROJECT}|f{i}.md|0", f"t{i}") for i in range(ei.BATCH + 1)])
    with pytest.raises(ei.Refused, match="daytime"):
        run(store, now=DAY)
    assert store.cols[ei.MAIN] == {}
    out = run(store, now=DAY, allow_daytime=True)
    assert out["written"] == ei.BATCH + 1


def test_night_bulk_embed_is_allowed_and_batched_to_64():
    store = FakeStore()
    seed(store, *[staged(f"{PROJECT}|f{i}.md|0", f"t{i}") for i in range(ei.BATCH + 1)])
    emb = FakeEmbedder()
    run(store, emb=emb, now=NIGHT)
    assert all(n <= ei.BATCH for _, n in emb.calls)
    assert sum(n for _, n in emb.calls) == ei.BATCH + 1


def test_embed_failure_is_retried_with_backoff_then_writes_succeed():
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    out = run(store, emb=FakeEmbedder(fail_times=2))
    assert out["written"] == 1


def test_embed_failure_past_retries_writes_nothing():
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    with pytest.raises(RuntimeError):
        run(store, emb=FakeEmbedder(fail_times=ei.RETRIES + 1))
    assert store.cols[ei.MAIN] == {} and len(store.cols[STAGING]) == 1


def test_dry_run_reports_without_embedding_or_writing():
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "alpha"))
    emb = FakeEmbedder()
    out = run(store, emb=emb, apply=False)
    assert emb.calls == [] and store.cols[ei.MAIN] == {} and len(store.cols[STAGING]) == 1
    assert out["pending"] == 1


def test_max_points_bounds_one_run():
    store = FakeStore()
    seed(store, *[staged(f"{PROJECT}|f{i}.md|0", f"t{i}") for i in range(5)])
    out = run(store, max_points=2)
    assert out["written"] == 2 and len(store.cols[STAGING]) == 3


def test_audit_row_per_write_has_no_text_or_token(tmp_path):
    store = FakeStore()
    seed(store, staged(f"{PROJECT}|a.md|0", "secret-looking-body"))
    rows = []
    ei.drain(PROJECT, store=store, token="tok-VALUE", embedder=FakeEmbedder(), digest=DIGEST, staging=STAGING,
             patterns=PATTERNS, now=DAY, apply=True, allow_daytime=False, killed=set(), max_points=50_000,
             audit=rows.append, sleep=lambda s: None)
    assert rows and rows[0]["project"] == PROJECT and rows[0]["written"] == 1
    blob = json.dumps(rows)
    assert "secret-looking-body" not in blob and "tok-VALUE" not in blob


def test_killed_projects_reads_switch_file(tmp_path):
    f = tmp_path / ".context/estate/kill-switch.yaml"
    f.parent.mkdir(parents=True)
    f.write_text("switched_off:\n  - aef\n")
    assert ei.killed_projects(tmp_path) == {"aef"}
    assert ei.killed_projects(tmp_path / "missing") == set()


class _Http:
    def __init__(self, status, body=None):
        self.status, self.body, self.calls = status, body or {}, []

    def __call__(self, method, url, token, body=None):
        self.calls.append((method, url, token))
        return self.status, self.body


def test_store_maps_401_and_403_to_refused():
    for status in (401, 403):
        store = ei.QdrantStore("https://q.example", http=_Http(status))
        with pytest.raises(ei.Refused, match="auth"):
            store.upsert("tok", ei.MAIN, [])


def test_store_sends_token_in_api_key_header_only_to_its_url():
    http = _Http(200, {"result": {"points": [], "next_page_offset": None}})
    store = ei.QdrantStore("https://q.example/", http=http)
    assert store.scroll("tok", STAGING) == []
    method, url, token = http.calls[0]
    assert method == "POST" and url == f"https://q.example/collections/{STAGING}/points/scroll" and token == "tok"


def test_ollama_digest_matches_tagged_name_and_reports_absence():
    http = _Http(200, {"models": [{"name": f"{ei.MODEL}:latest", "digest": DIGEST},
                                  {"name": "other:latest", "digest": "sha256:x"}]})
    assert ei.Ollama("http://gpu:11434", http=http).digest(ei.MODEL) == DIGEST
    assert ei.Ollama("http://gpu:11434", http=_Http(200, {"models": []})).digest(ei.MODEL) is None


def test_is_daytime_bounds():
    assert ei.is_daytime(dt.datetime(2026, 10, 13, ei.DAY_START, 0))
    assert not ei.is_daytime(dt.datetime(2026, 10, 13, ei.DAY_END, 0))
    assert not ei.is_daytime(NIGHT)


def test_ingest_token_reads_its_own_infisical_name(tmp_path, monkeypatch):
    import yaml
    monkeypatch.delenv("FW_QDRANT_ESTATE_INGEST_AEF_API_KEY", raising=False)
    sys.path.insert(0, str(ROOT))
    import web.secrets_store as ss
    monkeypatch.setattr(ss, "get_api_key", lambda name: None)
    f = tmp_path / "creds.yaml"
    f.write_text(yaml.safe_dump({"credentials": {"infisical_ua": {
        "client_id": "c", "client_secret": "s", "url": "https://i", "project_id": "p"}}}))
    monkeypatch.setenv("FW_ESTATE_CREDS_FILE", str(f))
    seen = []

    def http(method, url, body=None, headers=None):
        seen.append(url)
        return {"accessToken": "a"} if "login" in url else {"secret": {"secretValue": "ingest-tok"}}
    monkeypatch.setattr(ei.ep, "_http_json", http)
    assert ei._token() == "ingest-tok"
    assert "/secrets/raw/QDRANT_ESTATE_TOKEN_INGEST_AEF?" in seen[1]
