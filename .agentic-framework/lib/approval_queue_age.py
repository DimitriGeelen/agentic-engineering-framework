#!/usr/bin/env python3
"""Age of pending Tier 0 approval cards (T-3079).

A pending card (`.context/approvals/pending-*.yaml`, written by
agents/context/check-tier0.sh) is a request waiting on the operator. Before
T-3079 its only readers were pull surfaces (Watchtower /approvals,
`fw approvals pending`), so a card nobody opened sat for months. This is the
one predicate `fw doctor` and `fw audit` share to push it instead.

Usage:
    approval_queue_age.py stale <approvals_dir> <threshold_hours>

Prints one TSV row per pending card older than the threshold, oldest first:
    <file>\t<age_hours>\t<origin_kind>\t<command_preview>
A card whose YAML or timestamp cannot be read is reported (age from the
file's mtime, kind "unreadable"), never skipped: an unreadable card is still
sitting in the operator's queue.

Exit: 0 = ran (zero or more rows), 1 = no approvals directory, 2 = could not run.
"""
import os
import re
import sys
import time
from datetime import datetime


def _card_facts(path):
    """Return (timestamp_epoch_or_None, origin_kind, preview) for one card."""
    try:
        with open(path) as fh:
            raw = fh.read()
    except OSError:
        return None, "unreadable", ""
    data = None
    try:
        import yaml
        data = yaml.safe_load(raw)
    except Exception:
        data = None
    if not isinstance(data, dict):
        m = re.search(r"^timestamp:\s*['\"]?([^'\"\s]+)", raw, re.MULTILINE)
        ts = _parse_ts(m.group(1)) if m else None
        return ts, "unreadable", ""
    origin = data.get("origin")
    kind = str(origin.get("kind") or "unknown") if isinstance(origin, dict) else "unknown"
    preview = " ".join(str(data.get("command_preview") or "").split())[:60]
    ts = _parse_ts(data.get("timestamp"))
    if ts is None:
        kind = "unreadable"
    return ts, kind, preview


def _parse_ts(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def stale(approvals_dir, threshold_hours, now=None):
    now = time.time() if now is None else now
    rows = []
    for name in sorted(os.listdir(approvals_dir)):
        if not (name.startswith("pending-") and name.endswith(".yaml")):
            continue
        path = os.path.join(approvals_dir, name)
        if not os.path.isfile(path):
            continue
        ts, kind, preview = _card_facts(path)
        if ts is None:
            try:
                ts = os.path.getmtime(path)
            except OSError:
                ts = now
        age_h = max(0.0, (now - ts) / 3600.0)
        if age_h >= threshold_hours:
            rows.append((age_h, name, kind, preview))
    rows.sort(reverse=True)
    return [(name, f"{age:.1f}", kind, preview) for age, name, kind, preview in rows]


def main(argv):
    if len(argv) != 4 or argv[1] != "stale":
        print("usage: approval_queue_age.py stale <approvals_dir> <threshold_hours>", file=sys.stderr)
        return 2
    approvals_dir = argv[2]
    try:
        threshold = float(argv[3])
    except ValueError:
        print(f"threshold is not a number: {argv[3]!r}", file=sys.stderr)
        return 2
    if not os.path.isdir(approvals_dir):
        return 1
    try:
        rows = stale(approvals_dir, threshold)
    except OSError as exc:
        print(f"cannot read {approvals_dir}: {exc}", file=sys.stderr)
        return 2
    for row in rows:
        print("\t".join(c.replace("\t", " ") for c in row))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
