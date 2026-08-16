"""Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4).

Four signals, four separate sources, deliberately not blended into one score:

  freshness  — how old the index actually is (web.embeddings.index_freshness)
  usage      — is anybody querying it, and does the query find anything
               (web.recall_telemetry.usage_summary)
  happiness  — did the human/agent think the hits were useful
               (.context/working/happiness.jsonl, T-1719 A2)
  routing    — which provider served recent dispatches (.context/dispatches.jsonl)

Keeping them apart is the point. An index can be fresh and unqueried, queried and
missing, hitting and useless. A single composite number would let any one of those
hide inside the others, and the arc this page belongs to exists because a
five-month-old index passed for current (T-3004).

TRI-STATE DISCIPLINE. Every loader here returns `None` for "could not determine"
and never substitutes 0 or now(). A missing answer rendered as a number is
indistinguishable from a good one — that is the exact mechanism behind T-3004,
and web/embeddings.py:index_freshness carries the same rule in its docstring.
The template renders `None` as an explicit "unknown", never as a dash that could
read as zero.

Read-only by construction: this page opens the DB and reads JSONL files. It never
triggers a build or a reindex. An observability surface that can mutate the thing
it observes is a page you become afraid to refresh.
"""

import json
from pathlib import Path

from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("embeddings", __name__)

# How many trailing entries each ledger contributes. These are display caps, not
# analysis windows — the rates above them are computed over the full window.
RECENT_HAPPINESS = 10
RECENT_ROUTING = 10

# The miss-rate window the AC names. Kept separate from the 7-day doctor window
# (FW_RECALL_USAGE_DAYS) on purpose: doctor asks "is anybody using this at all",
# this page asks "is it working right now", and those want different horizons.
MISS_RATE_WINDOW_DAYS = 1.0


def _read_jsonl_tail(path: Path, limit: int) -> list[dict]:
    """Last `limit` well-formed rows, newest first. Never raises.

    Malformed lines are skipped rather than failing the page. A corrupt row in an
    append-only ledger must not take out the panel that would let you see it —
    that is the failure mode where the instrument goes dark exactly when
    something has gone wrong with what it measures.
    """
    if not path.is_file():
        return []
    rows: list[dict] = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (ValueError, TypeError):
                    continue
                if isinstance(obj, dict):
                    rows.append(obj)
    except OSError:
        return []
    return list(reversed(rows[-limit:]))


def _index_state() -> dict:
    """Freshness + chunk count, or an explicit unavailable reason.

    `web.embeddings` imports sqlite-vec and the embedding stack, neither of which
    a consumer install is required to have. Import failure is a legitimate state
    to report, not an error to raise — same SKIP semantics as lib/index-health.sh.
    """
    try:
        from web.embeddings import DB_PATH, index_freshness
    except Exception as exc:  # noqa: BLE001 — any import failure is the same verdict
        return {"available": False, "reason": f"web.embeddings not importable: {exc}"}

    state: dict = {"available": True, "db_path": str(DB_PATH), "reason": None}

    try:
        fresh = index_freshness() or {}
    except Exception as exc:  # noqa: BLE001
        fresh = {}
        state["reason"] = f"freshness unavailable: {exc}"

    # age_seconds is None when undeterminable — propagate it, do not coerce.
    state["built_at"] = fresh.get("built_at")
    state["age_seconds"] = fresh.get("age_seconds")
    state["freshness_source"] = fresh.get("source")
    state["age_days"] = (
        round(state["age_seconds"] / 86400.0, 1)
        if isinstance(state["age_seconds"], (int, float))
        else None
    )

    state["chunks"] = None
    try:
        import sqlite3

        if Path(DB_PATH).is_file():
            con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
            try:
                state["chunks"] = con.execute(
                    "SELECT COUNT(*) FROM documents"
                ).fetchone()[0]
            finally:
                con.close()
    except Exception:  # noqa: BLE001 — count is a nice-to-have, absence is reportable
        state["chunks"] = None

    return state


def _usage_state() -> dict:
    """Rolling-window recall outcomes, or an explicit unavailable reason."""
    try:
        from web.recall_telemetry import usage_summary
    except Exception as exc:  # noqa: BLE001
        return {
            "available": False,
            "reason": f"web.recall_telemetry not importable: {exc}",
        }
    try:
        summary = usage_summary(window_days=MISS_RATE_WINDOW_DAYS)
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "reason": f"usage_summary failed: {exc}"}

    summary["available"] = True
    summary["reason"] = None
    # rows == 0 is the zero-consumer signal and is reported as its own fact.
    # miss_rate is already None in that case (a rate over zero samples is a
    # number that looks like an answer) — recall_telemetry.usage_summary keeps
    # that contract, so nothing here needs to re-derive it.
    summary["zero_consumer"] = summary.get("rows", 0) == 0
    return summary


def _happiness_state() -> dict:
    """Recent retrieval-happiness ratings (T-1719 A2) plus a mean over them.

    The mean is over the displayed rows only and is labelled as such in the
    template. Averaging a -5..+5 scale across all of history would flatten
    exactly the trend the signal exists to expose.
    """
    path = PROJECT_ROOT / ".context" / "working" / "happiness.jsonl"
    rows = _read_jsonl_tail(path, RECENT_HAPPINESS)
    values = [r.get("value") for r in rows if isinstance(r.get("value"), (int, float))]
    return {
        "path": str(path),
        "exists": path.is_file(),
        "recent": rows,
        "count": len(rows),
        "mean": round(sum(values) / len(values), 2) if values else None,
        "negative": sum(1 for v in values if v < 0),
        "positive": sum(1 for v in values if v > 0),
    }


def _routing_state() -> dict:
    """Last N dispatch envelopes — which provider/model actually served work."""
    path = PROJECT_ROOT / ".context" / "dispatches.jsonl"
    rows = _read_jsonl_tail(path, RECENT_ROUTING)
    decisions = []
    for r in rows:
        decisions.append(
            {
                "ts": r.get("ts") or r.get("timestamp"),
                "task_id": r.get("task_id"),
                "workflow_type": r.get("workflow_type") or r.get("task_type"),
                "mechanism": r.get("mechanism"),
                "model": r.get("model"),
                "dispatch_id": r.get("dispatch_id"),
            }
        )
    return {"path": str(path), "exists": path.is_file(), "recent": decisions}


@bp.route("/embeddings")
def embeddings_panel():
    """The recall substrate's instrument panel (T-1719 A4)."""
    index = _index_state()
    usage = _usage_state()
    happiness = _happiness_state()
    routing = _routing_state()

    # One headline verdict, derived only from signals that are actually present.
    # "unknown" is a first-class outcome here for the same reason it is in
    # index_freshness: claiming health on absent evidence is the bug.
    if not index.get("available"):
        verdict, verdict_note = "unknown", "embedding stack not importable"
    elif index.get("age_days") is None:
        verdict, verdict_note = "unknown", "index age could not be determined"
    elif index["age_days"] > 30:
        verdict, verdict_note = "stale", f"index is {index['age_days']} days old"
    elif usage.get("available") and usage.get("zero_consumer"):
        verdict, verdict_note = "unused", "no recall queries in the window"
    else:
        verdict, verdict_note = "ok", None

    return render_page(
        "embeddings.html",
        page_title="Embeddings",
        index=index,
        usage=usage,
        happiness=happiness,
        routing=routing,
        verdict=verdict,
        verdict_note=verdict_note,
        miss_rate_window_days=MISS_RATE_WINDOW_DAYS,
    )
