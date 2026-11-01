"""T-4966: concurrent `fw reviewer judge` runs in one checkout.

ring20-dashboard runs 3 judges at once. Verdict appends and commits shared one lock (T-3940),
but the review-register appends (dispatches, runs, completions) did not, while every verdict
commit stages those files (T-4591). A commit could catch a half-written line, and a committed
torn line breaks the completions file's append-only history check for good.

Pinned here, with real processes and real git:
  - the ledger lock is re-entrant within one process (a nested acquire never blocks);
  - several processes appending large register rows while another commits in a loop leave
    every committed blob line-parseable, and `history_fault` clean.
"""
from __future__ import annotations

import json
import multiprocessing as mp
import subprocess
import sys
import time
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))

from lib import verdict_ledger as vl  # noqa: E402

GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"]


def _repo(tmp_path: Path) -> Path:
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    (tmp_path / vl.COMPLETIONS).parent.mkdir(parents=True, exist_ok=True)
    (tmp_path / vl.COMPLETIONS).write_text("")
    subprocess.run(GIT + ["-C", str(tmp_path), "add", "-A"], check=True)
    subprocess.run(GIT + ["-C", str(tmp_path), "commit", "-q", "-m", "init"], check=True)
    return tmp_path


def test_ledger_lock_is_reentrant_in_one_process(tmp_path):
    code = (
        "import sys; sys.path.insert(0, sys.argv[1]); from pathlib import Path\n"
        "from lib import verdict_ledger as vl\n"
        "root = Path(sys.argv[2])\n"
        "with vl._ledger_lock(root):\n"
        "    with vl._ledger_lock(root):\n"
        "        vl._append(vl.COMPLETIONS, {'n': 1}, root)\n"
        "print('ok')\n")
    out = subprocess.run([sys.executable, "-c", code, str(_HERE.parent.parent), str(tmp_path)],
                         capture_output=True, text=True, timeout=30)
    assert out.stdout.strip() == "ok", out.stderr


def test_lock_released_after_nested_use(tmp_path):
    with vl._ledger_lock(tmp_path):
        with vl._ledger_lock(tmp_path):
            pass
    # another process can take it now
    code = ("import sys; sys.path.insert(0, sys.argv[1]); from pathlib import Path\n"
            "from lib import verdict_ledger as vl\n"
            "with vl._ledger_lock(Path(sys.argv[2])): print('got')\n")
    out = subprocess.run([sys.executable, "-c", code, str(_HERE.parent.parent), str(tmp_path)],
                         capture_output=True, text=True, timeout=30)
    assert out.stdout.strip() == "got", out.stderr


def _writer(root: str, wid: int, rows: int) -> None:
    for i in range(rows):
        # ~20 KB per row: larger than Python's 8 KB write buffer, so an unlocked append is
        # several write(2) calls and a concurrent `git add` can see a partial line.
        vl._append(vl.COMPLETIONS, {"w": wid, "i": i, "pad": "x" * 20000}, Path(root))
        time.sleep(0.05)        # spread the writes over the committer's whole run


def _committer(root: str, stop_at: float) -> None:
    r = Path(root)
    while time.monotonic() < stop_at:
        with vl._ledger_lock(r):
            subprocess.run(GIT + ["-C", root, "add", str(vl.COMPLETIONS)], check=True)
            subprocess.run(GIT + ["-C", root, "commit", "-q", "-m", "c"], capture_output=True)


def test_parallel_appends_and_commits_never_commit_a_torn_line(tmp_path):
    root = _repo(tmp_path)
    ctx = mp.get_context("fork")
    stop_at = time.monotonic() + 6
    procs = [ctx.Process(target=_writer, args=(str(root), w, 60)) for w in range(4)]
    procs.append(ctx.Process(target=_committer, args=(str(root), stop_at)))
    for p in procs:
        p.start()
    for p in procs:
        p.join(120)
        assert p.exitcode == 0
    subprocess.run(GIT + ["-C", str(root), "add", str(vl.COMPLETIONS)], check=True)
    subprocess.run(GIT + ["-C", str(root), "commit", "-q", "-m", "final"], capture_output=True)

    shas = subprocess.run(["git", "-C", str(root), "log", "--format=%H", "--", str(vl.COMPLETIONS)],
                          capture_output=True, text=True, check=True).stdout.split()
    assert len(shas) > 10, f"only {len(shas)} commits: too few to exercise the race"
    for sha in shas:
        blob = subprocess.run(["git", "-C", str(root), "show", f"{sha}:{vl.COMPLETIONS}"],
                              capture_output=True, text=True, check=True).stdout
        for n, line in enumerate(blob.splitlines(), 1):
            if line.strip():
                json.loads(line)        # a torn line raises here, naming the commit below
    assert vl.history_fault(root, vl.COMPLETIONS) == ""
    rows = [json.loads(l) for l in (root / vl.COMPLETIONS).read_text().splitlines() if l.strip()]
    assert len(rows) == 4 * 60
