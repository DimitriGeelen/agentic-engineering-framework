"""T-1934: pin the `_compute_cost(default_when_absent=...)` contract.

The proposed-mode fallback (default-medium) is load-bearing: without it
the scatter renders empty even when 60+ tasks carry proposed BVP
scores. Confirmed-mode must NOT receive the fallback — a missing
cost_estimate on a confirmed entity is a real data gap, not a default.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.blueprints import bvp


def test_compute_cost_three_component_takes_precedence_over_default():
    ce = {"blast_radius": 5, "tier": 3, "effort": 2}
    cost, br, tier, effort, src = bvp._compute_cost(ce, default_when_absent=True)
    assert src == "three-component"
    assert cost == 0.6 * 5 + 0.3 * 3 + 0.1 * 2
    assert (br, tier, effort) == (5.0, 3.0, 2.0)


def test_compute_cost_tshirt_takes_precedence_over_default():
    cost, br, tier, effort, src = bvp._compute_cost({"size": "L"}, default_when_absent=True)
    assert src == "tshirt"
    assert cost == 6.0
    assert (br, tier, effort) == (None, None, None)


def test_compute_cost_absent_returns_none_when_default_disabled():
    """Confirmed-mode (default_when_absent=False) honours absent-as-absent."""
    cost, br, tier, effort, src = bvp._compute_cost(None, default_when_absent=False)
    assert (cost, br, tier, effort, src) == (None, None, None, None, "absent")
    cost, br, tier, effort, src = bvp._compute_cost({}, default_when_absent=False)
    assert (cost, br, tier, effort, src) == (None, None, None, None, "absent")


def test_compute_cost_absent_returns_default_medium_when_proposed_mode():
    """Proposed-mode (default_when_absent=True) falls back to T-shirt M."""
    cost, br, tier, effort, src = bvp._compute_cost(None, default_when_absent=True)
    assert src == "default-medium"
    assert cost == 4.0
    cost, br, tier, effort, src = bvp._compute_cost({}, default_when_absent=True)
    assert src == "default-medium"
    assert cost == 4.0


def test_compute_cost_default_off_by_default():
    """Back-compat: callers passing no flag get the original absent-as-absent
    semantics. Confirmed-only callers must continue to skip un-costed entities."""
    cost, br, tier, effort, src = bvp._compute_cost(None)
    assert (cost, src) == (None, "absent")
