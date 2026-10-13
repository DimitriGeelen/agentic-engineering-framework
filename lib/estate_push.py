#!/usr/bin/env python3
"""fw estate push (T-4162, T-4091 slice 1): stage new/changed/deleted index chunks.

Reads the project's local vector index (documents + file_state), keeps only the
opted-in categories, redacts secrets and hosts at write time, diffs against the
push ledger and stages text + payload (never vectors) in the project's
payload-only staging collection. A central ingest worker embeds from there.
Design: docs/reports/T-4091-estate-push-pipe.md §4.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
import urllib.request
import uuid
from dataclasses import dataclass, field
from pathlib import Path

TENANT = "estate"
DEFAULT_URL = "https://qdrant-estate.docker.ring20.geelenandcompany.com"
DEFAULT_COLLECTION = "staging_aef"
TOKEN_NAME = "qdrant_estate_staging_aef"
BATCH = 64
MAX_CHUNK_CHARS = 8000  # R-37: size gate
TEXT_SUFFIXES = (".md", ".yaml", ".yml", ".json", ".txt")
_NS = uuid.UUID("6f1c2d3e-4a5b-4c6d-8e7f-0a1b2c3d4e5f")

# T-4123 pilot feed list. Active tasks and handovers are deliberately absent.
PILOT_CATEGORIES = {
    "Completed Tasks": "completed-task",
    "Episodic Memory": "episodic",
    "Project Memory": "project-memory",
    "Research Reports": "report",
    "Saved Answers": "saved-answer",
    "Agent Docs": "agent-doc",
    "Specifications": "specification",
    "Component Fabric": "module-card",
}
# Matches that cannot be redacted away: the surrounding block is the secret.
REFUSE_PATTERNS = {"SSH Private Key"}

_POSIX = {"[:space:]": r"\s", "[:alnum:]": "A-Za-z0-9", "[:alpha:]": "A-Za-z", "[:digit:]": "0-9"}
_IPV4 = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


@dataclass
class Plan:
    upserts: list = field(default_factory=list)
    deletes: list = field(default_factory=list)
    refused: list = field(default_factory=list)
    skipped: list = field(default_factory=list)


def load_patterns(path: Path) -> list[tuple[str, str]]:
    out = []
    if not path.is_file():
        return out
    for line in path.read_text().replace("\r", "").splitlines():
        if not line.strip() or line.lstrip().startswith("#") or "\t" not in line:
            continue
        name, rx = line.split("\t", 1)
        for k, v in _POSIX.items():
            rx = rx.replace(k, v)
        try:
            re.compile(rx)
        except re.error:
            continue
        out.append((name.strip(), rx))
    return out


def load_role_map(path: Path) -> dict:
    if not path.is_file():
        return {}
    import yaml
    data = yaml.safe_load(path.read_text()) or {}
    return {str(k): str(v) for k, v in (data.get("roles", data) or {}).items()}


def redact(text: str, patterns, role_map) -> tuple[str, list[str]]:
    """Return (redacted, names of secret patterns that fired)."""
    fired = []
    for name, rx in patterns:
        text, n = re.subn(rx, f"[REDACTED:{name}]", text)
        if n:
            fired.append(name)
    for host in sorted(role_map, key=len, reverse=True):
        text = text.replace(host, f"[role:{role_map[host]}]")
    text = _IPV4.sub("[ip]", text)
    return text, fired


def scan_items(items, patterns) -> list[dict]:
    """Final gate: any staged upsert whose text still matches a secret pattern."""
    bad = []
    for it in items:
        for name, rx in patterns:
            if re.search(rx, it["payload"]["text"]):
                bad.append({"chunk_key": it["payload"]["chunk_key"], "reason": name})
    return bad


def _sha(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()


def _point(key: str, op: str, h: str, payload: dict) -> dict:
    return {"id": str(uuid.uuid5(_NS, f"{key}|{h}|{op}")), "vector": {}, "payload": payload}


def build_plan(db_path, ledger: dict, *, project: str, patterns, role_map: dict,
               framework_version: str, categories=None) -> Plan:
    cats = set(categories) if categories is not None else set(PILOT_CATEGORIES)
    cats &= set(PILOT_CATEGORIES)  # active tasks / handovers can never be opted in
    plan = Plan()
    db = sqlite3.connect(str(db_path))
    seen = set()
    try:
        states = {r[0]: r[1] for r in db.execute("SELECT path, updated_at FROM file_state")}
        rows = db.execute("SELECT path, category, task_id, chunk_index, chunk_text FROM documents"
                          " ORDER BY path, chunk_index").fetchall()
    finally:
        db.close()
    for path, cat, task_id, idx, text in rows:
        if cat not in cats:
            continue
        key = f"{project}|{path}|{idx}"
        if not path.lower().endswith(TEXT_SUFFIXES):
            plan.skipped.append({"chunk_key": key, "reason": "type"})
            continue
        if len(text) > MAX_CHUNK_CHARS:
            plan.skipped.append({"chunk_key": key, "reason": "too-large"})
            continue
        seen.add(key)
        if any(name in REFUSE_PATTERNS and re.search(rx, text) for name, rx in patterns):
            name = next(n for n, rx in patterns if n in REFUSE_PATTERNS and re.search(rx, text))
            plan.refused.append({"chunk_key": key, "reason": name})
            continue
        clean, _ = redact(text, patterns, role_map)
        left = scan_items([{"payload": {"text": clean, "chunk_key": key}}], patterns)
        if left:
            plan.refused.append(left[0])
            continue
        h = _sha(clean)
        if ledger.get(key) == h:
            continue
        observed = dt.datetime.fromtimestamp(states.get(path) or 0, dt.timezone.utc).strftime("%Y-%m-%d")
        plan.upserts.append(_point(key, "upsert", h, {
            "tenant": TENANT, "project": project, "category": cat, "item_type": PILOT_CATEGORIES[cat],
            "source_path": path, "task_id": task_id or "", "content_hash": h, "chunk_index": idx,
            "observed_on": observed, "framework_version": framework_version,
            "chunk_key": key, "op": "upsert", "text": clean}))
    for key, h in sorted(ledger.items()):
        if key not in seen and key.startswith(project + "|"):
            plan.deletes.append(_point(key, "delete", h, {
                "tenant": TENANT, "project": project, "chunk_key": key, "content_hash": h, "op": "delete"}))
    return plan


def _put(url: str, token: str, body: dict) -> int:
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="PUT",
                                 headers={"Content-Type": "application/json", "api-key": token})
    with urllib.request.urlopen(req, timeout=60) as r:  # noqa: S310
        return r.status


def stage(plan: Plan, base_url: str, token: str, collection: str, put=_put) -> int:
    pts = plan.upserts + plan.deletes
    url = f"{base_url.rstrip('/')}/collections/{collection}/points?wait=true"
    for i in range(0, len(pts), BATCH):
        put(url, token, {"points": pts[i:i + BATCH]})
    return len(pts)


def _apply_ledger(ledger: dict, plan: Plan) -> dict:
    for u in plan.upserts:
        ledger[u["payload"]["chunk_key"]] = u["payload"]["content_hash"]
    for d in plan.deletes:
        ledger.pop(d["payload"]["chunk_key"], None)
    return ledger


def _token() -> str:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from web.secrets_store import get_api_key  # lazy: keeps the planner dependency-free
    tok = get_api_key(TOKEN_NAME)
    if not tok:
        sys.exit(f"estate push: no token named '{TOKEN_NAME}' (env FW_{TOKEN_NAME.upper()}_API_KEY or the key store)")
    return tok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="fw estate push",
                                 description="Stage new/changed/deleted index chunks (text + payload) in the estate staging collection.")
    ap.add_argument("--apply", action="store_true", help="write to staging (default: dry run)")
    ap.add_argument("--project-root", default=os.environ.get("PROJECT_ROOT", os.getcwd()))
    ap.add_argument("--db")
    ap.add_argument("--url", default=os.environ.get("FW_ESTATE_QDRANT_URL", DEFAULT_URL))
    ap.add_argument("--collection", default=DEFAULT_COLLECTION)
    ap.add_argument("--categories", default=os.environ.get("FW_ESTATE_PUSH_CATEGORIES", ""),
                    help="comma list, subset of the pilot categories (default: all pilot categories)")
    a = ap.parse_args(argv)
    root = Path(a.project_root)
    db = Path(a.db or os.environ.get("VECTOR_DB_PATH") or root / ".context/working/fw-vec-index.db")
    if not db.is_file():
        sys.exit(f"estate push: no local index at {db} (run fw index reindex)")
    state = root / ".context/working/estate-push-state.json"
    ledger = json.loads(state.read_text()) if state.is_file() else {}
    cats = {c.strip() for c in a.categories.split(",") if c.strip()} or None
    ver = (root / "VERSION").read_text().strip() if (root / "VERSION").is_file() else "unknown"
    plan = build_plan(db, ledger, project=root.name, patterns=load_patterns(root / ".secret-scan-patterns"),
                      role_map=load_role_map(root / ".context/estate/role-map.yaml"),
                      framework_version=ver, categories=cats)
    if plan.refused:
        log = root / ".context/working/estate-push-refused.jsonl"
        with log.open("a") as f:
            for r in plan.refused:
                f.write(json.dumps({**r, "ts": dt.datetime.now(dt.timezone.utc).isoformat()}) + "\n")
    print(f"estate push: {len(plan.upserts)} upsert, {len(plan.deletes)} delete, "
          f"{len(plan.refused)} refused, {len(plan.skipped)} skipped"
          + ("" if a.apply else " (dry run; --apply to stage)"))
    if not a.apply:
        return 0
    n = stage(plan, a.url, _token(), a.collection)
    state.write_text(json.dumps(_apply_ledger(ledger, plan), indent=0, sort_keys=True))
    print(f"estate push: staged {n} points in {a.collection}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
