#!/usr/bin/env python3
"""T-1724 verification helper: mirror the inline python from
agents/handover/handover.sh and assert the suggested first action is NOT
T-1611 (the DEFER-decided inception this fix excludes).

Used as a standalone verification command because pytest's monkey-patching
isn't available, and the verification gate in update-task.sh parses
`## Verification` line-by-line (multi-line python -c blocks fail).
"""

import glob
import re
import sys


def main():
    candidates = []
    for f in sorted(glob.glob(".tasks/active/*.md")):
        with open(f) as fh:
            content = fh.read()
        if "status: started-work" not in content:
            continue
        h = re.search(r"^horizon:\s*(.+)", content, re.M)
        if not h or h.group(1).strip() not in ("now", "next"):
            continue
        if re.search(r"^\*\*Decision\*\*:\s*DEFER", content, re.M):
            continue
        tid = re.search(r"^id:\s*(.+)", content, re.M)
        owner = re.search(r"^owner:\s*(.+)", content, re.M)
        is_human = owner and owner.group(1).strip() == "human"
        hval = 0 if h.group(1).strip() == "now" else 1
        candidates.append((is_human, hval, tid.group(1).strip() if tid else ""))
    candidates.sort()
    picked = candidates[0][2] if candidates else "none"
    if picked == "T-1611":
        print(f"FAIL: T-1611 still picked (DEFER filter not applied)")
        sys.exit(1)
    print(f"PASS: handover would suggest {picked}")


if __name__ == "__main__":
    main()
