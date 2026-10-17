#!/usr/bin/env python3
"""One shared budget ladder for the context gate (T-4226).

Operator ruling 2026-10-17. One spawn reserve R sets every band, and the
multipliers widen as the window grows:

    R = min(50K, max(20K, 20K + 0.05 * (W - 200K)))
    f = clamp((W - 200K) / 600K, 0, 1)
    free = W - used

    Stop  (critical)  free <= R
    Red   (urgent)    free <= (1.5 + 0.5 f) R
    Amber (warn)      free <= (2 + f) R
    Green (ok)        otherwise

The comparison is inclusive: a reading exactly at a threshold is in the
higher band, so the worked values hold (200K -> Amber 160K used, Red 170K,
Stop 180K). Thresholds are floored to whole tokens, so every band boundary
is an integer `used` count.

Used by agents/context/checkpoint.sh and agents/context/budget-gate.sh.
Those scripts never re-derive the formula; they read these numbers.

CLI (shell-sourceable, one KEY=VALUE per line):
    python3 -I lib/budget_ladder.py <CONTEXT_WINDOW>
    python3 -I lib/budget_ladder.py <CONTEXT_WINDOW> <used_tokens>   # adds LEVEL/FREE
"""
import sys
from fractions import Fraction
from math import floor

BASE = 200_000
RESERVE_FLOOR = 20_000
RESERVE_CAP = 50_000
RESERVE_SLOPE = Fraction(5, 100)
RAMP = 600_000


def ladder(window):
    """Return the band table for a context window of `window` tokens."""
    w = int(window)
    reserve = min(RESERVE_CAP, max(RESERVE_FLOOR, RESERVE_FLOOR + RESERVE_SLOPE * (w - BASE)))
    f = min(max(Fraction(w - BASE, RAMP), Fraction(0)), Fraction(1))
    stop_free = floor(reserve)
    red_free = floor((Fraction(3, 2) + f / 2) * reserve)
    amber_free = floor((2 + f) * reserve)
    return {
        "window": w,
        "reserve": floor(reserve),
        "f": f,
        "warn_used": w - amber_free,
        "urgent_used": w - red_free,
        "critical_used": w - stop_free,
    }


def level(table, used):
    """Level name for `used` tokens: ok | warn | urgent | critical."""
    if used >= table["critical_used"]:
        return "critical"
    if used >= table["urgent_used"]:
        return "urgent"
    if used >= table["warn_used"]:
        return "warn"
    return "ok"


def free_tokens(table, used):
    return table["window"] - used


def main(argv):
    if len(argv) not in (2, 3):
        print("usage: budget_ladder.py <CONTEXT_WINDOW> [used_tokens]", file=sys.stderr)
        return 64
    table = ladder(argv[1])
    print(f"CONTEXT_WINDOW={table['window']}")
    print(f"BUDGET_RESERVE={table['reserve']}")
    print(f"TOKEN_WARN={table['warn_used']}")
    print(f"TOKEN_URGENT={table['urgent_used']}")
    print(f"TOKEN_CRITICAL={table['critical_used']}")
    if len(argv) == 3:
        used = int(argv[2])
        print(f"LEVEL={level(table, used)}")
        print(f"FREE_TOKENS={free_tokens(table, used)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
