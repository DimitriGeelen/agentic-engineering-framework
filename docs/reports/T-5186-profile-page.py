"""T-5186 spike: profile Watchtower pages in-process (no host contention). Read-only."""
import cProfile
import io
import os
import pstats
import sys
import time

root = sys.argv[1]
paths = sys.argv[2:] or ["/approvals"]
os.chdir(root)
os.environ.setdefault("PROJECT_ROOT", root)
sys.path.insert(0, root)
from web.app import app  # noqa: E402

c = app.test_client()
for p in paths:
    for run in (1, 2):
        pr = cProfile.Profile()
        t0, c0 = time.time(), time.process_time()
        pr.enable()
        r = c.get(p)
        pr.disable()
        wall, cpu = time.time() - t0, time.process_time() - c0
        print(f"\n=== {p} run{run}: status {r.status_code} wall {wall:.2f}s cpu {cpu:.2f}s bytes {len(r.data)}")
        if run == 1:
            s = io.StringIO()
            st = pstats.Stats(pr, stream=s).sort_stats("cumulative")
            st.print_stats(28)
            out = [ln for ln in s.getvalue().splitlines() if ln.strip()]
            print("\n".join(out[:45]))
