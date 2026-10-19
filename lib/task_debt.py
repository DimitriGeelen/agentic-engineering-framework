#!/usr/bin/env python3
"""Stale-task count for `fw doctor`'s Task debt check (T-814).

T-4386: the check used to be a bash loop over .tasks/active/*.md that forked
grep|head|sed|tr and `date` for every file — ~4,600 processes and ~18 s of each
doctor run at 930 active tasks. This is the same predicate in one process.

Semantics are the loop's, kept exactly:
  * the value is the first line starting with `last_update:` (anywhere in the
    file, as `grep '^last_update:' | head -1` found it), with the key, the
    following spaces and every double quote removed;
  * it counts when it parses to an epoch > 0 that is older than the cutoff;
  * a value that does not parse is skipped. That includes a SINGLE-quoted value
    ('2026-10-19T12:29:28Z'), which `date -d` rejected — see
    docs/reports/T-4386-doctor-profile.md for why that is reported, not changed,
    here.

Usage: task_debt.py ACTIVE_DIR CUTOFF_EPOCH   → prints the stale count.
"""
import os
import re
import sys
from datetime import datetime

_KEY_RE = re.compile(r"^last_update: *")


def last_update_value(path):
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("last_update:"):
                    return _KEY_RE.sub("", line.rstrip("\n"), count=1).replace('"', "")
    except OSError:
        return None
    return None


def to_epoch(value):
    """Epoch seconds, or 0 when unparseable (the loop's `|| echo 0`)."""
    if not value:
        return 0
    try:
        dt = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        return 0
    return int(dt.timestamp())  # naive → local time, as `date -d` reads it


def stale_count(active_dir, cutoff_epoch):
    n = 0
    try:
        names = sorted(os.listdir(active_dir))
    except OSError:
        return 0
    for name in names:
        if not name.endswith(".md") or name.startswith("."):
            continue
        path = os.path.join(active_dir, name)
        if not os.path.isfile(path):
            continue
        epoch = to_epoch(last_update_value(path))
        if 0 < epoch < cutoff_epoch:
            n += 1
    return n


def main(argv):
    if len(argv) != 3:
        print("usage: task_debt.py ACTIVE_DIR CUTOFF_EPOCH", file=sys.stderr)
        return 2
    print(stale_count(argv[1], int(argv[2])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
