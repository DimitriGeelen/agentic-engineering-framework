"""T-2335: /approvals surfaces the BVP driver propose-queue as an approval category.

Origin: operator caught a cross-surface visibility gap (2026-06-11) — pending BVP
driver proposals (T-2331 write → T-2332 /bvp read surface) had no ambient signal;
the agent had to *tell* the operator to "go look at /bvp". This section mirrors the
queue onto the unified /approvals centre, following the Arc-Closure pattern (T-1961).

Drives the *real* approvals route with a stubbed `_load_bvp_proposals` returning a
controlled list, then asserts the section + summary chip + per-proposal rows render
and that the proposals are counted into the page total. No live server, no live-queue
pollution — Flask test client + monkeypatched loaders (mirrors test_approvals_expand_overflow.py).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def _fake_proposals(n: int):
    """N pending proposal rows, shape per lib/bvp.sh _driver_propose."""
    out = []
    for i in range(n):
        out.append({
            "id": f"P-{i:08x}",
            "ts": "2026-06-26T00:00:00Z",
            "state": "pending",
            "name": f"fake-driver-{i}",
            "weight": 5,
            "rationale": f"rationale for driver {i}",
            "drop": None,
            "task": f"T-{8000 + i}",
            "author": "agent:tester",
        })
    return out


def _patch_loaders(monkeypatch, n_proposals: int):
    """Stub the other section loaders so only BVP Proposals renders."""
    from web.blueprints import approvals
    monkeypatch.setattr(approvals, "_load_pending_approvals", lambda: [])
    monkeypatch.setattr(approvals, "_load_resolved_approvals", lambda: [])
    monkeypatch.setattr(approvals, "_load_pending_go_decisions", lambda: [])
    monkeypatch.setattr(approvals, "_load_pending_human_acs", lambda: [])
    monkeypatch.setattr(approvals, "_count_deferred_inceptions", lambda: 0)
    monkeypatch.setattr(approvals, "_load_paused_dispatches", lambda: [])
    monkeypatch.setattr(approvals, "_load_close_ready_arcs", lambda _=0.80: [])
    monkeypatch.setattr(approvals, "_load_bvp_proposals", lambda: _fake_proposals(n_proposals))


def test_context_includes_bvp_proposals_and_count(monkeypatch):
    """_build_approvals_context surfaces the proposals + count + adds to total."""
    _patch_loaders(monkeypatch, n_proposals=3)
    from web.blueprints import approvals
    ctx = approvals._build_approvals_context()
    assert ctx["bvp_proposal_count"] == 3
    assert len(ctx["bvp_proposals"]) == 3
    # All other sections stubbed empty → total equals the proposal count.
    assert ctx["total_count"] == 3


def test_approvals_renders_bvp_section_heading(monkeypatch):
    """The BVP Driver Proposals h2 + section anchor render when proposals exist."""
    _patch_loaders(monkeypatch, n_proposals=2)
    html = _client().get("/approvals").get_data(as_text=True)
    assert 'id="section-bvp-proposals"' in html
    assert "BVP Driver Proposals" in html


def test_approvals_renders_summary_chip(monkeypatch):
    """Summary count strip includes a BVP Drivers chip pointing at the section."""
    _patch_loaders(monkeypatch, n_proposals=2)
    html = _client().get("/approvals").get_data(as_text=True)
    assert 'href="#section-bvp-proposals"' in html
    assert "BVP Drivers" in html


def test_approvals_renders_one_card_per_proposal(monkeypatch):
    """Each pending proposal renders one .bvp-proposal card with its name + weight."""
    _patch_loaders(monkeypatch, n_proposals=4)
    html = _client().get("/approvals").get_data(as_text=True)
    assert html.count('class="approval-card bvp-proposal"') == 4
    assert "fake-driver-0" in html
    assert "weight 5" in html
    # Each card links to /bvp where the operator approves/rejects (T-2332 surface).
    assert 'href="/bvp"' in html


def test_no_bvp_section_when_queue_empty(monkeypatch):
    """Zero pending proposals → no section, no summary chip (clean empty state)."""
    _patch_loaders(monkeypatch, n_proposals=0)
    html = _client().get("/approvals").get_data(as_text=True)
    assert 'id="section-bvp-proposals"' not in html
    assert 'href="#section-bvp-proposals"' not in html


def test_htmx_content_fragment_includes_bvp_section(monkeypatch):
    """The htmx polling fragment /approvals/content surfaces the section too."""
    _patch_loaders(monkeypatch, n_proposals=1)
    html = _client().get("/approvals/content").get_data(as_text=True)
    assert 'id="section-bvp-proposals"' in html


def test_load_bvp_proposals_degrades_to_empty_on_import_error(monkeypatch):
    """If the bvp blueprint/loader is unavailable, the helper returns [] not a 500."""
    from web.blueprints import approvals
    import builtins
    real_import = builtins.__import__

    def _boom(name, *a, **k):
        if name == "web.blueprints.bvp":
            raise ImportError("simulated missing blueprint")
        return real_import(name, *a, **k)

    monkeypatch.setattr(builtins, "__import__", _boom)
    assert approvals._load_bvp_proposals() == []
