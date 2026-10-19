#!/usr/bin/env python3
"""T-4351 — effective cron schedule for a registry job.

`fw cron generate` (bin/fw) and its doctor/audit dry run (lib/cron_dry_run.py)
both copied each job's `schedule:` verbatim. The seeded `index-reindex-hourly`
job carries `20 * * * *`, so every project on a host ran its heaviest disk
writer at the same minute (6 of 8 projects on .107, dimitri-mint-dev T-135).

This module is the one place both generators ask "what line does cron get?".

How a minute is chosen deliberately (registry contract):

  * `schedule_pinned: true` on the job — the schedule is used verbatim, always.
  * Minute field `H` — "derive it": a stable hash of the project root, 0-59.
    Usable on any job (Jenkins' `H` convention).
  * index-reindex-hourly only: the seeded default minute `20` counts as NOT
    deliberate (every registry seeded before T-4351 carries it), so it is
    derived too. Any other numeric minute is deliberate and kept; to keep 20
    itself, set `schedule_pinned: true`.

Frequency knob (index-reindex-hourly only, unless pinned): config key
INDEX_REINDEX_INTERVAL_HOURS (env FW_INDEX_REINDEX_INTERVAL_HOURS, then
.framework.yaml, default 1). Applies when the hour field is `*`: 1 keeps `*`,
N in 2-24 writes `*/N`. Anything else falls back to 1 with a stderr note.
"""
import hashlib
import os
import sys

STAGGERED_JOBS = {"index-reindex-hourly": "20"}  # job id -> legacy seeded minute
INTERVAL_KEY = "INDEX_REINDEX_INTERVAL_HOURS"


def project_minute(project_root: str) -> int:
    """Stable 0-59 minute for a project: same root -> same minute, every run."""
    ident = os.path.realpath(project_root)
    return int(hashlib.sha256(ident.encode("utf-8")).hexdigest(), 16) % 60


def interval_hours(project_root: str) -> int:
    raw = os.environ.get("FW_" + INTERVAL_KEY, "").strip()
    if not raw:
        cfg = os.path.join(project_root, ".framework.yaml")
        try:
            import yaml
            with open(cfg) as f:
                data = yaml.safe_load(f) or {}
            if isinstance(data, dict) and data.get(INTERVAL_KEY) is not None:
                raw = str(data[INTERVAL_KEY]).strip()
        except Exception:
            raw = ""
    if not raw:
        return 1
    try:
        val = int(raw)
    except ValueError:
        val = 0
    if not 1 <= val <= 24:
        print(f"cron-schedule: {INTERVAL_KEY}={raw!r} is not an integer 1-24; using 1",
              file=sys.stderr)
        return 1
    return val


def effective_schedule(job: dict, project_root: str) -> str:
    schedule = str(job.get("schedule", "") or "")
    if job.get("schedule_pinned") is True:
        return schedule
    parts = schedule.split()
    if len(parts) != 5:
        return schedule
    jid = job.get("id")
    legacy = STAGGERED_JOBS.get(jid) if isinstance(jid, str) else None
    if parts[0] == "H" or (legacy is not None and parts[0] == legacy):
        parts[0] = str(project_minute(project_root))
    if legacy is not None and parts[1] == "*":
        n = interval_hours(project_root)
        if n > 1:
            parts[1] = f"*/{n}"
    return " ".join(parts)


if __name__ == "__main__":
    # usage: cron_schedule.py <project_root>  -> prints the derived minute
    print(project_minute(sys.argv[1] if len(sys.argv) > 1 else "."))
