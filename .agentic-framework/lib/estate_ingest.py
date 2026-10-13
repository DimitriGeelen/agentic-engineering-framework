#!/usr/bin/env python3
"""fw estate ingest (T-4163, T-4091 slice 2): the central ingest worker.

Drains a project's payload-only staging collection, embeds each text with the ONE
pinned model on the shared embedding host, writes the main collection with model
and digest on every point, and deletes the drained staging points. Refuses, and
writes nothing, when the target is not registered in `_manifest` (R-26), when the
project is switched off (R-28), when the entry is retired or not 768-dimensional, when
the model digest differs from the one ring20 recorded in the entry (R-19), when the store refuses the token (R-25), or on a daytime bulk embed (R-21).
Every write leaves an audit row (R-29) that carries counts only, never text or tokens.
Design: docs/reports/T-4091-estate-push-pipe.md §4; slice 1 is lib/estate_push.py.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import estate_push as ep  # noqa: E402  (patterns, secret scan, tenant, namespace)

MODEL = "nomic-embed-text-v2-moe"
DIMS = 768
MAIN = "estate__knowledge__nomic-embed-text-v2-moe-768"  # alias: estate_knowledge
MANIFEST = "_manifest"
MANIFEST_KEY = "collection"  # payload field that names the collection an entry registers
# ring20 owns `_manifest`: the ingest token is `_manifest:r` only (RBAC is per collection, and
# write would expose every project's entry), so the worker reads its entry and never writes it.
WRITABLE_STATES = ("candidate", "active")  # anything else (retired, unknown, missing) is refused
INGEST_TOKEN = "qdrant_estate_ingest_aef"
BATCH = 64  # R-21: batches of at most ~64 texts
RETRIES = 4  # total embed attempts per batch, with exponential backoff
DAY_START, DAY_END = 8, 20  # local hours during which bulk re-embedding is refused (R-21)
KILL_FILE = ".context/estate/kill-switch.yaml"  # `switched_off: [project, ...]`; operator-owned
# Not `off:` — YAML 1.1 reads a bare `off` as boolean False, which silently switches nothing off.
AUDIT_LOG = ".context/working/estate-ingest-audit.jsonl"


class Refused(Exception):
    """A guard refused the run. Nothing was written past the refusal point."""


def _request(method, url, token, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["api-key"] = token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:  # noqa: S310
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, {}


class QdrantStore:
    """The few estate-store calls the worker makes. Every call carries the caller's token."""

    def __init__(self, base_url: str, http=_request):
        self.base = base_url.rstrip("/")
        self.http = http

    def _call(self, method, path, token, body=None):
        status, data = self.http(method, f"{self.base}{path}", token, body)
        if status in (401, 403):
            raise Refused(f"estate store refused the token (auth HTTP {status}) for {path}")
        if status != 200:
            raise RuntimeError(f"estate store HTTP {status} for {path}")
        return data

    def get_manifest(self, token, collection):
        data = self._call("POST", f"/collections/{MANIFEST}/points/scroll", token, {
            "limit": 1, "with_payload": True,
            "filter": {"must": [{"key": MANIFEST_KEY, "match": {"value": collection}}]}})
        pts = data.get("result", {}).get("points", [])
        return {"id": str(pts[0]["id"]), "payload": pts[0].get("payload", {})} if pts else None

    def scroll(self, token, collection, limit=256):
        out, offset = [], None
        while len(out) < limit:
            data = self._call("POST", f"/collections/{collection}/points/scroll", token, {
                "limit": min(256, limit - len(out)), "with_payload": True, "with_vector": False,
                "offset": offset})
            result = data.get("result", {})
            out += [{"id": str(p["id"]), "payload": p.get("payload", {})} for p in result.get("points", [])]
            offset = result.get("next_page_offset")
            if not offset:
                break
        return out

    def upsert(self, token, collection, points):
        self._call("PUT", f"/collections/{collection}/points?wait=true", token, {"points": points})

    def delete(self, token, collection, ids):
        self._call("POST", f"/collections/{collection}/points/delete?wait=true", token, {"points": ids})


class Ollama:
    """The shared embedding host. Only the pinned model is ever requested."""

    def __init__(self, host: str, http=_request):
        self.host = host.rstrip("/")
        self.http = http

    def digest(self, model):
        status, body = self.http("GET", f"{self.host}/api/tags", None)
        if status != 200:
            raise RuntimeError(f"embedding host HTTP {status} on /api/tags")
        for m in body.get("models", []):
            if m.get("name") in (model, f"{model}:latest"):
                return m.get("digest")
        return None

    def embed(self, model, inputs):
        status, body = self.http("POST", f"{self.host}/api/embed", None, {"model": model, "input": inputs})
        if status != 200:
            raise RuntimeError(f"embedding host HTTP {status} on /api/embed")
        return body["embeddings"]


