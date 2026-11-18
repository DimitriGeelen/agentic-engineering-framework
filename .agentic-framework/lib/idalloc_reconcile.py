#!/usr/bin/env python3
"""Task-id reconciliation (T-5217, slice 1 of inception T-5212).

`fw task id reconcile [--heal] [--json]` compares the three records of which task ids
exist — the task files in every worktree view, the counter (<main>/.tasks/.id-highwater)
and the reservation ledger (<main>/.tasks/.id-ledger.jsonl, written by lib/idalloc.sh) —
and reports:

  ERROR  duplicate             one id carried by two different task files
  ERROR  file-above-counter    a task file in the main range above the counter
  ERROR  counter-below-ledger  the ledger reserved ids above the counter
  ERROR  overlapping-reservations  two reserve rows share ids
  ERROR  counter-missing       no counter file
  WARN   incomplete-reservation    reserved ids with neither a file nor a created row
  WARN   file-without-reservation  a task file above the adopt line that no reservation covers
  WARN   counter-above-ledger      the counter is above every reservation and file (unexplained gap)
  INFO   deleted-after-creation    a created row whose file is gone from every view
  INFO   quarantine-band           task files above the quarantine cliff (T-100202)

`--heal` only ever raises the counter: to the highest id the files (main range) and the
ledger account for, and appends a heal row. It never lowers it and never renames a file.

Usage: idalloc_reconcile.py --main-view DIR [--view DIR ...] [--gap N] [--heal] [--json]
Exit: 0 no ERROR (after healing, when --heal), 1 an ERROR remains, 2 usage.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time

_ID_RE = re.compile(r"^T-(\d+)")


def _read_counter(path):
    try:
        with open(path, encoding="utf-8") as fh:
            line = fh.readline().strip()
    except OSError:
        return None
    return int(line) if line.isdigit() else None


def _read_ledger(path):
    rows, bad = [], 0
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    bad += 1
                    continue
                if isinstance(row, dict):
                    rows.append(row)
    except OSError:
        pass
    return rows, bad


def _scan_files(views):
    """id -> {basename: [paths]} over active/ and completed/ of every view."""
    found = {}
    for view in views:
        for sub in ("active", "completed"):
            d = os.path.join(view, sub)
            try:
                names = os.listdir(d)
            except OSError:
                continue
            for name in names:
                if not name.endswith(".md"):
                    continue
                m = _ID_RE.match(name)
                if not m:
                    continue
                found.setdefault(int(m.group(1)), {}).setdefault(name, []).append(os.path.join(d, name))
    return found


def _ranges(ids):
    """Compress sorted ints into 'a-b' strings."""
    out, start, prev = [], None, -2
    for i in sorted(ids):
        if start is None:
            start = prev = i
        elif i == prev + 1:
            prev = i
        else:
            out.append(f"T-{start}" if start == prev else f"T-{start}..T-{prev}")
            start = prev = i
    if start is not None:
        out.append(f"T-{start}" if start == prev else f"T-{start}..T-{prev}")
    return out


def _main_cliff(points, gap):
    """Walk sorted (lo, hi) intervals from the bottom; return the main-range max."""
    m = None
    for lo, hi in sorted(points):
        if m is None:
            m = hi
        elif lo - m > gap:
            break
        elif hi > m:
            m = hi
    return m or 0


def analyse(main_view, views, gap):
    counter_path = os.path.join(main_view, ".id-highwater")
    ledger_path = os.path.join(main_view, ".id-ledger.jsonl")
    counter = _read_counter(counter_path)
    rows, bad_rows = _read_ledger(ledger_path)
    files = _scan_files(views)

    reserves = [r for r in rows if r.get("event") == "reserve"
                and isinstance(r.get("first"), int) and isinstance(r.get("last"), int)]
    created = {r["id"] for r in rows if r.get("event") == "created" and isinstance(r.get("id"), int)}
    adopt = max([r["last"] for r in rows if r.get("event") == "adopt" and isinstance(r.get("last"), int)],
                default=None)
    ledger_max = max([r["last"] for r in reserves] + ([adopt] if adopt is not None else []), default=0)

    points = [(i, i) for i in files] + [(r["first"], r["last"]) for r in reserves]
    if adopt is not None:
        points.append((adopt, adopt))
    main_max = _main_cliff(points, gap)
    main_ids = {i for i in files if i <= main_max}
    band = sorted(i for i in files if i > main_max)

    findings = []

    def add(level, code, message, ids=None):
        f = {"level": level, "code": code, "message": message}
        if ids:
            f["ids"] = _ranges(ids)
        findings.append(f)

    # ERRORs
    dups = sorted(i for i, names in files.items() if len(names) > 1)
    if dups:
        add("ERROR", "duplicate", f"{len(dups)} id(s) carried by more than one task file", dups)
    if counter is None:
        add("ERROR", "counter-missing", f"no counter at {counter_path}")
    else:
        above = sorted(i for i in main_ids if i > counter)
        if above:
            add("ERROR", "file-above-counter", f"{len(above)} task file id(s) above the counter ({counter})", above)
        if ledger_max > counter:
            add("ERROR", "counter-below-ledger", f"the ledger reserved up to {ledger_max}, the counter is {counter}")
    seq = sorted((r["first"], r["last"]) for r in reserves)
    overlaps = set()
    hi_seen = None
    for lo, hi in seq:
        if hi_seen is not None and lo <= hi_seen:
            overlaps.update(range(lo, min(hi, hi_seen) + 1))
        hi_seen = hi if hi_seen is None else max(hi_seen, hi)
    if overlaps:
        add("ERROR", "overlapping-reservations", f"{len(overlaps)} id(s) reserved more than once", overlaps)

    # WARNs
    incomplete = []
    for r in reserves:
        missing = [i for i in range(r["first"], r["last"] + 1) if i not in files and i not in created]
        if missing:
            incomplete.append({"purpose": r.get("purpose"), "reserved": _ranges(range(r["first"], r["last"] + 1)),
                               "missing": _ranges(missing), "ts": r.get("ts"), "pid": r.get("pid")})
    if incomplete:
        n = len(incomplete)
        f = {"level": "WARN", "code": "incomplete-reservation",
             "message": f"{n} reservation(s) with ids that have neither a file nor a created row",
             "reservations": incomplete}
        findings.append(f)
    reserved = set()
    for r in reserves:
        reserved.update(range(r["first"], r["last"] + 1))
    floor = adopt if adopt is not None else (None if not rows else 0)
    if floor is not None:
        unreserved = sorted(i for i in main_ids if i > floor and i not in reserved)
        if unreserved:
            add("WARN", "file-without-reservation",
                f"{len(unreserved)} task file id(s) above the adopt line ({floor}) with no reservation", unreserved)
    if counter is not None and rows and counter > max(ledger_max, max(main_ids, default=0)):
        add("WARN", "counter-above-ledger",
            f"the counter ({counter}) is above every reservation and task file ({max(ledger_max, max(main_ids, default=0))})")
    if bad_rows:
        add("WARN", "ledger-unparsable", f"{bad_rows} ledger line(s) are not JSON")

    # INFO
    deleted = sorted(i for i in created if i not in files)
    if deleted:
        add("INFO", "deleted-after-creation", f"{len(deleted)} created id(s) have no file in any view", deleted)
    if band:
        add("INFO", "quarantine-band",
            f"{len(band)} task file(s) above the quarantine cliff at {main_max} (gap > {gap})", band)

    target = max(main_max, ledger_max)
    return {
        "main_view": main_view,
        "views": list(views),
        "counter": counter,
        "ledger_max": ledger_max,
        "main_max": main_max,
        "adopt": adopt,
        "heal_target": target,
        "findings": findings,
    }


def heal(report):
    counter, target = report["counter"], report["heal_target"]
    if counter is not None and counter >= target:
        return None
    main_view = report["main_view"]
    path = os.path.join(main_view, ".id-highwater")
    ledger = os.path.join(main_view, ".id-ledger.jsonl")
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    row = {"event": "heal", "from": counter, "to": target, "reason": "reconcile", "by": "reconcile", "ts": ts}
    with open(ledger, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, separators=(",", ":")) + "\n")
    tmp = f"{path}.tmp.{os.getpid()}-{os.urandom(4).hex()}"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(f"{target}\n")
    os.replace(tmp, path)
    return row


def render(report, healed):
    out = []
    c = report["counter"]
    out.append(f"Task-id reconciliation — {report['main_view']}")
    out.append(f"  counter: {c if c is not None else 'missing'}   ledger max: {report['ledger_max']}   "
               f"main-range max: {report['main_max']}   views: {len(report['views'])}")
    if healed:
        out.append(f"  HEALED  counter {healed['from']} -> {healed['to']}")
    if not report["findings"]:
        out.append("  OK  no findings")
    for f in report["findings"]:
        line = f"  {f['level']:<5} {f['code']}: {f['message']}"
        if f.get("ids"):
            shown = f["ids"][:10]
            line += " — " + ", ".join(shown) + (" …" if len(f["ids"]) > 10 else "")
        out.append(line)
        for r in f.get("reservations", [])[:10]:
            out.append(f"          {', '.join(r['reserved'])} ({r.get('purpose')}, {r.get('ts')}): "
                       f"missing {', '.join(r['missing'][:5])}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="fw task id reconcile", description=(__doc__ or "").split("\n\n")[0])
    ap.add_argument("--main-view", required=True)
    ap.add_argument("--view", action="append", default=[])
    ap.add_argument("--gap", type=int, default=int(os.environ.get("FW_ID_QUARANTINE_GAP", "1000") or 1000))
    ap.add_argument("--heal", action="store_true")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    views = list(dict.fromkeys([a.main_view] + a.view))
    report = analyse(a.main_view, views, a.gap)
    healed = None
    if a.heal:
        healed = heal(report)
        if healed:
            report = analyse(a.main_view, views, a.gap)
    report["healed"] = healed
    if a.json:
        print(json.dumps(report, indent=2))
    else:
        print(render(report, healed))
    return 1 if any(f["level"] == "ERROR" for f in report["findings"]) else 0


if __name__ == "__main__":
    sys.exit(main())
