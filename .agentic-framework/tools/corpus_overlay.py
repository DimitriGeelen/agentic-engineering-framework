#!/usr/bin/env python3
"""T-2629 (T-2620 GO, Slice A): live task-state projection onto map carrier uids.

Emits the wire-CANONICAL ``aef:annotate`` payload (T-2635; convergence
confirmed by 832 at rail 230 — their doc-at-tag names this shape canonical
and their harness fixture pins these exact bytes; the 0.7.0-era
``annotations/tone/title`` form remains an accepted intake alias until an
operator-sequenced retirement no earlier than 0.8.0):

    {"type": "aef:annotate", "map": <id>, "generated": <epoch>,
     "nodes": [{"uid", "badge", "text", "severity": info|warn|alert}]}

``badge`` clamps at 48 chars, ``text`` at 200 (intake-side too); the intake
maps severity→tone (info/warn/alert → info/warn/err). Extra top-level keys
(map, generated) are ignored by the intake.

Projection profiles are map-specific and live HERE, server-side, in exactly
one place (T-2620 IW-4) — the maps' carriers under-determine the projection
(horizon splits, focus/partial-complete splits, decision parsing).

aef-task-lifecycle (T-2629):

    tl_create        captured, horizon now
    tl_parked        captured, horizon next/later
    tl_work          started-work (focus badge from focus.yaml)
    tl_heal          issues
    tl_human_review  work-completed still in .tasks/active/ (partial-complete)
    tl_archive       work-completed in .tasks/completed/, 7-day window

aef-inception-flow (T-2634 — inception tasks only, keyed to the map's
existing uids):

    if_file          captured (filed, exploration not started)
    if_inception     started-work / issues (exploring)
    if_gw_outcome    work-completed still in .tasks/active/ — the go/no-go
                     decision queue (same population /approvals holds)
    if_done_go       completed, 7-day window, body ``**Decision**: GO``
    if_done_closed   completed, 7-day window, non-GO (NO-GO/DEFER/unparsed)

Severity: bucket's oldest last_update age — info, warn >7d, alert >30d.
Terminal buckets (tl_archive, if_done_*) are always info. Operator-queue
buckets (if_gw_outcome) floor at warn and escalate to alert when the oldest
waiter exceeds 7d — a non-empty decision queue is an action request, not
ambient state. Thresholds are v0 defaults; tuning is the
draft-trigger-handling decision point, deliberately not doctrine yet.

Every emitted node is filtered against the map's live latest-version uids —
a map edit that removes or renames a node silently drops that badge instead
of emitting a phantom uid (mirror of 832's unknown-uid tolerance, rail 197).
"""

import argparse
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import corpus_spec  # noqa: E402

ARCHIVE_WINDOW_DAYS = 7
WARN_DAYS = 7
ALERT_DAYS = 30

_FM_KEYS = re.compile(r"^(status|horizon|id|workflow_type):\s*(.+?)\s*$")


def _frontmatter(path: Path) -> dict:
    out = {}
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return out
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        return out
    for line in m.group(1).splitlines():
        km = _FM_KEYS.match(line)
        if km:
            out[km.group(1)] = km.group(2).strip("\"'")
    # last_update may be quoted or bare; keep it separate (value has colons)
    lm = re.search(r"^last_update:\s*['\"]?([0-9T:Z.+-]+)", m.group(1), re.M)
    if lm:
        out["last_update"] = lm.group(1)
    return out


