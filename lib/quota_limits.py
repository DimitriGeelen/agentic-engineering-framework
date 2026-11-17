#!/usr/bin/env python3
"""Limit-message recognisers per harness -> `limit` events in the quota ledger (T-5203, T-5190 S4).

When a harness hits its subscription limit, the message lands only in that worker's stderr.log or
result.jsonl. This module turns the KNOWN wordings into ledger events, so S5 can say "at limit
until". Wordings are from 1409's T-6158 table (docs/reports/T-5190-subscription-quota-overview.md):

  harness  wording (fixture)                                                      kind     reset
  claude   "You've hit your weekly limit · resets 5am (UTC)"                       weekly   parsed (UTC only)
  claude   "You've hit your weekly limit · resets Nov 21, 5am (UTC)"               weekly   parsed (UTC only)
  claude   "You've hit your 5-hour limit · resets 3pm (UTC)" (also "session")      5h       parsed (UTC only)
  glm      "Usage limit reached for 5 hour. Your limit will reset at 2026-11-16 14:12:01"
                                                                                   5h       "unknown" + reset_text
  glm      "Rate limit reached for requests"                                      rate     "unknown"
  glm      "Insufficient balance or no resource package. Please recharge."         balance  "unknown"
  any      "HTTP Error 429: Too Many Requests"                                     rate     "unknown"

── RESET RULES (never guess a zone) ────────────────────────────────────────────
* claude: a reset is parsed ONLY when the text says "(UTC)". Anything else (no zone, another
  zone) gives reset "unknown" plus reset_text, the matched literal.
  - With a date ("Nov 21, 5am (UTC)"): that day and time in UTC. The message carries no year,
    so the year is the message time's; if that lands more than a day before the message time
    the message must mean next year (a "resets Jan 2" seen on Dec 30).
  - Without a date ("5am (UTC)"): the NEXT 05:00 UTC strictly after the message time. The
    message time is the dispatch completion ts (meta.json `ended`), the latest moment the
    message can have been printed. Without a message time, reset is "unknown".
* glm: "will reset at YYYY-MM-DD HH:MM:SS" carries NO zone (1409 read it as UTC+8 by inference,
  not by any provider statement), so reset is "unknown" and reset_text keeps the literal only.
* balance and rate: reset "unknown"; no reset_text.

── WHAT IS STORED ──────────────────────────────────────────────────────────────
  {"event": "limit", "ts", "project", "task", "dispatch_id", "worker_kind", "subscription",
   "kind", "reset_at" | "reset": "unknown", ["reset_text"], "source": "dispatch"}
ids come from meta.json, never from the output. From the output only `kind` and the reset
(parsed time, or the literal matched by a fixed date/time pattern) are kept. At most one
event per kind per dispatch (the last matching message wins: it is the most recent).

── WHAT IS READ ────────────────────────────────────────────────────────────────
The last 1 MB of stderr.log (the harness's own messages, plus run.sh's "HARNESS ERROR" lines)
and of result.jsonl, where ONLY error events count (type error / turn.failed, is_error, or an
`error` key): the model's own text in result.jsonl can quote these wordings (a worker reading
this file would), and that is not a limit.

Which recognisers run depends on the worker kind: claude's wording only for claude workers;
glm's and plain HTTP 429 for every kind (GLM is reached through opencode or a claude harness
pointed at it).

CLI (called by run.sh at dispatch completion, right after S3's append; always exit 0):
  quota_limits.py append --meta META_JSON --wdir WDIR [--worker-kind K]
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

READ_TAIL_BYTES = 1024 * 1024
UNKNOWN = "unknown"
_UTC = _dt.timezone.utc

_MONTHS = {m: i for i, m in enumerate(
    ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"), 1)}

# claude: "You've hit your weekly limit · resets Nov 21, 5am (UTC)". The separator varies (·, ∙, -, |).
_CLAUDE = re.compile(
    r"(?:hit your|reached your)\s+(?P<what>weekly|opus weekly|5-hour|five-hour|session)\s+limit"
    r"(?:[^\n]{0,8}?resets\s+(?P<when>(?:[A-Za-z]{3,9}\.?\s+\d{1,2},?\s+(?:at\s+)?)?"
    r"\d{1,2}(?::\d{2})?(?:\s*[ap]m)?)\b\s*(?:\((?P<tz>[A-Za-z][A-Za-z0-9/_+:-]{0,39})\))?)?",
    re.IGNORECASE)
_CLAUDE_WHEN = re.compile(
    r"^(?:(?P<mon>[A-Za-z]{3,9})\.?\s+(?P<day>\d{1,2}),?\s+(?:at\s+)?)?"
    r"(?P<h>\d{1,2})(?::(?P<m>\d{2}))?\s*(?P<ap>am|pm)?$", re.IGNORECASE)

# glm
_GLM_USAGE = re.compile(
    r"Usage limit reached for (?P<span>\d+\s*hours?|week(?:ly)?|month(?:ly)?)\b"
    r"(?:[^\n]{0,40}?reset at (?P<at>\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?))?",
    re.IGNORECASE)
_GLM_RATE = re.compile(r"Rate limit reached for requests", re.IGNORECASE)
_GLM_BALANCE = re.compile(r"Insufficient balance or no resource package", re.IGNORECASE)

# any harness
_HTTP_429 = re.compile(r"\b429\b\W{0,3}Too Many Requests", re.IGNORECASE)


def _as_dt(v) -> _dt.datetime | None:
    if v is None:
        return None
    if isinstance(v, _dt.datetime):
        return v if v.tzinfo else v.replace(tzinfo=_UTC)
    try:
        d = _dt.datetime.fromisoformat(str(v).replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=_UTC)
    except (TypeError, ValueError):
        return None


def _iso(d: _dt.datetime) -> str:
    return d.astimezone(_UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def claude_reset(when: str | None, tz: str | None, at=None) -> dict:
    """Reset fields for a claude 'resets <when> (<tz>)' clause. See RESET RULES above."""
    literal = " ".join((when or "").split())
    unknown = {"reset": UNKNOWN}
    if literal:
        unknown["reset_text"] = literal + (f" ({tz})" if tz else "")
    if not literal or (tz or "").upper() != "UTC":
        return unknown
    m = _CLAUDE_WHEN.match(literal)
    if not m:
        return unknown
    h, mi, ap = int(m["h"]), int(m["m"] or 0), (m["ap"] or "").lower()
    if ap:
        if not 1 <= h <= 12:
            return unknown
        h = h % 12 + (12 if ap == "pm" else 0)
    if h > 23 or mi > 59:
        return unknown
    now = _as_dt(at)
    if now is None:
        return unknown
    now = now.astimezone(_UTC)
    if m["mon"]:
        mon = _MONTHS.get(m["mon"][:3].lower())
        if mon is None:
            return unknown
        try:
            cand = _dt.datetime(now.year, mon, int(m["day"]), h, mi, tzinfo=_UTC)
            if cand < now - _dt.timedelta(days=1):
                cand = cand.replace(year=now.year + 1)
        except ValueError:
            return unknown
    else:
        # No date: the next h:mi UTC strictly after the message time.
        cand = now.replace(hour=h, minute=mi, second=0, microsecond=0)
        if cand <= now:
            cand += _dt.timedelta(days=1)
    return {"reset_at": _iso(cand)}


def _glm_kind(span: str) -> str:
    s = span.lower()
    n = re.match(r"(\d+)", s)
    if n:
        return f"{int(n.group(1))}h"
    return "weekly" if s.startswith("week") else "monthly"


def recognise(text: str, worker_kind: str | None = None, at=None) -> list[dict]:
    """Limit events found in `text`: [{"kind", "reset_at" | "reset", ["reset_text"]}], at most one
    per kind (the last occurrence wins). Pure: no I/O. `at` is the message time (for claude's
    date-less reset); unrelated text gives []."""
    if not text:
        return []
    found: list[tuple[int, str, dict]] = []   # (position, kind, reset fields)
    if (worker_kind or "claude") == "claude":
        for m in _CLAUDE.finditer(text):
            kind = "weekly" if "week" in m["what"].lower() else "5h"
            found.append((m.start(), kind, claude_reset(m["when"], m["tz"], at)))
    for m in _GLM_USAGE.finditer(text):
        fields: dict = {"reset": UNKNOWN}
        if m["at"]:
            fields["reset_text"] = m["at"]
        found.append((m.start(), _glm_kind(m["span"]), fields))
    for rx, kind in ((_GLM_RATE, "rate"), (_HTTP_429, "rate"), (_GLM_BALANCE, "balance")):
        for m in rx.finditer(text):
            found.append((m.start(), kind, {"reset": UNKNOWN}))
    by_kind: dict[str, dict] = {}
    for _, kind, fields in sorted(found, key=lambda t: t[0]):
        by_kind.pop(kind, None)
        by_kind[kind] = {"kind": kind, **fields}
    return list(by_kind.values())


# ── reading a worker directory ──────────────────────────────────────────────────

def _tail(p: Path, limit: int = READ_TAIL_BYTES) -> str:
    try:
        with open(p, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - limit))
            data = f.read(limit)
    except OSError:
        return ""
    if size > limit:   # drop the partial first line
        nl = data.find(b"\n")
        data = data[nl + 1:] if nl >= 0 else b""
    return data.decode("utf-8", errors="replace")


def _strings(v, out: list[str], budget: list[int]) -> None:
    if budget[0] <= 0:
        return
    if isinstance(v, str):
        budget[0] -= 1
        out.append(v)
    elif isinstance(v, dict):
        for x in v.values():
            _strings(x, out, budget)
    elif isinstance(v, list):
        for x in v:
            _strings(x, out, budget)


def result_error_text(raw: str) -> str:
    """Only the error events of a result.jsonl stream, as text."""
    out: list[str] = []
    for line in raw.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict):
            continue
        if ev.get("type") in ("error", "turn.failed") or ev.get("is_error") is True or "error" in ev:
            _strings(ev, out, [200])
    return "\n".join(out)


def worker_text(wdir) -> str:
    w = Path(wdir)
    return _tail(w / "stderr.log") + "\n" + result_error_text(_tail(w / "result.jsonl"))


def events_for_dispatch(meta: dict, wdir, worker_kind: str | None = None) -> list[dict]:
    """Ledger rows for one completed dispatch: ids from meta.json, the rest from recognise()."""
    here = str(Path(__file__).resolve().parent)
    if here not in sys.path:
        sys.path.insert(0, here)
    import quota_ledger  # noqa: E402  (sibling, S3)
    kind = worker_kind or meta.get("worker_kind") or "claude"
    at = _as_dt(meta.get("ended")) or _dt.datetime.now(_UTC)
    base = quota_ledger.make_row(event="dispatch", project=meta.get("project"), task=meta.get("task"),
                                 dispatch_id=meta.get("name"), worker_kind=kind,
                                 subscription=meta.get("subscription"), ts=_iso(at))
    base.pop("tokens", None)
    base["event"] = "limit"
    rows = []
    for ev in recognise(worker_text(wdir), kind, at):
        rows.append({**base, **ev, "source": "dispatch"})
    return rows


def append_for_dispatch(meta_path, wdir, worker_kind: str | None = None) -> int:
    """Append the limit events of one dispatch. Never raises; returns how many were written."""
    try:
        here = str(Path(__file__).resolve().parent)
        if here not in sys.path:
            sys.path.insert(0, here)
        import quota_ledger  # noqa: E402
        meta = json.loads(Path(meta_path).read_text(encoding="utf-8"))
        if not isinstance(meta, dict):
            return 0
        return sum(1 for row in events_for_dispatch(meta, wdir, worker_kind) if quota_ledger.append(row))
    except Exception as e:  # noqa: BLE001 - never change the dispatch outcome
        print(f"WARNING: quota limit events not recorded ({type(e).__name__}) — the run itself is "
              "unaffected", file=sys.stderr)
        return 0


def main(argv: list[str] | None = None) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="quota_limits.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("append")
    a.add_argument("--meta", required=True)
    a.add_argument("--wdir", required=True)
    a.add_argument("--worker-kind")
    try:
        args = ap.parse_args(argv)
    except SystemExit:
        return 0
    append_for_dispatch(args.meta, args.wdir, args.worker_kind)
    return 0


if __name__ == "__main__":
    sys.exit(main())
