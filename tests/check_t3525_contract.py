#!/usr/bin/env python3
"""T-3525: assert the verdict contract's one load-bearing property, from OUTSIDE pytest.

A non-green verdict with no guidance must be UNCONSTRUCTIBLE. The pytest suite asserts
this too, but a suite can be skipped, renamed, or deselected while staying green — so
the close gate runs this file directly and it fails loudly if the property is gone.

Exists as a file rather than a `python3 -c` one-liner because the P-011 verification
gate refuses a multi-line python body: it would be executed as bash, where `import` is
a screenshot tool (T-2990). The gate was right and this is its suggested route.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
import judge_verdict as jv  # noqa: E402

failures = []

for state in (jv.AMBER, jv.RED, jv.UNKNOWN):
    try:
        jv.verdict(state)
    except jv.VerdictError:
        pass
    else:
        failures.append(f"{state} was constructible with NO guidance — the contract is gone")

# Green must NOT require guidance, or the mechanism becomes a tax on every pass and
# gets switched off. The control leg.
try:
    jv.verdict(jv.GREEN)
except Exception as exc:  # noqa: BLE001
    failures.append(f"green required guidance ({exc}) — over-applied, not protection")

# Amber and red must differ in behaviour, or the third state is decoration.
if jv.may_proceed(jv.verdict(jv.AMBER, "g")) is not True:
    failures.append("amber did not permit proceeding")
if jv.may_proceed(jv.verdict(jv.RED, "g")) is not False:
    failures.append("red permitted proceeding")

# Closed work is never reviewable (D-662).
if jv.reviewable({"status": "work-completed"})[0] is not False:
    failures.append("closed work was reviewable")

if failures:
    for f in failures:
        print(f"FAIL: {f}", file=sys.stderr)
    raise SystemExit(1)

print("T-3525 contract holds: non-green requires guidance; amber != red; closed not reviewable")
