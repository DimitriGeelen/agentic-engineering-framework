#!/usr/bin/env python3
"""T-3338 (arc-020 S8): live wire-level smoke of the endpoint-probe.

Runs against a REAL termlink hub. Proves the probe distinguishes the three
outcomes that G3 self-heal rests on:

  live session   -> exists   (True)
  bogus session  -> absent   (False, definitive: the hub answered)
  unreachable    -> INDETERMINATE (raised, NOT reported as absent)

The third case is the whole point: a probe that returned False on an
unreachable world would tell the self-heal loop "give up" when the truth is
"try again" — that inversion is the D4-A death-test bug this seam prevents.

Usage:
    termlink hub status --json   # confirm a hub is running (else: hub start)
    python3 tests/manual/s8_probe_smoke.py
Exit 0 = all three outcomes observed as expected.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import AEFAddress
from lib.aef_resolve import ResolveIndeterminate, termlink_probe


def _first_live_session() -> str | None:
    out = subprocess.run(
        ["termlink", "list", "--json"], capture_output=True, text=True, timeout=20
    ).stdout
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    sessions = data if isinstance(data, list) else data.get("sessions", data.get("data", []))
    for s in sessions:
        sid = s.get("id") or s.get("name")
        if sid:
            return sid
    return None


def main() -> int:
    live = _first_live_session()
    if not live:
        print("SKIP: no live session found in `termlink list` — start one and re-run")
        return 2

    probe = termlink_probe()
    ok = True

    # 1. live session -> exists
    r = probe(AEFAddress(host=None, session=live))
    print(f"live session   {live!r:24} -> {'exists' if r else 'ABSENT'}  (want exists)")
    ok &= r is True

    # 2. bogus session -> definitively absent (hub answered "not found")
    r = probe(AEFAddress(host=None, session="tl-bogus-does-not-exist-xyz"))
    print(f"bogus session  {'tl-bogus-...xyz':24} -> {'EXISTS' if r else 'absent'}  (want absent)")
    ok &= r is False

    # 3. unreachable hub -> INDETERMINATE (raised), never a false-absence.
    #    An invoke that always fails models a hub that cannot be reached.
    def dead_invoke(args, *, timeout=8.0):
        raise RuntimeError("simulated: hub unreachable")

    dead_probe = termlink_probe(invoke=dead_invoke)
    try:
        dead_probe(AEFAddress(host=None, session=live))
        print("unreachable    (dead invoke)             -> RETURNED  (want INDETERMINATE)")
        ok = False
    except ResolveIndeterminate as exc:
        print(f"unreachable    (dead invoke)             -> INDETERMINATE (raised)  ✓  [{exc}]")

    print("\nRESULT:", "PASS ✓" if ok else "FAIL ✗")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
