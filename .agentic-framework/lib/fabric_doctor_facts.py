#!/usr/bin/env python3
"""Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`.

T-3430. Extracted to a real file per L-332/L-408: a heredoc inside `$()` inside
bin/fw is the canonical self-lockout shape (the same reason lib/cron_dry_run.py
exists). Reads the JSON from FW_FAB_JSON rather than argv so a card location
containing a shell metacharacter never reaches a command line.

Prints: total<TAB>todo_purpose<TAB>unknown_subsystem<TAB>no_edges
With --offenders: a comma-joined list of the first few offender locations.
Exits 1 and prints nothing when the input is not parseable — doctor then stays
silent rather than reporting a count it did not compute.
"""

import json
import os
import sys


def main():
    raw = os.environ.get("FW_FAB_JSON", "")
    if not raw.strip():
        return 1
    try:
        data = json.loads(raw)
    except (ValueError, AttributeError):
        return 1
    if "--offenders" in sys.argv[1:]:
        print(", ".join(o.get("location", "")
                        for o in data.get("offenders", [])[:3]))
        return 0
    counts = data.get("counts", {})
    print("\t".join(str(counts.get(k, 0)) for k in
                    ("total", "todo_purpose", "unknown_subsystem", "no_edges")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
