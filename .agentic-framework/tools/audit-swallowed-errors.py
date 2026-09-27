#!/usr/bin/env python3
"""L-369 corpus audit: scan all task ## Verification blocks for swallowed-errors
findings using the reviewer's deterministic detector.

Usage:
  tools/audit-swallowed-errors.py                 # list findings
  tools/audit-swallowed-errors.py --max N         # exit non-zero if findings > N
  tools/audit-swallowed-errors.py --min N         # exit non-zero if findings < N (regression guard)

Origin: T-1815 — pin reviewer precision after L-369 canonical-FP exemption.
The corpus baseline at exemption-time is 11 findings across 9 task files.
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from lib.reviewer.static_scan import detect_swallowed_errors  # noqa: E402

_VERIFICATION_RE = re.compile(
    r"^## Verification\s*\n(.+?)(?=^##\s|\Z)", re.MULTILINE | re.DOTALL
)


def scan() -> list[tuple[str, str, str]]:
    rows = []
    paths = sorted(
        glob.glob(os.path.join(ROOT, ".tasks/active/T-*.md"))
        + glob.glob(os.path.join(ROOT, ".tasks/completed/T-*.md"))
    )
    for path in paths:
        try:
            text = open(path).read()
        except OSError:
            continue
        m = _VERIFICATION_RE.search(text)
        if not m:
            continue
        for f in detect_swallowed_errors(m.group(1)):
            rows.append((os.path.relpath(path, ROOT), f.location, f.evidence[:120]))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--max", type=int, default=None, help="fail if findings > N")
    ap.add_argument("--min", type=int, default=None, help="fail if findings < N (regression guard)")
    args = ap.parse_args()

    rows = scan()
    for path, loc, evidence in rows:
        print(f"{path}: {loc}: {evidence}")
    print(f"# total findings: {len(rows)}")

    if args.max is not None and len(rows) > args.max:
        print(f"FAIL: {len(rows)} findings exceeds --max {args.max}", file=sys.stderr)
        return 1
    if args.min is not None and len(rows) < args.min:
        print(
            f"FAIL: {len(rows)} findings below --min {args.min} — known TP regressed?",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
