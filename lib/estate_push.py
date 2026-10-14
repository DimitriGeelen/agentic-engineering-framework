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
STAGING_BUDGET = 100_000  # ring20 staging collection cap, in points (T-4162 operator ruling 2026-10-13)
DEFAULT_MAX_POINTS = 50_000  # per --apply run; the first fill is ~295k chunks, so it goes in batches
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


def _count(url: str, token: str, collection: str) -> int:
    req = urllib.request.Request(f"{url.rstrip('/')}/collections/{collection}/points/count",
                                 data=json.dumps({"exact": True}).encode(), method="POST",
                                 headers={"Content-Type": "application/json", "api-key": token})
    with urllib.request.urlopen(req, timeout=60) as r:  # noqa: S310
        return int(json.loads(r.read())["result"]["count"])


def staged_count(base_url: str, token: str, collection: str, get=None) -> int:
    """Points currently in staging. Raises when the store cannot say: unknown is never zero."""
    n = (get or _count)(base_url, token, collection)
    if not isinstance(n, int) or n < 0:
        raise ValueError(f"store returned an unusable staged count: {n!r}")
    return n


def select_batch(plan: Plan, limit: int) -> tuple[Plan, int]:
    """First `limit` operations in plan order (upserts, then tombstones). Returns (batch, remaining)."""
    ops = plan.upserts + plan.deletes
    take = ops[:max(limit, 0)]
    batch = Plan(upserts=[o for o in take if o["payload"]["op"] == "upsert"],
                 deletes=[o for o in take if o["payload"]["op"] == "delete"],
                 refused=plan.refused, skipped=plan.skipped)
    return batch, len(ops) - len(take)


def _apply_ledger(ledger: dict, plan: Plan) -> dict:
    for u in plan.upserts:
        ledger[u["payload"]["chunk_key"]] = u["payload"]["content_hash"]
    for d in plan.deletes:
        ledger.pop(d["payload"]["chunk_key"], None)
    return ledger


INFISICAL_TOKEN_NAME = "QDRANT_ESTATE_TOKEN_STAGING_AEF"
INFISICAL_ENV = os.environ.get("FW_ESTATE_INFISICAL_ENV", "prod")
CREDS_FILE_DEFAULT = "~/.claude-creds.yaml"  # host credential file; holds Universal Auth client settings
_INFISICAL_MISS: list[str] = []  # why the last lookup missed (status / reason only, never a value)


