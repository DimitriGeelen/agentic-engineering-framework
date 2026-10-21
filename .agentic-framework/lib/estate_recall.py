#!/usr/bin/env python3
"""Estate read side (T-4164, T-4091 slice 3): what `fw recall` / `fw ask --scope` ask the estate.

Embeds the query with the ONE pinned model ingest writes with (estate_ingest.MODEL), searches the
estate main collection, and returns hits that carry their provenance (R-12, R-33): project, task id
or path, item type, dates, evidence, status, model id, score, framework version. A field the stored
payload does not have is shown as `unrecorded`, never left blank and never guessed.

Scope (R-13): `own` is the local index only (this module is not called); `estate` is the whole estate
store, own items included and labelled; `both` is the local index plus the estate's OTHER projects
(own items are already answered, fresher, by the local index). Every other-project hit is labelled
`[cross-project: <project>]`.

Ranking (R-14): `default` keeps own hits first while a cross-project hit beats them by no more than a
margin, unless that hit is newer and evidence `tested`; `solution-finder` puts other projects first.
Superseded and retired items are left out unless asked for.

Unavailable (R-16): no read token, a store that refuses or cannot be reached, or a down embedder
raises EstateUnavailable; the callers answer from the local index and say `estate unavailable`.
Design: docs/reports/T-4091-estate-push-pipe.md §1 item 7; requirements T-4123 R-12..R-16, R-33..R-36.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import estate_ingest as ei  # noqa: E402  (MODEL, DIMS, MAIN: the read side must match ingest exactly)
import estate_push as ep  # noqa: E402  (token resolution, default store URL)

READ_TOKEN = "qdrant_estate_read_aef"
INFISICAL_READ_TOKEN = "QDRANT_ESTATE_TOKEN_READ_AEF"
SCOPES = ("own", "estate", "both")
MODES = ("default", "solution-finder")
DEFAULT_MARGIN = 0.05
UNRECORDED = "unrecorded"
HIDDEN_STATUSES = ("superseded", "retired")
PEER_REPORT_TYPES = ("peer-report", "peer_report", "peer report")
TIMEOUT = float(os.environ.get("FW_ESTATE_READ_TIMEOUT", "5"))  # a recall must not hang on the store


class EstateUnavailable(Exception):
    """The estate could not answer. The message is the reason shown after `estate unavailable:`."""


def _request(method, url, token, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["api-key"] = token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:  # noqa: S310
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, {}


def read_token() -> str:
    """The estate read token, or EstateUnavailable. resolve_token exits on a miss; a recall must not."""
    try:
        return ep.resolve_token(READ_TOKEN, INFISICAL_READ_TOKEN, "read")
    except SystemExit as e:
        raise EstateUnavailable(str(e.code) if e.code else "no estate read token") from None
    except Exception as e:  # noqa: BLE001 - a broken key store is an unavailable estate, not a crash
        raise EstateUnavailable(f"no estate read token ({type(e).__name__})") from None


def _field(payload: dict, *names) -> str:
    for n in names:
        v = payload.get(n)
        if v not in (None, ""):
            return str(v)
    return UNRECORDED


def normalise(point: dict, own: str) -> dict:
    """One search hit as a provenance record. Every field is present and non-empty (R-12, R-33)."""
    p = point.get("payload") or {}
    project = _field(p, "project")
    item_type = _field(p, "item_type", "category")
    evidence = _field(p, "evidence", "evidence_type")
    if item_type.lower() in PEER_REPORT_TYPES or evidence.lower() in PEER_REPORT_TYPES:
        evidence = "peer report"  # R-36: a peer's report is never shown as tested
    recorded = _field(p, "observed_on", "recorded_on")
    return {
        "project": project,
        "cross_project": project != own,
        "ref": _field(p, "task_id", "source_path"),
        "path": _field(p, "source_path"),
        "item_type": item_type,
        "recorded": recorded,
        "confirmed": _field(p, "last_confirmed", "confirmed_on"),
        "evidence": evidence,
        "status": _field(p, "status"),
        "model": _field(p, "model"),
        "version": _field(p, "framework_version", "artefact_version"),
        "guarded_by": _field(p, "guarded_by"),
        "score": float(point.get("score") or 0.0),
        "text": p.get("text") or "",
    }


def _beats_own(cross: dict, own: dict, margin: float) -> bool:
    """Default mode: may this cross-project hit stand above this own hit?"""
    if cross["score"] - own["score"] > margin:
        return True
    newer = cross["recorded"] != UNRECORDED and (own["recorded"] == UNRECORDED
                                                 or cross["recorded"] > own["recorded"])
    return newer and cross["evidence"] == "tested" and cross["score"] >= own["score"]


def rank(hits: list, mode: str = "default", margin: float = DEFAULT_MARGIN,
         include_superseded: bool = False) -> list:
    """Order hits per R-14. Ties and equal kinds keep score order."""
    if mode not in MODES:
        raise ValueError(f"unknown ranking mode {mode!r} (one of {', '.join(MODES)})")
    kept = [h for h in hits if include_superseded or h["status"].lower() not in HIDDEN_STATUSES]
    kept.sort(key=lambda h: h["score"], reverse=True)
    if mode == "solution-finder":
        return [h for h in kept if h["cross_project"]] + [h for h in kept if not h["cross_project"]]
    # Default: an own hit moves up past a cross-project hit that does not beat it. Bubble passes are
    # fine at recall sizes (tens of hits) and keep the result a stable, explainable order.
    out = list(kept)
    swapped = True
    while swapped:
        swapped = False
        for i in range(len(out) - 1):
            a, b = out[i], out[i + 1]
            if a["cross_project"] and not b["cross_project"] and not _beats_own(a, b, margin):
                out[i], out[i + 1] = b, a
                swapped = True
    return out


def search(query: str, *, own: str, scope: str, limit: int = 5, store_url: str | None = None,
           embed_host: str | None = None, token: str | None = None, http=_request) -> list:
    """Raw provenance hits from the estate for `scope` (estate | both). Raises EstateUnavailable."""
    if scope not in ("estate", "both"):
        raise ValueError(f"search() serves scope estate|both, not {scope!r}")
    store_url = (store_url or os.environ.get("FW_ESTATE_QDRANT_URL") or ep.DEFAULT_URL).rstrip("/")
    embed_host = (embed_host or os.environ.get("FW_EMBED_HOST") or os.environ.get("OLLAMA_HOST")
                  or "http://localhost:11434").rstrip("/")
    token = token if token is not None else read_token()
    try:
        status, body = http("POST", f"{embed_host}/api/embed", None, {"model": ei.MODEL, "input": [query]})
    except Exception as e:  # noqa: BLE001
        raise EstateUnavailable(f"embedder unreachable ({type(e).__name__})") from None
    vecs = body.get("embeddings") if status == 200 else None
    if not vecs or len(vecs[0]) != ei.DIMS:
        raise EstateUnavailable(f"embedder gave no {ei.DIMS}-d vector for {ei.MODEL} (HTTP {status})")
    req = {"vector": vecs[0], "limit": limit * 4, "with_payload": True,
           "filter": {"must": [{"key": "tenant", "match": {"value": ep.TENANT}}]}}
    if scope == "both":
        req["filter"]["must_not"] = [{"key": "project", "match": {"value": own}}]
    try:
        status, body = http("POST", f"{store_url}/collections/{ei.MAIN}/points/search", token, req)
    except Exception as e:  # noqa: BLE001
        raise EstateUnavailable(f"estate store unreachable ({type(e).__name__})") from None
    if status in (401, 403):
        raise EstateUnavailable(f"estate store refused the read token (HTTP {status})")
    if status != 200:
        raise EstateUnavailable(f"estate store HTTP {status}")
    return [normalise(pt, own) for pt in body.get("result") or []]


def recall(query: str, *, own: str, scope: str, mode: str = "default", margin: float = DEFAULT_MARGIN,
           include_superseded: bool = False, limit: int = 5, **kw) -> list:
    """Ranked, filtered provenance hits, at most `limit`. Raises EstateUnavailable."""
    hits = search(query, own=own, scope=scope, limit=limit, **kw)
    return rank(hits, mode=mode, margin=margin, include_superseded=include_superseded)[:limit]


def label(hit: dict) -> str:
    return f"[cross-project: {hit['project']}]" if hit["cross_project"] else f"[own: {hit['project']}]"


def provenance(hit: dict) -> str:
    """The R-12/R-33/R-34 line: everything a reader needs to decide whether to trust the hit."""
    since = (f"confirmed {hit['confirmed']}" if hit["confirmed"] != UNRECORDED
             else f"true at {hit['version']}, not re-observed since {hit['recorded']}")
    return (f"type {hit['item_type']} · recorded {hit['recorded']} · {since} · evidence {hit['evidence']}"
            f" · status {hit['status']} · check {hit['guarded_by']} · model {hit['model']}"
            f" · score {hit['score']:.3f}")


def format_hit(hit: dict, prefix: str = "  ") -> list:
    text = " ".join(hit["text"].split())
    if len(text) > 100:
        text = text[:97] + "..."
    return [f"{prefix}{label(hit)} {hit['ref']}: {text}", f"{prefix}    {provenance(hit)}"]


def as_chunk(hit: dict) -> dict:
    """An estate hit in the shape web.ask.format_rag_context and lib/ask.py sources expect."""
    return {
        "title": f"{label(hit)} {hit['ref']}",
        "category": hit["item_type"],
        "path": hit["path"],
        "score": hit["score"],
        "project": hit["project"],
        "cross_project": hit["cross_project"],
        "provenance": provenance(hit),
        "chunk_text": f"Provenance: {provenance(hit)}\n\n{hit['text']}",
    }


def own_project(project_root) -> str:
    """The project name estate payloads carry for this project (push and ingest use the root's name)."""
    return os.environ.get("FW_ESTATE_PROJECT") or Path(project_root).resolve().name