def is_daytime(now: dt.datetime) -> bool:
    return DAY_START <= now.hour < DAY_END


def killed_projects(root: Path) -> set:
    path = root / KILL_FILE
    if not path.is_file():
        return set()
    import yaml
    data = yaml.safe_load(path.read_text()) or {}
    return {str(p) for p in (data.get("switched_off") or [])}


def _bare(digest) -> str:
    # Ollama's /api/tags gives the bare hex; tolerate a `sha256:` prefix on either side.
    d = str(digest or "").strip().lower()
    return d[len("sha256:"):] if d.startswith("sha256:") else d


def check_manifest(entry, digest, apply) -> None:
    """Refuse unless ring20's `_manifest` entry for MAIN admits a write by this worker's model."""
    if not entry:
        raise Refused(f"collection {MAIN} is not registered in {MANIFEST} (R-26); nothing written")
    p = entry.get("payload") or {}
    state = p.get("state")
    if state not in WRITABLE_STATES:
        raise Refused(f"{MANIFEST} entry for {MAIN} is in state {state!r}, not one of "
                      f"{'/'.join(WRITABLE_STATES)}; nothing written")
    try:
        dims = int(p.get("dims"))
    except (TypeError, ValueError):
        dims = None
    if dims != DIMS:
        raise Refused(f"{MANIFEST} entry for {MAIN} has dims {p.get('dims')!r}, not {DIMS}; nothing written")
    pinned = _bare(p.get("model_digest"))
    if not pinned:
        return
    if not digest:
        if apply:  # fail closed: an apply must know the digest it embeds with
            raise Refused(f"no digest for {MODEL} on the embedding host to compare with the pinned "
                          f"{pinned} (R-19); nothing written")
        return  # a dry run has no digest to compare
    if _bare(digest) != pinned:
        raise Refused(f"model digest {_bare(digest)} differs from the collection's pinned digest {pinned} "
                      "(R-19); nothing written")


def _embed(embedder, texts, sleep):
    last = None
    for attempt in range(RETRIES):
        try:
            vecs = embedder.embed(MODEL, texts)
        except Exception as e:  # noqa: BLE001 - any embed failure is retried, then surfaced
            last = e
            sleep(min(2 ** attempt, 30))
            continue
        if len(vecs) != len(texts) or any(len(v) != DIMS for v in vecs):
            raise Refused(f"embedding host returned vectors that are not {len(texts)} x {DIMS}")
        return vecs
    raise RuntimeError(f"embedding failed after {RETRIES} attempts: {last}")


def _main_id(chunk_key: str) -> str:
    # Stable per chunk: an edit overwrites the point, a deletion removes it by the same id.
    return str(uuid.uuid5(ep._NS, f"main|{chunk_key}"))


def _main_point(payload: dict, vector, digest: str) -> dict:
    return {"id": _main_id(payload["chunk_key"]), "vector": vector, "payload": {
        "tenant": ep.TENANT, "project": payload["project"], "model": MODEL, "digest": digest,
        "category": payload.get("category", ""), "item_type": payload.get("item_type", ""),
        "source_path": payload.get("source_path", ""), "task_id": payload.get("task_id", ""),
        "content_hash": payload.get("content_hash", ""), "chunk_index": payload.get("chunk_index", 0),
        "chunk_key": payload["chunk_key"], "observed_on": payload.get("observed_on", ""),
        "framework_version": payload.get("framework_version", ""), "text": payload["text"]}}


