#!/usr/bin/env python3
"""T-3335 (arc-020 S8) live smoke: the claim mutex on a REAL termlink hub.

Two distinct candidates race one AEF election target through the live
TermlinkChannelClaimBackend (default invoke → the `termlink` binary). Proves
the F5 first-claim-wins mutex fires on real termlink — the substrate the full
G1 (distinct co-resident correspondents) + G3 (self-heal, message still lands)
arc-close demo builds on.

Prereq: a hub must be running (`termlink hub status`; else `termlink hub start`).
Run:    cd /opt/999-Agentic-Engineering-Framework && python3 tests/manual/s8_claim_smoke.py

Not a pytest (it needs a live hub) — it is the executable form of T-3335's
[REVIEW] Human AC. Exit 0 = mutex behaved; non-zero = investigate.
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_election import LOST, WON, TermlinkChannelClaimBackend, elect


def main() -> int:
    uniq = f"{os.getpid()}-{int(time.time())}"
    target = f"aef::host=smoke.local::project=/opt/smoke::@peer-{uniq}::"
    backend = TermlinkChannelClaimBackend("aef-elect-smoke")

    print(f"target: {target}")
    a = elect(target, f"cand-A-{uniq}", backend)
    b = elect(target, f"cand-B-{uniq}", backend)
    print(f"  A: role={a.role} candidate={a.candidate_id}")
    print(f"  B: role={b.role} candidate={b.candidate_id}")

    winners = [r for r in (a, b) if r.role == WON]
    losers = [r for r in (a, b) if r.role == LOST]
    ok = True

    if len(winners) != 1 or len(losers) != 1:
        print(f"FAIL: expected exactly 1 WON + 1 LOST, got "
              f"{len(winners)} WON / {len(losers)} LOST")
        ok = False
    else:
        won, lost = winners[0], losers[0]
        holder = (lost.holder or {}).get("holder")
        print(f"  WON  = {won.candidate_id}")
        print(f"  LOST = {lost.candidate_id}; holder named = {holder}")
        if holder != won.candidate_id:
            print(f"FAIL: LOST holder {holder!r} != winner {won.candidate_id!r}")
            ok = False
        won.release()
        c = elect(target, f"cand-C-{uniq}", backend)
        print(f"  after release → C: role={c.role} (expect {WON})")
        if c.role != WON:
            print("FAIL: slot did not reopen after release")
            ok = False
        else:
            print("released → re-electable")
            c.release()

    print("SMOKE PASS" if ok else "SMOKE FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
