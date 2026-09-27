"""T-3523: an operator's adjustment survives the next scoring run.

Operator ruling D-661 leg 3. Two detection routes, neither requiring a tick:
provenance (`confirmed_via: human|watchtower`) and digest (values no longer match the
stamp written with them).

THE CONTROL THAT MATTERS is `test_a_fresh_agent_value_is_NOT_sticky`. A protection
mechanism that marks everything protected has failed into paralysis, and it looks
exactly like one that works — nothing gets overwritten either way. Every sticky
assertion below is paired with a non-sticky one over the same shape.

The second theme is the asymmetry: a MISSING stamp means unprotected, not protected.
Every score in the corpus predates this field, so "absent = sticky" would refuse the
whole corpus on the first run and read as a broken feature. This is the one place
where absence points permissive, and it is deliberate — contrast T-3068's
blast_radius, where absence scored CHEAPEST and therefore had to become None. The
rule is "unknown must never be silently favourable", not "unknown is always None".
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import bvp_sticky as st  # noqa: E402


SCORES = {"D1": 4, "D2": 3, "D3": 2, "D4": 1}


# ── route 1: provenance ─────────────────────────────────────────────────────


@pytest.mark.parametrize("via", ["human", "watchtower", "operator", "HUMAN", " Human "])
def test_operator_doors_are_sticky(via):
    s = st.sticky_state(SCORES, confirmed_via=via, stamped_digest=st.values_digest(SCORES))
    assert s["sticky"] is True
    assert s["route"] == "provenance"


def test_a_fresh_agent_value_is_NOT_sticky():
    """THE control. If this ever goes sticky, the mechanism protects everything,
    which is indistinguishable from working and stops all re-scoring."""
    s = st.sticky_state(SCORES, confirmed_via="agent",
                        stamped_digest=st.values_digest(SCORES))
    assert s["sticky"] is False
    assert s["route"] == "none"


# ── route 2: digest ─────────────────────────────────────────────────────────


def test_hand_edited_values_are_sticky_even_when_via_says_agent():
    # The operator edits the file directly: confirmed_via still says `agent` because
    # no verb ran, so ONLY the digest can catch this.
    edited = dict(SCORES, D1=5)
    s = st.sticky_state(edited, confirmed_via="agent",
                        stamped_digest=st.values_digest(SCORES))
    assert s["sticky"] is True
    assert s["route"] == "digest"
    assert "outside the verb" in s["reason"]


def test_key_order_does_not_fake_an_edit():
    # A false "the operator touched this" would block legitimate re-scoring forever,
    # which is the failure that gets the whole mechanism switched off.
    reordered = {"D4": 1, "D2": 3, "D1": 4, "D3": 2}
    s = st.sticky_state(reordered, confirmed_via="agent",
                        stamped_digest=st.values_digest(SCORES))
    assert s["sticky"] is False


def test_digest_is_stable_across_equal_maps():
    assert st.values_digest(SCORES) == st.values_digest(dict(reversed(list(SCORES.items()))))


def test_digest_changes_when_a_value_changes():
    assert st.values_digest(SCORES) != st.values_digest(dict(SCORES, D2=4))


# ── the asymmetry: missing stamp is NOT protection ──────────────────────────


def test_missing_stamp_is_unprotected_not_sticky():
    s = st.sticky_state(SCORES, confirmed_via="agent", stamped_digest=None)
    assert s["sticky"] is False
    assert "predates" in s["reason"]


def test_missing_stamp_still_yields_to_provenance():
    # Absence of a digest must not override an explicit operator door.
    s = st.sticky_state(SCORES, confirmed_via="human", stamped_digest=None)
    assert s["sticky"] is True
    assert s["route"] == "provenance"


def test_empty_values_are_not_sticky():
    for empty in ({}, [], None):
        assert st.sticky_state(empty, confirmed_via="human")["sticky"] is False


# ── arc scoped-driver weights, per the ruling ───────────────────────────────


DRIVERS = [{"name": "determinism", "weight": 5}, {"name": "replay-fidelity", "weight": 4}]


def test_arc_driver_weights_are_covered():
    """Operator: 'it also covers ArcScope drivers, absolutely.' Same predicate over a
    list of driver dicts rather than a score map."""
    stamped = st.values_digest(DRIVERS)
    assert st.sticky_state(DRIVERS, "agent", stamped)["sticky"] is False
    bumped = [dict(DRIVERS[0], weight=6), DRIVERS[1]]
    s = st.sticky_state(bumped, "agent", stamped)
    assert s["sticky"] is True
    assert s["route"] == "digest"


def test_arc_driver_key_order_does_not_fake_an_edit():
    shuffled = [{"weight": 5, "name": "determinism"}, {"weight": 4, "name": "replay-fidelity"}]
    assert st.sticky_state(shuffled, "agent", st.values_digest(DRIVERS))["sticky"] is False


# ── skip AND report ─────────────────────────────────────────────────────────


def test_skip_line_names_subject_field_and_route():
    s = st.sticky_state(SCORES, confirmed_via="human")
    line = st.format_skip("T-1234", "bvp_scores", s)
    assert "T-1234" in line and "bvp_scores" in line
    assert "provenance" in line
    assert "SKIPPED" in line


def test_summary_reports_zero_skips_too():
    """L-575: printing nothing when skipped==0 makes 'protected nothing' and
    'protected silently' look identical. Never print a verdict without its
    denominator."""
    out = st.format_summary(0, 12)
    assert "0 skipped" in out
    assert "12 value(s) written" in out


def test_stamp_round_trips_into_a_non_sticky_state():
    stamped = st.stamp(SCORES)
    assert stamped["by"] == "agent"
    s = st.sticky_state(SCORES, confirmed_via="agent", stamped_digest=stamped["digest"])
    assert s["sticky"] is False
