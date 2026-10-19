#!/usr/bin/env python3
"""T-3257 build-order gate: may real live-fire work proceed?

The rule this task was filed under is "G-097 is closed OR a workaround is
confirmed measured (not assumed)". The original in-task predicate stated that
disjunction in a comment and then tested only the first half, so it asserted
something stricter than the rule it cited — and G-097 being open with the
workaround measured is precisely the state the comment allowed and the code
refused.

It lives in a file rather than inline because P-011 runs verification ONE LINE
AT A TIME: a multi-line `python3 -c` body is not one command, and its lines 2+
get executed as shell. That is how 56MB of ImageMagick PostScript once landed in
this repo's root (T-2990) — `import yaml, sys` run as bash, where `import` is a
screenshot tool.

Exit 0 = proceed. Exit 1 = blocked.
"""

import os
import sys

import yaml

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def g097_closed() -> bool:
    path = os.path.join(REPO, ".context", "project", "concerns.yaml")
    with open(path) as fh:
        doc = yaml.safe_load(fh)
    entry = next((c for c in doc["concerns"] if c.get("id") == "G-097"), None)
    return bool(entry) and entry.get("status") not in ("open", None)


def workaround_measured() -> bool:
    """Both legs, deliberately.

    The probe file alone would pass on a repo where someone wrote a probe and
    never wired its finding in; the driver strings alone would pass on a repo
    where someone added a transport flag without ever measuring it. Requiring
    both means the claim "measured" is backed by the measurement AND by the
    thing it caused.
    """
    probe = os.path.exists(os.path.join(REPO, "tools", "t3250-transport-probe.sh"))
    with open(os.path.join(REPO, "agents", "context", "continuous-driver.sh")) as fh:
        driver = fh.read()
    return probe and "tmux send-keys" in driver and "termlink|tmux" in driver


def main() -> int:
    closed = g097_closed()
    measured = workaround_measured()
    print(f"G-097 closed={closed}  workaround measured={measured}")
    if closed or measured:
        return 0
    print("BLOCKED: G-097 is open and no measured workaround is present.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
