#!/usr/bin/env python3
"""T-4081 / G-114: find Watchtower decisions that no longer stand at HEAD.

Watchtower commits an operator decision through a scratch index (T-2708). Before
T-4081 it left the real index on the pre-decision blobs, so the next ordinary
commit wrote them back and reverted the decision in git while the working tree
kept it. This reads history only and writes nothing.

For each task, the LAST commit titled `T-NNN: inception decision ... (via
Watchtower)` within the window is taken, and only if its task file carries a
`**Decision**: GO|NO-GO|DEFER` line. The decision in force is the value recorded by
the NEWEST `T-NNN: inception decision` commit of either source (Watchtower or CLI),
so a later legitimate decision supersedes an earlier one. The task is reported by
name when the task file at HEAD carries a different value (a GO reverted to DEFER),
no decision block, or no file at all.

Usage: watchtower_decision_revert.py [--repo DIR] [--days N]
Exit: 0 none reverted, 2 one or more reverted, 3 git unreadable.
"""
import argparse
import os
import re
import subprocess
import sys

DECISION = re.compile(r"^\*\*Decision\*\*:\s*(NO-GO|GO|DEFER)\b", re.M | re.I)
SUBJECT = re.compile(r"^(T-\d+): inception decision\b.*\(via Watchtower\)\s*$")
ANY_DECISION = re.compile(r"^(T-\d+): inception decision\b")


def _git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or "git " + " ".join(args))
    return r.stdout


def _task_paths(repo, rev, tid):
    out = _git(repo, "ls-tree", "-r", "--name-only", rev, "--", ".tasks/active", ".tasks/completed")
    return [p for p in out.splitlines() if re.match(rf"\.tasks/(active|completed)/{re.escape(tid)}-[^/]*\.md$", p)]


def _value_at(repo, rev, tid):
    """The decision value (GO/NO-GO/DEFER) in the task file at `rev`, or None."""
    for p in _task_paths(repo, rev, tid):
        m = DECISION.search(_git(repo, "show", f"{rev}:{p}"))
        if m:
            return m.group(1).upper()
    return None


def find_reverted(repo, days=60):
    log = _git(repo, "log", f"--since={days}.days", "--reverse", "--format=%H%x09%s",
               "--grep=inception decision")
    last_wt = {}
    decisions = {}  # task -> every decision commit in the window, oldest first
    for line in log.splitlines():
        sha, _, subj = line.partition("\t")
        m = ANY_DECISION.match(subj)
        if not m:
            continue
        decisions.setdefault(m.group(1), []).append(sha)
        if SUBJECT.match(subj):
            last_wt[m.group(1)] = sha
    reverted = []
    for tid, sha in sorted(last_wt.items()):
        if _value_at(repo, sha, tid) is None:
            continue
        # the newest decision commit of either source is the one HEAD must still show
        valued = [(s, v) for s in decisions[tid] for v in [_value_at(repo, s, tid)] if v]
        latest_sha, latest = valued[-1]  # non-empty: the Watchtower commit above carries a value
        head_value = _value_at(repo, "HEAD", tid)
        if head_value == latest:
            continue
        if not _task_paths(repo, "HEAD", tid):
            why = "task file missing at HEAD"
        elif head_value is None:
            why = "no decision block at HEAD"
        else:
            why = f"decision at HEAD is {head_value}, decision commit recorded {latest}"
        reverted.append((tid, latest_sha[:9], why))
    return reverted


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=os.environ.get("PROJECT_ROOT", "."))
    ap.add_argument("--days", type=int, default=60)
    a = ap.parse_args()
    try:
        rev = find_reverted(a.repo, a.days)
    except Exception as e:
        print(f"ERROR: {e}")
        return 3
    for tid, sha, why in rev:
        print(f"REVERTED {tid} decision-commit={sha} {why}")
    print(f"{len(rev)} Watchtower decision(s) no longer at HEAD (last {a.days} days)")
    return 2 if rev else 0


if __name__ == "__main__":
    sys.exit(main())
