#!/usr/bin/env python3
"""T-2629 (T-2620 GO, Slice A): live task-state projection onto map carrier uids.

Emits the wire-ready ``aef:annotate`` payload in the designer 0.7.0 SHIPPED
intake shape (T-2632; 832 T-258, protocol doc §Annotation seam at tag
designer-v0.7.0 — supersedes the rail-197 draft field names):

    {"type": "aef:annotate", "map": <id>, "generated": <epoch>,
     "annotations": [{"uid", "badge", "tone", "title"}]}

``badge`` clamps at 48 chars, ``title`` at 200 (intake-side too); ``tone`` is
one of info|ok|warn|err — our severity ladder maps info→info, warn→warn,
alert→err. Extra top-level keys (map, generated) are ignored by the intake.

Projection profile (v0, aef-task-lifecycle only — the map's ``state=`` carriers
under-determine the projection: two ``captured`` carriers split on horizon,
three ``started-work`` carriers split on focus/partial-complete, so the rules
are map-specific and live HERE, server-side, in exactly one place — T-2620 IW-4):

    tl_create        captured, horizon now
    tl_parked        captured, horizon next/later
    tl_work          started-work (focus badge from focus.yaml)
    tl_heal          issues
    tl_human_review  work-completed still in .tasks/active/ (partial-complete)
    tl_archive       work-completed in .tasks/completed/, 7-day window

Severity: bucket's oldest last_update age — info, warn >7d, alert >30d
(tl_archive always info). Thresholds are v0 defaults; tuning is the
draft-trigger-handling decision point, deliberately not doctrine yet.

Every emitted node is filtered against the map's live latest-version carriers
(uid present AND carrying ``aef:meta state=``) — a map edit that removes or
renames a carrier silently drops that badge instead of emitting a phantom uid
(mirror of 832's unknown-uid tolerance, rail 197).
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

_FM_KEYS = re.compile(r"^(status|horizon|id):\s*(.+?)\s*$")


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
    """{uid: state} for the map's latest version; {} when unreadable."""
    d = root / ".context/designer/projects" / map_id
    try:
        meta = json.loads((d / "meta.json").read_text())
        spec = corpus_spec.parse_map((d / f"v{meta['latest']}.bpmn").read_text())
    except (OSError, ValueError, KeyError):
        return {}
    return {
        n.get("uid"): n["meta"]["state"]
        for n in spec["nodes"]
        if n.get("uid") and (n.get("meta") or {}).get("state")
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


PROFILES = {"aef-task-lifecycle": _task_lifecycle_buckets}


_TONE = {"info": "info", "warn": "warn", "alert": "err"}


def build_payload(root: Path, map_id: str, now: float | None = None) -> dict:
    now = now if now is not None else time.time()
    payload = {"type": "aef:annotate", "map": map_id, "generated": int(now),
               "annotations": []}
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
        severity = "info"
        if uid != "tl_archive":
            severity = ("alert" if oldest > ALERT_DAYS
                        else "warn" if oldest > WARN_DAYS else "info")
        title = f"{len(tasks)} task(s)"
        if stuck and uid != "tl_archive":
            title += f", {stuck} stuck >{WARN_DAYS}d (oldest {oldest:.0f}d)"
        if focus and any(t.get("id") == focus for t in tasks):
            title += f" — focus: {focus}"
        payload["annotations"].append(
            {"uid": uid, "badge": str(len(tasks))[:48],
             "tone": _TONE[severity], "title": title[:200]}
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
