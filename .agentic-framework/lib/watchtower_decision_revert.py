#!/usr/bin/env python3
"""T-4081 / G-114: find Watchtower decisions that no longer stand at HEAD.

Watchtower commits an operator decision through a scratch index (T-2708). Before
T-4081 it left the real index on the pre-decision blobs, so the next ordinary
commit wrote them back and reverted the decision in git while the working tree
kept it. This reads history only and writes nothing.

For each task, the LAST commit titled `T-NNN: inception decision ... (via
Watchtower)` within the window is taken. If the task file in that commit carries
a `**Decision**: GO|NO-GO|DEFER` line and the task file at HEAD does not (or has
no file at all), the task is reported by name.

Usage: watchtower_decision_revert.py [--repo DIR] [--days N]
Exit: 0 none reverted, 2 one or more reverted, 3 git unreadable.
"""
import argparse
import os
import re
import subprocess
import sys

DECISION = re.compile(r"^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b", re.M | re.I)
SUBJECT = re.compile(r"^(T-\d+): inception decision\b.*\(via Watchtower\)\s*$")


def _git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or "git " + " ".join(args))
    return r.stdout


def _task_paths(repo, rev, tid):
    out = _git(repo, "ls-tree", "-r", "--name-only", rev, "--", ".tasks/active", ".tasks/completed")
    return [p for p in out.splitlines() if re.match(rf"\.tasks/(active|completed)/{re.escape(tid)}-[^/]*\.md$", p)]


def find_reverted(repo, days=60):
    log = _git(repo, "log", f"--since={days}.days", "--reverse", "--format=%H%x09%s",
               "--grep=via Watchtower")
    last = {}
    for line in log.splitlines():
        sha, _, subj = line.partition("\t")
        m = SUBJECT.match(subj)
        if m:
            last[m.group(1)] = sha
    reverted = []
    for tid, sha in sorted(last.items()):
        committed = [p for p in _task_paths(repo, sha, tid)
                     if DECISION.search(_git(repo, "show", f"{sha}:{p}"))]
        if not committed:
            continue
        head = _task_paths(repo, "HEAD", tid)
        if any(DECISION.search(_git(repo, "show", f"HEAD:{p}")) for p in head):
            continue
        reverted.append((tid, sha[:9], "task file missing at HEAD" if not head
                         else "no decision block at HEAD"))
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