def _age_days(ts: str, now: float):
    try:
        return (now - time.mktime(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S"))) / 86400
    except (ValueError, TypeError):
        return None


def carriers(root: Path, map_id: str) -> dict:
    """{uid: state-or-None} for every uid-bearing node in the map's latest
    version; {} when unreadable. Presence (not state) is what the phantom-uid
    filter needs — inception-flow nodes like the decision gateway carry a uid
    but no ``aef:meta state=`` (T-2634)."""
    d = root / ".context/designer/projects" / map_id
    try:
        meta = json.loads((d / "meta.json").read_text())
        spec = corpus_spec.parse_map((d / f"v{meta['latest']}.bpmn").read_text())
    except (OSError, ValueError, KeyError):
        return {}
    return {
        n["uid"]: (n.get("meta") or {}).get("state")
        for n in spec["nodes"]
        if n.get("uid")
    }


def _focus_task(root: Path):
    fy = root / ".context/working/focus.yaml"
    if not fy.is_file():
        return None
    m = re.search(r"^current_task:\s*(T-\d+)", fy.read_text(errors="replace"), re.M)
    return m.group(1) if m else None


def _task_lifecycle_buckets(root: Path, now: float) -> dict:
    buckets = {u: [] for u in (
        "tl_create", "tl_parked", "tl_work", "tl_heal", "tl_human_review", "tl_archive"
    )}
    for p in (root / ".tasks/active").glob("T-*.md"):
        f = _frontmatter(p)
        status, horizon = f.get("status"), f.get("horizon", "now")
        if status == "captured":
            buckets["tl_parked" if horizon in ("next", "later") else "tl_create"].append(f)
        elif status == "started-work":
            buckets["tl_work"].append(f)
        elif status == "issues":
            buckets["tl_heal"].append(f)
        elif status == "work-completed":
            buckets["tl_human_review"].append(f)
    for p in (root / ".tasks/completed").glob("T-*.md"):
        f = _frontmatter(p)
        age = _age_days(f.get("last_update", ""), now)
        if age is not None and age <= ARCHIVE_WINDOW_DAYS:
            buckets["tl_archive"].append(f)
    return buckets


_DECISION_RE = re.compile(r"^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b", re.M | re.I)


def _decision(path: Path):
    """GO/NO-GO/DEFER from the task body's ``**Decision**:`` marker, or None."""
    try:
        m = _DECISION_RE.search(path.read_text(errors="replace"))
    except OSError:
        return None
    return m.group(1).upper() if m else None


def _inception_flow_buckets(root: Path, now: float) -> dict:
    buckets = {u: [] for u in (
        "if_file", "if_inception", "if_gw_outcome", "if_done_go", "if_done_closed"
    )}
    for p in (root / ".tasks/active").glob("T-*.md"):
        f = _frontmatter(p)
        if f.get("workflow_type") != "inception":
            continue
        status = f.get("status")
        if status == "captured":
            buckets["if_file"].append(f)
        elif status in ("started-work", "issues"):
            buckets["if_inception"].append(f)
        elif status == "work-completed":
            buckets["if_gw_outcome"].append(f)
    for p in (root / ".tasks/completed").glob("T-*.md"):
        f = _frontmatter(p)
        if f.get("workflow_type") != "inception":
            continue
        age = _age_days(f.get("last_update", ""), now)
        if age is None or age > ARCHIVE_WINDOW_DAYS:
            continue
        key = "if_done_go" if _decision(p) == "GO" else "if_done_closed"
        buckets[key].append(f)
    return buckets


PROFILES = {
    "aef-task-lifecycle": _task_lifecycle_buckets,
    "aef-inception-flow": _inception_flow_buckets,
}

# Terminal buckets: settled history, never escalates past info.
_TERMINAL_UIDS = {"tl_archive", "if_done_go", "if_done_closed"}
# Operator-queue buckets: non-empty = action request. Warn floor, alert when
# the oldest waiter exceeds WARN_DAYS.
_QUEUE_UIDS = {"if_gw_outcome"}


def build_payload(root: Path, map_id: str, now: float | None = None) -> dict:
    now = now if now is not None else time.time()
    payload = {"type": "aef:annotate", "map": map_id, "generated": int(now),
               "nodes": []}
    profile = PROFILES.get(map_id)
    live = carriers(root, map_id)
    if not profile or not live:
        return payload
    focus = _focus_task(root)
    for uid, tasks in profile(root, now).items():
        if uid not in live or not tasks:  # phantom-uid filter / empty bucket
            continue
        ages = [a for a in (_age_days(t.get("last_update", ""), now) for t in tasks)
                if a is not None]
        oldest = max(ages) if ages else 0.0
        stuck = sum(1 for a in ages if a > WARN_DAYS)
        if uid in _TERMINAL_UIDS:
            severity = "info"
        elif uid in _QUEUE_UIDS:
            severity = "alert" if oldest > WARN_DAYS else "warn"
        else:
            severity = ("alert" if oldest > ALERT_DAYS
                        else "warn" if oldest > WARN_DAYS else "info")
        title = f"{len(tasks)} task(s)"
        if stuck and uid not in _TERMINAL_UIDS:
            title += f", {stuck} stuck >{WARN_DAYS}d (oldest {oldest:.0f}d)"
        if focus and any(t.get("id") == focus for t in tasks):
            title += f" — focus: {focus}"
        payload["nodes"].append(
            {"uid": uid, "badge": str(len(tasks))[:48],
             "severity": severity, "text": title[:200]}
        )
    return payload


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("map_id", nargs="?", default="aef-task-lifecycle")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[1]))
    args = ap.parse_args()
    print(json.dumps(build_payload(Path(args.root), args.map_id), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
