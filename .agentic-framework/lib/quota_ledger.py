#!/usr/bin/env python3
"""Machine-wide quota ledger: ids and counts only (T-5202, T-5190 S3).

Every project's `fw` on this machine appends one row here when a TermLink dispatch completes
(run.sh, right after S2 writes meta.json `tokens`) and one when a review cost row is written
(lib/review_cost.py). Several projects share a subscription; this one file is where their use
can be summed (S5 reads it; S4 adds limit events to the same file).

── WHERE ────────────────────────────────────────────────────────────────────────
FW_QUOTA_LEDGER > $XDG_STATE_HOME/aef/quota-ledger.jsonl > ~/.local/state/aef/quota-ledger.jsonl
It lives outside every project on purpose: it is per machine user, not per repo.

── WHAT A ROW HOLDS ─────────────────────────────────────────────────────────────
  {"event": "dispatch"|"review", "ts", "project": <directory basename only>, "task",
   "dispatch_id" | "review_id", "worker_kind", "subscription", "tokens": {...}}
`tokens` carries only counts the run REPORTED and is omitted when none were (unknown is not
zero, T-3519). Never a prompt, a host name, a path or account data: every string field must
be a short id and pass S1's account-value check, or it is written as "redacted".

── CONCURRENCY AND SIZE ─────────────────────────────────────────────────────────
A writer takes flock(2) on `<ledger>.lock`, rotates the ledger to `<ledger>.1` when it is
above FW_QUOTA_LEDGER_MAX_BYTES (default 50 MB), then writes the whole line with ONE
os.write on an O_APPEND descriptor. The lock spans rotation and write, so no writer ever
appends to a file another has just renamed, and lines from parallel writers never interleave.
The reader skips torn or non-object lines.

── FAILURE ─────────────────────────────────────────────────────────────────────
append() never raises. A failed append prints one warning per process on stderr and returns
False; the dispatch or review it describes is unaffected.

CLI:
  quota_ledger.py path
  quota_ledger.py append-dispatch --meta META_JSON [--worker-kind K]     always exit 0
  quota_ledger.py rows [--since ISO] [--subscription ID]                 JSON lines
"""

from __future__ import annotations

import datetime as _dt
import fcntl
import hashlib
import json
import os
import re
import sys
from pathlib import Path

DEFAULT_MAX_BYTES = 50 * 1024 * 1024
FILE_NAME = "quota-ledger.jsonl"
EVENTS = ("dispatch", "review")
TOKEN_KEYS = ("input", "output", "cache_read", "cache_creation", "total")
_SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$")
_SUB_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")   # S1's ID_RE
REDACTED = "redacted"

_warned = False


# ── path ──────────────────────────────────────────────────────────────────────

def ledger_path() -> Path:
    p = os.environ.get("FW_QUOTA_LEDGER", "").strip()
    if p:
        return Path(p).expanduser()
    xdg = os.environ.get("XDG_STATE_HOME", "").strip()
    base = Path(xdg).expanduser() if xdg else Path.home() / ".local" / "state"
    return base / "aef" / FILE_NAME


def max_bytes() -> int:
    try:
        v = int(os.environ.get("FW_QUOTA_LEDGER_MAX_BYTES", "") or DEFAULT_MAX_BYTES)
        return v if v > 0 else DEFAULT_MAX_BYTES
    except ValueError:
        return DEFAULT_MAX_BYTES


# ── row shaping ───────────────────────────────────────────────────────────────

def _account_values(text: str) -> list[str]:
    try:
        here = str(Path(__file__).resolve().parent)
        if here not in sys.path:
            sys.path.insert(0, here)
        import subscriptions  # noqa: E402  (sibling module, S1)
        return subscriptions.account_values(text)
    except Exception:  # noqa: BLE001 - an old vendored copy without S1: the id regex still holds
        return []


def _id(v) -> str | None:
    if v is None or v == "":
        return None
    s = str(v)
    if not _SAFE.match(s) or _account_values(s):
        return REDACTED
    return s


def _now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def make_row(*, event: str, project: str | os.PathLike | None, task=None, dispatch_id=None,
             review_id=None, worker_kind=None, subscription=None, tokens=None,
             ts: str | None = None) -> dict:
    """A ledger row from raw values: ids only, `project` reduced to its basename."""
    row: dict = {"event": event if event in EVENTS else REDACTED, "ts": ts or _now()}
    proj = os.path.basename(os.path.normpath(str(project))) if project else None
    for key, val in (("project", proj), ("task", task), ("dispatch_id", dispatch_id),
                     ("review_id", review_id), ("worker_kind", worker_kind)):
        v = _id(val)
        if v is not None:
            row[key] = v
    sub = str(subscription) if subscription else "unknown"
    row["subscription"] = sub if _SUB_RE.match(sub) else "unknown"
    if isinstance(tokens, dict):
        counts = {k: int(tokens[k]) for k in TOKEN_KEYS
                  if isinstance(tokens.get(k), (int, float)) and not isinstance(tokens.get(k), bool)
                  and tokens[k] >= 0}
        if counts:
            row["tokens"] = counts
    return row


