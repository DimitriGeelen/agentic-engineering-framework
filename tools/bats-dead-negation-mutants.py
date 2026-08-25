#!/usr/bin/env python3
"""T-3138 AC6: mutate the dead-negation lint, confirm its own suite goes red.

The usual control for a new check — "does it fail against pre-change code?" — is
degenerate here, because the lint is net-new: before this task the tool did not
exist, so every test fails trivially and the measurement says nothing about
whether the tests can tell a working lint from a broken one.

Mutation testing is the control that does say something. Each mutant below
disables exactly one behaviour the lint depends on. A mutant that SURVIVES (suite
stays green) marks an assertion nobody is really making.

That is not hypothetical here. M3 survived on the first run, which is the only
reason anyone looked at the here-string guard — and the guard turned out to be
genuinely wrong, matching `<<< hi` and swallowing the rest of the file as heredoc
data. A surviving mutant found a real defect in the lint that its own green
suite, its fixtures and a careful read of the regex had all missed.

The lint source is restored in a `finally` block. Run it on a clean tree: if the
process is killed mid-run the file is left mutated, and `git diff` is the fix.

Usage:  tools/bats-dead-negation-mutants.py [--json]
Exit 0 when every mutant is killed, 1 when any survives or an anchor is stale.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

LINT = Path("tools/bats-dead-negation-lint.py")
SUITE = "tests/lint/bats-dead-negation.bats"

# (name, anchor-in-source, replacement). Anchors are exact text: a stale anchor
# is reported as a failure, not skipped. A skipped mutant is an unmeasured one,
# and silently-unmeasured is the exact shape this whole task is about.
MUTANTS = [
    ("M1 position ignored — every `!` flagged",
     "if k == last or _top_level_or(s):", "if False:"),
    ("M2 heredoc bodies read as code",
     "    in_body: List[bool] = [False] * len(lines)",
     "    return [False] * len(lines)\n    in_body: List[bool] = [False] * len(lines)"),
    ("M3 here-string guard removed entirely",
     r'''re.compile(r"(?<!<)<<(?!<)-?\s*''', r'''re.compile(r"<<-?\s*'''),
    ("M3b here-string guard lookahead-only (the bug that shipped first)",
     r'''re.compile(r"(?<!<)<<(?!<)-?\s*''', r'''re.compile(r"<<(?!<)-?\s*'''),
    ("M4 ||-guarded negations treated as dead",
     "or _top_level_or(s)", "or False"),
    ("M5 ||-guard not quote-aware",
     '        elif c in "\\"\'":\n            q = c\n', ''),
    ("M6 line continuations not joined",
     "    lines = _join_continuations(raw, is_body)", "    lines = raw"),
    ("M7 empty scan reports success instead of refusing",
     "        return 2\n\n    dead", "        return 0\n\n    dead"),
]


def main() -> int:
    original = LINT.read_text()
    results = []
    try:
        for name, anchor, replacement in MUTANTS:
            if anchor not in original:
                results.append({"mutant": name, "killed": False,
                                "why": "anchor missing — mutant not applied"})
                continue
            LINT.write_text(original.replace(anchor, replacement, 1))
            proc = subprocess.run(["bats", SUITE], capture_output=True, text=True)
            red = [l.split(" ", 3)[-1].strip()
                   for l in proc.stdout.splitlines() if l.startswith("not ok")]
            results.append({"mutant": name, "killed": bool(red), "killed_by": red})
    finally:
        LINT.write_text(original)

    survived = [r for r in results if not r["killed"]]
    if "--json" in sys.argv:
        print(json.dumps({"killed": len(results) - len(survived),
                          "total": len(results), "results": results}, indent=2))
    else:
        for r in results:
            mark = "KILLED " if r["killed"] else "SURVIVED"
            print(f"{mark}  {r['mutant']}")
            for t in r.get("killed_by", [])[:3]:
                print(f"            by: {t[:70]}")
            if r.get("why"):
                print(f"            {r['why']}")
        print(f"\n{len(results) - len(survived)} of {len(results)} mutants killed")
    return 0 if not survived else 1


if __name__ == "__main__":
    sys.exit(main())
