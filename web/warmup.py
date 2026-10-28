"""Startup cache warm-up for Watchtower (T-4363).

A cold Watchtower listens within ~2 s, but the first request to a page that
reads the task corpus builds every mtime cache on the request thread: on 832
(~1,200 tasks) the first GET /approvals took 13.4 s against 1.3 s warm, and
here (~4,400 tasks) 40.9 s against 11.9 s. fw doctor's smoke probe gives each
route 5 s, so a doctor run right after a restart reported timeouts that were
only the cold build.

The fix is not one cache. The cold cost is spread over several readers that
different pages share (``shared.get_all_task_metadata``, the review-readiness
and inception-blocker caches behind ``/approvals``, the dashboard's cost and
verify readers — T-3765 named four), and naming each one here would rot the
way T-3765's list did. So the warm-up issues the pages themselves, through the
app's own test client, on a daemon thread: whatever a page reads cold is
filled before an operator or the smoke probe asks for it.

``WARMUP_STATE`` is surfaced by ``/api/_identity`` so a probe can tell a
deliberate warm-up from a slow server (``web/smoke_test.py`` waits for it),
and by ``/health``, which never reads the corpus (T-4854).

The warm-up starts after the port binds, so a page request in the first seconds
still waits for the cold build. A watchdog that can only probe a page sets
``WATCHTOWER_WARM_BEFORE_SERVE=1`` (default 0): the serve entry points then finish
the warm-up before they serve (T-4854, ring20-dashboard's restart loop).
"""
from __future__ import annotations

import datetime
import os
import re
import threading
import time

# The pages whose cold build is the expensive one (measured T-4363: /, /search,
# /approvals, /tasks, /timeline were the five slowest cold routes; /cron is
# named in 832's doctor report). Order: shared corpus readers first.
# /search carries a keyword query (T-4458): without one the page never builds the
# keyword index, and the first real search paid that build (17-89 s, host load).
WARM_PATHS: tuple[str, ...] = ("/", "/approvals", "/tasks", "/cron", "/timeline",
                               "/search?q=warmup&mode=keyword")

WARMUP_STATE: dict = {"state": "idle", "started_at": None, "finished_at": None, "paths": {}}

_START_LOCK = threading.Lock()


def _now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _run(app, paths) -> None:
    try:
        client = app.test_client()
        for path in paths:
            t0 = time.monotonic()
            try:
                status = client.get(path).status_code
            except Exception as e:  # a page that fails here fails for the operator too; keep going
                status = f"error: {type(e).__name__}: {e}"
            WARMUP_STATE["paths"][path] = {"status": status,
                                           "seconds": round(time.monotonic() - t0, 2)}
    finally:  # never leave a probe waiting on a warm-up that died
        WARMUP_STATE["finished_at"] = _now()
        WARMUP_STATE["state"] = "done"


def _project_root():
    from web.shared import PROJECT_ROOT
    return PROJECT_ROOT


def warm_before_serve() -> bool:
    """WATCHTOWER_WARM_BEFORE_SERVE: env > .framework.yaml > default 0. See lib/config.sh."""
    val = os.environ.get("FW_WATCHTOWER_WARM_BEFORE_SERVE")
    if val is None:
        try:
            text = (_project_root() / ".framework.yaml").read_text(encoding="utf-8", errors="replace")
        except OSError:
            text = ""
        m = re.search(r"^\s*WATCHTOWER_WARM_BEFORE_SERVE\s*:\s*(\S+)", text, re.M)
        val = m.group(1).strip("\"'") if m else ""
    return val.strip().lower() in ("1", "true", "yes")


def start_cache_warmup(app, paths=WARM_PATHS, wait=False):
    """Start the warm-up on a daemon thread once per process; return the thread
    (None when it already ran or is running). ``wait`` joins it before returning."""
    with _START_LOCK:
        if WARMUP_STATE["state"] != "idle":
            return None
        WARMUP_STATE.update(state="warming", started_at=_now(), finished_at=None, paths={})
        t = threading.Thread(target=_run, args=(app, tuple(paths)),
                             name="watchtower-cache-warmup", daemon=True)
        t.start()
    if wait:
        t.join()
    return t
