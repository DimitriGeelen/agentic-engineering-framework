"""T-5186 spike: count and time every subprocess a cold /approvals runs, by command shape. Read-only."""
import collections
import os
import subprocess
import sys
import time

root = sys.argv[1]
page = sys.argv[2] if len(sys.argv) > 2 else "/approvals"
os.chdir(root)
os.environ.setdefault("PROJECT_ROOT", root)
sys.path.insert(0, root)

stats = collections.defaultdict(lambda: [0, 0.0])
callers = collections.defaultdict(collections.Counter)
_real = subprocess.Popen.__init__


def _wrap(self, args, *a, **kw):
    import traceback
    t = time.time()
    _real(self, args, *a, **kw)
    argv = args if isinstance(args, (list, tuple)) else [str(args)]
    key = " ".join(str(x) for x in argv[:2] if not str(x).startswith("-C"))
    if len(argv) > 2 and str(argv[1]) == "-C":
        key = " ".join(str(x) for x in argv[3:5])
    self._t5186 = (key, t)
    fr = [f for f in traceback.extract_stack(limit=12) if "/opt/999" in f.filename and "prof_subproc" not in f.filename]
    if fr:
        callers[key][f"{os.path.basename(fr[-1].filename)}:{fr[-1].name}"] += 1


_wait = subprocess.Popen.wait


def _wait2(self, *a, **kw):
    r = _wait(self, *a, **kw)
    k = getattr(self, "_t5186", None)
    if k and not getattr(self, "_t5186_done", False):
        self._t5186_done = True
        stats[k[0]][0] += 1
        stats[k[0]][1] += time.time() - k[1]
    return r


subprocess.Popen.__init__ = _wrap
subprocess.Popen.wait = _wait2

from web.app import app  # noqa: E402

t0 = time.time()
r = app.test_client().get(page)
print(f"{page}: status {r.status_code} wall {time.time()-t0:.2f}s")
tot = sum(v[0] for v in stats.values())
print(f"subprocesses: {tot}, summed wall {sum(v[1] for v in stats.values()):.1f}s")
for k, (n, s) in sorted(stats.items(), key=lambda kv: -kv[1][1])[:12]:
    top = ", ".join(f"{c}×{m}" for c, m in callers[k].most_common(3))
    print(f"  {n:5d}  {s:6.1f}s  {k[:50]:50s}  {top}")
