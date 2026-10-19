#!/usr/bin/env python3
"""Stale-task count for `fw doctor`'s Task debt check (T-814).

T-4386: the check used to be a bash loop over .tasks/active/*.md that forked
grep|head|sed|tr and `date` for every file — ~4,600 processes and ~18 s of each
doctor run at 930 active tasks. This is the same predicate in one process.

T-4430: the loop (and its T-4386 port) stripped only double quotes, so a
SINGLE-quoted value ('2026-10-19T12:29:28Z') — the form 843 of 929 active tasks
carry — failed to parse and was skipped as if fresh. Now:
  * the value is `last_update:` in the frontmatter (first `---` block), read as
    a YAML scalar: quoted or unquoted, date-only or datetime, `Z` or offset;
  * it counts when its epoch is older than the cutoff;
  * a value that is missing or does not parse is never skipped silently: it
    counts as debt (an active task whose age cannot be shown is not fresh) and
    is listed on stderr as `unparsed: N`, so stdout stays the one integer the
    caller (bin/fw doctor) reads.

Usage: task_debt.py ACTIVE_DIR CUTOFF_EPOCH   → prints the stale count.
"""
import os
import sys
from datetime import date, datetime, time

try:
    import yaml
except ImportError:  # pragma: no cover - yaml is a framework dependency
    yaml = None

_KEY = "last_update:"


def last_update_value(path):
    """Raw scalar text after `last_update:` in the frontmatter, or None."""
    try:
        with open(path, errors="replace") as f:
            if f.readline().rstrip("\r\n") != "---":
                return None
            for line in f:
                line = line.rstrip("\r\n")
                if line == "---":
                    return None
                if line.startswith(_KEY):
                    return line[len(_KEY):].strip()
    except OSError:
        return None
    return None


def _scalar(value):
    if yaml is not None:
        try:
            return yaml.safe_load(value)
        except yaml.YAMLError:
            return None
    v = value.split(" #", 1)[0].strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        v = v[1:-1]
    return v


def to_epoch(value):
    """Epoch seconds, or None when missing/unparseable."""
    if not value:
        return None
    v = _scalar(value)
    if isinstance(v, str):
        try:
            v = datetime.fromisoformat(v.strip().replace("Z", "+00:00"))
        except ValueError:
            return None
    if isinstance(v, datetime):
        return int(v.timestamp())  # naive → local time, as `date -d` reads it
    if isinstance(v, date):
        return int(datetime.combine(v, time()).timestamp())
    return None


def scan(active_dir, cutoff_epoch):
    """(stale_count, unparsed_paths). Unparsed paths are included in the count."""
    n, unparsed = 0, []
    try:
        names = sorted(os.listdir(active_dir))
    except OSError:
        return 0, []
    for name in names:
        if not name.endswith(".md") or name.startswith("."):
            continue
        path = os.path.join(active_dir, name)
        if not os.path.isfile(path):
            continue
        epoch = to_epoch(last_update_value(path))
        if epoch is None:
            unparsed.append(name)
            n += 1
        elif epoch < cutoff_epoch:
            n += 1
    return n, unparsed


def stale_count(active_dir, cutoff_epoch):
    return scan(active_dir, cutoff_epoch)[0]


def main(argv):
    if len(argv) != 3:
        print("usage: task_debt.py ACTIVE_DIR CUTOFF_EPOCH", file=sys.stderr)
        return 2
    n, unparsed = scan(argv[1], int(argv[2]))
    print(n)
    if unparsed:
        print(f"unparsed: {len(unparsed)} ({', '.join(unparsed)})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
