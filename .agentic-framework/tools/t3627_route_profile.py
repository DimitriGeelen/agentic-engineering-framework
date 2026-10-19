#!/usr/bin/env python3
"""T-3627: profile Watchtower GET routes in-process (app.test_client, never a live server).

For each parameterless GET route: time the first (cold) and second (warm) request and
count the files opened by the WARM request (sys.audit "open" events under the corpus
dirs). A route whose warm request still opens hundreds of corpus files re-reads the
corpus on every request with no cache — the /graduation class.

Usage: python3 tools/t3627_route_profile.py [--routes /a /b ...] [--top N]
"""
import argparse
import importlib.util
import os
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.environ.setdefault("PROJECT_ROOT", str(ROOT))
sys.path.insert(0, str(ROOT))

CORPUS = (str(ROOT / ".tasks"), str(ROOT / ".context" / "episodic"),
          str(ROOT / ".context"), str(ROOT / "docs"), str(ROOT / ".fabric"))
_state = threading.local()


def _hook(event, args):
    if event == "open" and getattr(_state, "counting", False):
        p = args[0]
        if isinstance(p, (str, bytes, os.PathLike)):
            p = os.fsdecode(p)
            if p.startswith(CORPUS):
                _state.count += 1


def _routes():
    spec = importlib.util.spec_from_file_location(
        "uxr", ROOT / "agents" / "ux-review" / "ux-review.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.discover_get_routes()


def _hit(client, route):
    _state.counting, _state.count = True, 0
    t0 = time.perf_counter()
    try:
        code = client.get(route).status_code
    except Exception as e:  # a crashing route is a finding, not a profiler failure
        code = f"EXC {type(e).__name__}"
    dt = time.perf_counter() - t0
    _state.counting = False
    return code, dt, _state.count


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--routes", nargs="*")
    ap.add_argument("--top", type=int, default=25)
    a = ap.parse_args(argv)
    sys.addaudithook(_hook)
    from web.app import app
    client = app.test_client()
    routes = a.routes or _routes()
    rows = []
    for r in routes:
        code, cold, cold_n = _hit(client, r)
        _, warm, warm_n = _hit(client, r)
        rows.append((warm_n, warm, cold, cold_n, code, r))
        print(f"{r:45s} {code!s:>4} cold {cold:6.2f}s/{cold_n:5d} files  "
              f"warm {warm:6.2f}s/{warm_n:5d} files", flush=True)
    print("\n== worst warm (files re-read on a warm request) ==")
    for warm_n, warm, cold, cold_n, code, r in sorted(rows, reverse=True)[:a.top]:
        print(f"{r:45s} warm {warm:6.2f}s {warm_n:5d} files | cold {cold:6.2f}s {cold_n:5d}")


if __name__ == "__main__":
    main()