# ── write ─────────────────────────────────────────────────────────────────────

def _warn(msg: str) -> None:
    global _warned
    if not _warned:
        _warned = True
        print(f"WARNING: quota ledger not written ({msg}) — the run itself is unaffected",
              file=sys.stderr)


def append(row: dict, path: Path | None = None) -> bool:
    """Append one row. Atomic and cross-process safe; never raises."""
    try:
        p = Path(path) if path else ledger_path()
        data = (json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
        p.parent.mkdir(parents=True, exist_ok=True)
        lock_fd = os.open(str(p) + ".lock", os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX)
            try:
                if p.stat().st_size >= max_bytes():
                    os.replace(p, str(p) + ".1")
            except FileNotFoundError:
                pass
            fd = os.open(str(p), os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
            try:
                n = os.write(fd, data)
                if n != len(data):
                    raise OSError(f"short write {n}/{len(data)}")
            finally:
                os.close(fd)
        finally:
            os.close(lock_fd)   # releases the flock
        return True
    except Exception as e:  # noqa: BLE001 - never fail the dispatch or review
        _warn(f"{type(e).__name__}: {str(e).splitlines()[0] if str(e) else ''}".rstrip(": "))
        return False


def append_dispatch(meta_path, worker_kind: str | None = None) -> bool:
    """The completion row for a dispatch, from its meta.json (S2 wrote subscription + tokens)."""
    try:
        meta = json.loads(Path(meta_path).read_text(encoding="utf-8"))
        if not isinstance(meta, dict):
            raise ValueError("meta.json is not an object")
    except Exception as e:  # noqa: BLE001
        _warn(f"meta.json unreadable: {type(e).__name__}")
        return False
    row = make_row(event="dispatch", project=meta.get("project"), task=meta.get("task"),
                   dispatch_id=meta.get("name"),
                   worker_kind=worker_kind or meta.get("worker_kind") or "claude",
                   subscription=meta.get("subscription"), tokens=meta.get("tokens"))
    return append(row)


def review_id_for(rec: dict) -> str:
    """A stable id for a review cost row (the row has none of its own)."""
    h = hashlib.sha256(json.dumps(rec, sort_keys=True).encode("utf-8")).hexdigest()[:12]
    return f"RC-{h}"


# ── read ──────────────────────────────────────────────────────────────────────

def _parse_ts(v) -> _dt.datetime | None:
    if isinstance(v, _dt.datetime):
        return v if v.tzinfo else v.replace(tzinfo=_dt.timezone.utc)
    try:
        d = _dt.datetime.fromisoformat(str(v).replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=_dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def rows(since=None, subscription: str | None = None, path: Path | None = None) -> list[dict]:
    """Rows from the rotated file then the live one, oldest first; torn lines skipped."""
    p = Path(path) if path else ledger_path()
    cutoff = _parse_ts(since) if since is not None else None
    out: list[dict] = []
    for f in (Path(str(p) + ".1"), p):
        try:
            raw = f.read_bytes()
        except OSError:
            continue
        for line in raw.split(b"\n"):
            if not line.strip():
                continue
            try:
                obj = json.loads(line.decode("utf-8"))
            except (UnicodeDecodeError, ValueError):
                continue
            if not isinstance(obj, dict):
                continue
            if subscription is not None and obj.get("subscription") != subscription:
                continue
            if cutoff is not None:
                t = _parse_ts(obj.get("ts"))
                if t is None or t < cutoff:
                    continue
            out.append(obj)
    return out


def main(argv: list[str] | None = None) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="quota_ledger.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("path")
    ad = sub.add_parser("append-dispatch")
    ad.add_argument("--meta", required=True)
    ad.add_argument("--worker-kind")
    rr = sub.add_parser("rows")
    rr.add_argument("--since")
    rr.add_argument("--subscription")
    args = ap.parse_args(argv)
    if args.cmd == "path":
        print(ledger_path())
        return 0
    if args.cmd == "append-dispatch":
        append_dispatch(args.meta, args.worker_kind)
        return 0
    for r in rows(args.since, args.subscription):
        print(json.dumps(r, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
