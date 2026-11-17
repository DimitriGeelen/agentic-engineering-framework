#!/usr/bin/env python3
"""`fw quota status`: free / tight / at limit until, per subscription. Read-only (T-5204, T-5190 S5).

One shared answer any project can ask before a large round, in the same words. No provider
publishes its quota numbers, so nothing here is a percentage of a known limit: every state comes
from what the machine-wide ledger (lib/quota_ledger.py, S3) shows — limit events (S4,
lib/quota_limits.py) and the tokens that went before them.

── THE RULES (task T-5204, Goal) ────────────────────────────────────────────────
Per subscription, L = its latest limit event (by ts).
  at limit until <t>      L has reset_at in the future.
  at limit (reset unknown) L has no reset, no dispatch on that subscription has completed since
                          it (the dispatch that raised L does not count), and L is still inside
                          its window.
  tight                   a limit event inside its window has already reset (reset_at passed, or
                          an unknown reset cleared by a later dispatch); or, with --need N, the
                          tokens used in the current 5 h window plus N exceed 80% of the capacity
                          estimate.
  free                    otherwise; "capacity unknown" when there is no estimate.
Window per limit kind: 5 h for 5h and rate (glm rate, HTTP 429), 7 days for weekly, 24 h for
balance and anything else.
Capacity estimate: the tokens used in the 5 h before the most recent 5h limit event. Zero
counted tokens there is no estimate (unknown is not zero, T-3519).
Token count of a row: tokens.total when reported, else the sum of the reported parts.

── WHICH SUBSCRIPTIONS ─────────────────────────────────────────────────────────
Every id in the registry, plus any other id (unassigned, unknown, an id since removed from the
registry) that has a ledger row in the last 7 days, marked registered: false.

── OUTPUT ──────────────────────────────────────────────────────────────────────
Only ids, states, times and counts. Never a project, task, dispatch id or message text (a GLM
reset_text is a fixed date-time pattern from S4 and is shown as such, zone unknown).

CLI:
  quota_status.py [--need N] [--subscription ID] [--json] [--now ISO]
  exit 0 all free, 1 any tight, 2 any at limit, 3 usage error (unknown --subscription id)
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import sys
from pathlib import Path

_UTC = _dt.timezone.utc
H = _dt.timedelta(hours=1)
FIVE_H = 5 * H
WINDOWS = {"5h": FIVE_H, "rate": FIVE_H, "weekly": _dt.timedelta(days=7)}
DEFAULT_WINDOW = 24 * H
SEEN_HORIZON = _dt.timedelta(days=7)
READ_HORIZON = _dt.timedelta(days=30)   # the CLI reads this much ledger (capacity estimate's reach)
TIGHT_FRACTION = 0.8
TOKEN_PARTS = ("input", "output", "cache_read", "cache_creation")
FREE, TIGHT, AT_LIMIT = "free", "tight", "at-limit"
EXIT = {FREE: 0, TIGHT: 1, AT_LIMIT: 2}
USAGE_EXIT = 3


def _dt_of(v) -> _dt.datetime | None:
    if isinstance(v, _dt.datetime):
        return v if v.tzinfo else v.replace(tzinfo=_UTC)
    if not v:
        return None
    try:
        d = _dt.datetime.fromisoformat(str(v).replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=_UTC)
    except (TypeError, ValueError):
        return None


def _iso(d: _dt.datetime) -> str:
    return d.astimezone(_UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def window_for(kind) -> _dt.timedelta:
    return WINDOWS.get(str(kind or ""), DEFAULT_WINDOW)


def row_tokens(row: dict) -> int:
    t = row.get("tokens")
    if not isinstance(t, dict):
        return 0
    def ok(v):
        return isinstance(v, (int, float)) and not isinstance(v, bool) and v >= 0
    if ok(t.get("total")):
        return int(t["total"])
    return int(sum(t[k] for k in TOKEN_PARTS if ok(t.get(k))))


def _use_tokens(rows: list[dict], start: _dt.datetime, end: _dt.datetime) -> int:
    """Tokens of dispatch/review rows with start < ts <= end."""
    n = 0
    for r in rows:
        if r.get("event") not in ("dispatch", "review"):
            continue
        t = _dt_of(r.get("ts"))
        if t is not None and start < t <= end:
            n += row_tokens(r)
    return n


def _limit_view(ev: dict) -> dict:
    out = {"kind": str(ev.get("kind") or "unknown"), "ts": _iso(ev["_t"])}
    ra = _dt_of(ev.get("reset_at"))
    if ra is not None:
        out["reset_at"] = _iso(ra)
    else:
        out["reset"] = "unknown"
        if isinstance(ev.get("reset_text"), str):
            out["reset_text"] = ev["reset_text"]
    return out


def _limit_status(ev: dict, rows: list[dict], now: _dt.datetime) -> str | None:
    """'active' (at limit), 'reset-in-window' (tight), or None (outside its window)."""
    t = ev["_t"]
    if t > now:
        t = now   # a clock a little ahead: treat as just now
    ra = _dt_of(ev.get("reset_at"))
    if ra is not None and ra > now:
        return "active"
    in_window = now - t < window_for(ev.get("kind"))
    if ra is None:
        cleared = any(
            r.get("event") == "dispatch" and (_dt_of(r.get("ts")) or t) > t
            and not (ev.get("dispatch_id") and r.get("dispatch_id") == ev.get("dispatch_id"))
            for r in rows)
        if not cleared and in_window:
            return "active"
    return "reset-in-window" if in_window else None


def status_one(sid: str, rows: list[dict], now: _dt.datetime, need: int | None = None,
               registered: bool = True) -> dict:
    """The state of one subscription from its own ledger rows (any order)."""
    rows = [r for r in rows if r.get("subscription") == sid]
    limits = []
    for r in rows:
        if r.get("event") == "limit":
            t = _dt_of(r.get("ts"))
            if t is not None and t <= now + H:
                limits.append({**r, "_t": t})
    limits.sort(key=lambda e: e["_t"])
    window_tokens = _use_tokens(rows, now - FIVE_H, now)

    five = [e for e in limits if e.get("kind") == "5h"]
    capacity = None
    if five:
        lt = five[-1]["_t"]
        capacity = _use_tokens(rows, lt - FIVE_H, lt) or None

    out = {"id": sid, "registered": registered, "state": FREE, "until": None, "reason": "",
           "last_limit": _limit_view(limits[-1]) if limits else None,
           "window_tokens": window_tokens, "capacity_estimate": capacity, "need": need}

    if limits:
        last = limits[-1]
        if _limit_status(last, rows, now) == "active":
            ra = _dt_of(last.get("reset_at"))
            out["state"] = AT_LIMIT
            if ra is not None and ra > now:
                out["until"] = _iso(ra)
                out["reason"] = f"{last.get('kind')} limit at {_iso(last['_t'])}, resets {_iso(ra)}"
            else:
                out["until"] = "unknown"
                out["reason"] = (f"{last.get('kind')} limit at {_iso(last['_t'])}, reset unknown, "
                                 f"no dispatch completed since; holds at most until "
                                 f"{_iso(last['_t'] + window_for(last.get('kind')))}")
            return out
        recent = [e for e in limits if _limit_status(e, rows, now) == "reset-in-window"]
        if recent:
            e = recent[-1]
            out["state"] = TIGHT
            out["reason"] = (f"{e.get('kind')} limit at {_iso(e['_t'])} has reset, its window is "
                             f"still open until {_iso(e['_t'] + window_for(e.get('kind')))}")
            return out
    if need is not None and capacity:
        if window_tokens + need > TIGHT_FRACTION * capacity:
            out["state"] = TIGHT
            out["reason"] = (f"{window_tokens} tokens in the last 5 h + need {need} exceed 80% of "
                             f"the capacity estimate {capacity}")
            return out
    out["reason"] = "no limit in any open window" + ("" if capacity else "; capacity unknown")
    return out


def status(rows: list[dict], registry: dict, now, need: int | None = None,
           subscription: str | None = None) -> list[dict]:
    """Pure core: one dict per subscription. No I/O."""
    now = _dt_of(now) or _dt.datetime.now(_UTC)
    reg_ids = [s["id"] for s in (registry or {}).get("subscriptions") or [] if s.get("id")]
    ids = list(reg_ids)
    for r in rows:
        sid = r.get("subscription")
        t = _dt_of(r.get("ts"))
        if isinstance(sid, str) and sid and sid not in ids and t is not None and now - t < SEEN_HORIZON:
            ids.append(sid)
    if subscription is not None:
        ids = [i for i in ids if i == subscription] or [subscription]
    return [status_one(i, rows, now, need, i in reg_ids) for i in ids]


def exit_code(results: list[dict]) -> int:
    return max([EXIT[r["state"]] for r in results] or [0])


def _fmt_n(n) -> str:
    return "unknown" if n is None else f"{n:,}"


def line(r: dict) -> str:
    if r["state"] == AT_LIMIT:
        head = f"at limit until {r['until']}" if r["until"] != "unknown" else "at limit (reset unknown)"
    else:
        head = r["state"]
    parts = [f"{r['id']}{'' if r['registered'] else ' (not in registry)'}: {head}", r["reason"]]
    ev = r["last_limit"]
    if ev:
        reset = ev.get("reset_at") or "unknown"
        if ev.get("reset_text"):
            reset += f" (message says {ev['reset_text']}, zone not given)"
        parts.append(f"last limit {ev['kind']} at {ev['ts']}, reset {reset}")
    else:
        parts.append("no limit event")
    parts.append(f"5 h window {_fmt_n(r['window_tokens'])} tokens")
    parts.append(f"capacity estimate {_fmt_n(r['capacity_estimate'])}")
    if r.get("need") is not None:
        parts.append(f"need {_fmt_n(r['need'])}")
    return " — ".join(parts[:2]) + "; " + "; ".join(parts[2:])


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw quota status",
                                 description="free / tight / at limit, per subscription (read-only, T-5204)")
    ap.add_argument("--need", type=int, help="tokens the next round needs")
    ap.add_argument("--subscription", help="only this subscription id")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--now", help="evaluate at this ISO time instead of now (replay/tests)")
    args = ap.parse_args(argv)
    if args.need is not None and args.need < 0:
        print("--need must be zero or more tokens", file=sys.stderr)
        return USAGE_EXIT
    now = _dt.datetime.now(_UTC)
    if args.now:
        now = _dt_of(args.now)
        if now is None:
            print("--now must be an ISO time", file=sys.stderr)
            return USAGE_EXIT
    here = str(Path(__file__).resolve().parent)
    if here not in sys.path:
        sys.path.insert(0, here)
    import quota_ledger  # noqa: E402
    import subscriptions  # noqa: E402
    try:
        registry = subscriptions.load()
    except subscriptions.SubscriptionError as e:
        print(f"WARNING: subscription registry unreadable — showing ledger ids only "
              f"({str(e).splitlines()[0]})", file=sys.stderr)
        registry = {"subscriptions": []}
    rows = quota_ledger.rows(since=now - READ_HORIZON)
    results = status(rows, registry, now, args.need, args.subscription)
    if args.subscription is not None and not results[0]["registered"] and not any(
            r.get("subscription") == args.subscription for r in rows):
        print(f"unknown subscription id {args.subscription!r} (not in the registry, no ledger rows)",
              file=sys.stderr)
        return USAGE_EXIT
    if args.json:
        print(json.dumps({"now": _iso(now), "subscriptions": results}, indent=2, sort_keys=True))
    elif not results:
        print("No subscriptions registered and no ledger rows in the last 7 days.")
    else:
        for r in results:
            print(line(r))
    return exit_code(results)


if __name__ == "__main__":
    sys.exit(main())