def drain(project, *, store, token, embedder, digest, staging, patterns, now, apply, allow_daytime,
          killed, max_points, audit, sleep=time.sleep) -> dict:
    """Drain up to `max_points` staged points for `project`. Dry run unless `apply`."""
    if project in killed:
        raise Refused(f"project '{project}' is switched off (kill switch, R-28); nothing written")
    check_manifest(store.get_manifest(token, MAIN), digest, apply)

    upserts, deletes, refused = [], [], []
    points = store.scroll(token, staging, max_points)
    for pt in points:
        p = pt["payload"]
        key = p.get("chunk_key", "")
        if p.get("project") != project or not key.startswith(project + "|"):
            refused.append((pt, "foreign-project"))
            continue
        if p.get("op") == "delete":
            deletes.append(pt)
            continue
        bad = ep.scan_items([{"payload": {"text": p.get("text", ""), "chunk_key": key}}], patterns)
        if bad:
            refused.append((pt, bad[0]["reason"]))
            continue
        upserts.append(pt)

    summary = {"pending": len(points), "written": 0, "deleted": 0, "refused": len(refused)}
    if not apply:
        return summary
    if is_daytime(now) and len(upserts) > BATCH and not allow_daytime:
        raise Refused(f"daytime bulk embed of {len(upserts)} texts refused (R-21); "
                      "run at night or pass --allow-daytime")

    def row(**counts):
        audit({"ts": dt.datetime.now(dt.timezone.utc).isoformat(), "project": project, "collection": MAIN,
               "written": 0, "deleted": 0, "refused": 0, "model": MODEL, "digest": digest,
               "staging": staging, **counts})

    for i in range(0, len(upserts), BATCH):
        chunk = upserts[i:i + BATCH]
        vectors = _embed(embedder, [pt["payload"]["text"] for pt in chunk], sleep)
        store.upsert(token, MAIN, [_main_point(pt["payload"], v, digest) for pt, v in zip(chunk, vectors)])
        store.delete(token, staging, [pt["id"] for pt in chunk])
        summary["written"] += len(chunk)
        row(written=len(chunk))

    if deletes:
        store.delete(token, MAIN, [_main_id(pt["payload"]["chunk_key"]) for pt in deletes])
        store.delete(token, staging, [pt["id"] for pt in deletes])
        summary["deleted"] = len(deletes)
        row(deleted=len(deletes))

    if refused:
        store.delete(token, staging, [pt["id"] for pt, _ in refused])
        for pt, reason in refused:
            row(refused=1, reason=reason, chunk_key=pt["payload"].get("chunk_key", ""))
    return summary


def _token() -> str:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from web.secrets_store import get_api_key  # lazy: the guards above stay dependency-free
    tok = get_api_key(INGEST_TOKEN)
    if not tok:
        sys.exit(f"estate ingest: no token named '{INGEST_TOKEN}' (env FW_{INGEST_TOKEN.upper()}_API_KEY or the key store)")
    return tok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="fw estate ingest",
                                 description="Embed staged chunks with the pinned model and write the estate main collection.")
    ap.add_argument("--apply", action="store_true", help="embed and write (default: dry run, counts only)")
    ap.add_argument("--project-root", default=os.environ.get("PROJECT_ROOT", os.getcwd()))
    ap.add_argument("--project", help="project name as stored in the staged payload (default: project root name)")
    ap.add_argument("--staging", default=ep.DEFAULT_COLLECTION)
    ap.add_argument("--url", default=os.environ.get("FW_ESTATE_QDRANT_URL", ep.DEFAULT_URL))
    ap.add_argument("--embed-host", default=os.environ.get("FW_EMBED_HOST") or os.environ.get("OLLAMA_HOST")
                    or "http://localhost:11434")
    ap.add_argument("--max-points", type=int, default=ep.DEFAULT_MAX_POINTS)
    ap.add_argument("--allow-daytime", action="store_true", help="permit a bulk embed during daytime hours")
    ap.add_argument("--audit-log", help=f"append-only audit file (default: <root>/{AUDIT_LOG})")
    a = ap.parse_args(argv)
    if a.max_points <= 0:
        sys.exit(f"estate ingest: --max-points must be positive, got {a.max_points}")

    root = Path(a.project_root)
    project = a.project or root.name
    audit_path = Path(a.audit_log) if a.audit_log else root / AUDIT_LOG

    def audit(rec):
        audit_path.parent.mkdir(parents=True, exist_ok=True)
        with audit_path.open("a") as f:
            f.write(json.dumps(rec) + "\n")

    token = _token()
    digest = None
    if a.apply:
        digest = Ollama(a.embed_host).digest(MODEL)
        if not digest:
            sys.exit(f"estate ingest: model {MODEL} is not on the embedding host {a.embed_host}")
    try:
        out = drain(project, store=QdrantStore(a.url), token=token, embedder=Ollama(a.embed_host),
                    digest=digest or "", staging=a.staging,
                    patterns=ep.load_patterns(root / ".secret-scan-patterns"),
                    now=dt.datetime.now().astimezone(), apply=a.apply, allow_daytime=a.allow_daytime,
                    killed=killed_projects(root), max_points=a.max_points, audit=audit)
    except Refused as e:
        print(f"estate ingest: REFUSED — {e}")
        return 2
    mode = "applied" if a.apply else "dry run"
    print(f"estate ingest ({mode}): {out['pending']} staged, {out['written']} written, "
          f"{out['deleted']} deleted, {out['refused']} refused")
    return 0


if __name__ == "__main__":
    sys.exit(main())