def _http_json(method: str, url: str, body: dict | None = None, headers: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json", **(headers or {})})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode() or "{}")


def _ua_settings() -> dict | None:
    """Universal Auth client settings from the host credential file (FW_ESTATE_CREDS_FILE)."""
    import yaml
    path = Path(os.path.expanduser(os.environ.get("FW_ESTATE_CREDS_FILE", CREDS_FILE_DEFAULT)))
    if not path.is_file():
        _INFISICAL_MISS.append(f"credential file not found: {path}")
        return None
    try:
        ua = ((yaml.safe_load(path.read_text()) or {}).get("credentials") or {}).get("infisical_ua") or {}
    except (OSError, yaml.YAMLError) as e:
        _INFISICAL_MISS.append(f"credential file unreadable: {type(e).__name__}")
        return None
    missing = [k for k in ("client_id", "client_secret", "url", "project_id") if not ua.get(k)]
    if missing:
        _INFISICAL_MISS.append(f"credential file lacks infisical_ua.{'/'.join(missing)}")
        return None
    return ua


def _infisical_secret(name: str) -> str | None:
    """Read one secret by name from Infisical at run time (operator 2026-10-13, option 1).

    Universal Auth login with the host's client settings, then one raw-secret read.
    The value stays in memory: never printed, logged or written. Errors carry the
    HTTP status and Infisical's message only.
    """
    import urllib.error
    import urllib.parse
    _INFISICAL_MISS.clear()
    ua = _ua_settings()
    if ua is None:
        return None
    base = str(ua["url"]).rstrip("/")
    step = "login"
    try:
        login = _http_json("POST", f"{base}/api/v1/auth/universal-auth/login",
                           {"clientId": ua["client_id"], "clientSecret": ua["client_secret"]})
        access = login.get("accessToken")
        if not access:
            _INFISICAL_MISS.append("login returned no access token")
            return None
        step = "read"
        # The estate tokens may live in another project/folder than the identity's default.
        q = urllib.parse.urlencode({
            "workspaceId": os.environ.get("FW_ESTATE_INFISICAL_PROJECT_ID") or ua["project_id"],
            "environment": INFISICAL_ENV,
            "secretPath": os.environ.get("FW_ESTATE_INFISICAL_PATH") or ua.get("secret_path") or "/"})
        got = _http_json("GET", f"{base}/api/v3/secrets/raw/{urllib.parse.quote(name)}?{q}",
                         headers={"Authorization": f"Bearer {access}"})
    except urllib.error.HTTPError as e:
        try:
            msg = str(json.loads(e.read().decode() or "{}").get("message", ""))[:200]
        except Exception:
            msg = ""
        _INFISICAL_MISS.append(f"{step} HTTP {e.code}{': ' + msg if msg else ''}")
        return None
    except (OSError, ValueError) as e:
        _INFISICAL_MISS.append(f"{step} failed: {type(e).__name__}")
        return None
    value = ((got.get("secret") or {}).get("secretValue") or "").strip()
    if not value:
        _INFISICAL_MISS.append("secret has an empty value")
    return value or None


def resolve_token(local_name: str, infisical_name: str, verb: str) -> str:
    """Env / key store first (explicit operator override), then Infisical by name."""
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from web.secrets_store import get_api_key  # lazy: keeps the planner dependency-free
    tok = get_api_key(local_name) or _infisical_secret(infisical_name)
    if not tok:
        sys.exit(f"estate {verb}: no token: not in env FW_{local_name.upper()}_API_KEY, the key store, "
                 f"or Infisical ({INFISICAL_ENV}) as '{infisical_name}'"
                 + (f" — Infisical: {_INFISICAL_MISS[0]}" if _INFISICAL_MISS else ""))
    return tok


def _token() -> str:
    return resolve_token(TOKEN_NAME, INFISICAL_TOKEN_NAME, "push")


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
    ap.add_argument("--max-points", type=int, default=None,
                    help=f"most points one run stages, upserts and tombstones alike (default: "
                         f"$FW_ESTATE_PUSH_MAX_POINTS or {DEFAULT_MAX_POINTS})")
    a = ap.parse_args(argv)
    max_points = a.max_points
    if max_points is None:
        max_points = int(os.environ.get("FW_ESTATE_PUSH_MAX_POINTS") or DEFAULT_MAX_POINTS)
    if max_points <= 0:
        sys.exit(f"estate push: --max-points must be positive, got {max_points}")
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
    # Batching (T-4162): the store's staged count bounds how much headroom is left in the budget.
    # The count is read with the staging token; a dry run that cannot read it says so and stages nothing.
    staged, reason, tok = None, "", None
    try:
        tok = _token()
        staged = staged_count(a.url, tok, a.collection)
    except SystemExit as e:
        if a.apply:
            raise
        reason = str(e)
    except Exception as e:  # noqa: BLE001 — reported, then nothing is staged
        reason = f"could not read {a.collection}: {e}"
    if staged is None:
        headroom = 0
    else:
        headroom = max(STAGING_BUDGET - staged, 0)
    batch, remaining = select_batch(plan, min(max_points, headroom))
    runs_left = -(-remaining // max_points)
    total = len(plan.upserts) + len(plan.deletes)
    if staged is None:
        print(f"estate push: staged count unreadable ({reason}); this run would stage nothing")
    else:
        print(f"estate push: {total} to stage in total; this run stages {len(batch.upserts) + len(batch.deletes)} "
              f"(cap {max_points}, staging {staged} of {STAGING_BUDGET}); {runs_left} run(s) remain after this one")
    if not a.apply:
        return 0
    if staged is None:
        print("estate push: staging nothing — the staged count must be readable before any write")
        return 1
    if not batch.upserts and not batch.deletes:
        print("estate push: nothing to stage" if not total else
              f"estate push: staging budget full — wait for the ingest worker to drain {a.collection}")
        return 0
    n = stage(batch, a.url, tok, a.collection)
    state.write_text(json.dumps(_apply_ledger(ledger, batch), indent=0, sort_keys=True))
    print(f"estate push: staged {n} points in {a.collection}; {remaining} left for later runs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
