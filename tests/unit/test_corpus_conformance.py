"""T-2621: map-conformance rail — state-carrier collapse vs enforced transitions.

Pins the extraction convention (carriers terminate walks, same-state pairs
ignored, non-carrier nodes are pass-through) and both divergence directions.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_conformance as cc  # noqa: E402


def _spec(nodes, flows):
    return {
        "nodes": [
            {"id": nid, "meta": ({"state": st} if st else {})}
            for nid, st in nodes
        ],
        "flows": [
            {"id": f"f{i}", "from": a, "to": b} for i, (a, b) in enumerate(flows)
        ],
    }


# Mirrors the real lifecycle shape: carriers joined through gateways/services.
ALIGNED = _spec(
    nodes=[
        ("create", "captured"),
        ("parked", "captured"),
        ("gw_ready", None),
        ("start", "started-work"),
        ("work", "started-work"),
        ("gw_issues", None),
        ("heal", "issues"),
        ("archive", "work-completed"),
        ("shelve", "captured"),
    ],
    flows=[
        ("create", "gw_ready"),
        ("gw_ready", "start"),
        ("gw_ready", "parked"),
        ("parked", "start"),
        ("start", "work"),
        ("work", "gw_issues"),
        ("gw_issues", "heal"),
        ("heal", "work"),
        ("heal", "archive"),      # issues -> work-completed
        ("gw_issues", "archive"),  # started-work -> work-completed
        ("work", "shelve"),        # started-work -> captured
    ],
)

CANON = {
    ("captured", "started-work"),
    ("started-work", "captured"),
    ("started-work", "issues"),
    ("started-work", "work-completed"),
    ("issues", "started-work"),
    ("issues", "work-completed"),
}


def test_aligned_map_asserts_exactly_the_canonical_set():
    assert cc.asserted_transitions(ALIGNED) == CANON


def test_walks_terminate_at_carriers_and_ignore_same_state_pairs():
    asserted = cc.asserted_transitions(ALIGNED)
    # parked->start is captured->started-work, never captured->captured
    assert ("captured", "captured") not in asserted
    # create cannot see work-completed: every path passes through a carrier first
    assert ("captured", "work-completed") not in asserted


def test_map_asserting_refused_transition_diverges():
    spec = _spec(
        nodes=[("archive", "work-completed"), ("create", "captured")],
        flows=[("archive", "create")],  # work-completed -> captured: refused
    )
    asserted = cc.asserted_transitions(spec)
    assert ("work-completed", "captured") in asserted - CANON


def test_map_lacking_allowed_transition_diverges():
    thin = _spec(
        nodes=[("create", "captured"), ("start", "started-work")],
        flows=[("create", "start")],
    )
    missing = CANON - cc.asserted_transitions(thin)
    assert ("issues", "work-completed") in missing
    assert ("started-work", "captured") in missing


def test_zero_carriers_is_skip_not_divergence():
    bare = _spec(nodes=[("a", None), ("b", None)], flows=[("a", "b")])
    assert cc.carrier_count(bare) == 0
    assert cc.asserted_transitions(bare) == set()


def test_canonical_excludes_legacy(tmp_path):
    (tmp_path / "status-transitions.yaml").write_text(
        "transitions:\n"
        "  - {from: captured, to: started-work}\n"
        "  - {from: refined, to: started-work, legacy: true}\n"
    )
    assert cc.canonical_transitions(tmp_path, "status-transitions.yaml") == {
        ("captured", "started-work")
    }
