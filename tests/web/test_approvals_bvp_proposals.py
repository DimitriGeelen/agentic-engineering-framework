"""T-2335: /approvals — BVP Driver Proposals section (cross-surface visibility).

The /approvals review center must surface pending rows from
.context/bvp-driver-proposals.jsonl via the SAME reader the /bvp page uses
(web.blueprints.bvp._load_proposals), with Approve/Reject buttons proxying to
the T-2332 endpoints so the state machine + audit trail stay single-sourced.

Tests monkeypatch web.blueprints.bvp.PROPOSALS_PATH to a tmp JSONL so the
live proposals file is never read or polluted.
"""

import json

import pytest

import web.blueprints.bvp as bvp

PENDING_ROW = {
    "id": "P-deadbeef",
    "ts": "2026-07-21T10:00:00Z",
    "state": "pending",
    "name": "Test-Driver",
    "weight": 3,
    "rationale": "A thirty-plus character rationale distinguishing this driver from the global directives.",
    "task": "T-2335",
    "author": "agent:test",
}

APPROVED_ROW = {
    "id": "P-deadbeef",
    "ts": "2026-07-21T11:00:00Z",
    "state": "approved",
    "actor": "human:test",
}


@pytest.fixture()
def client(monkeypatch, tmp_path):
    proposals = tmp_path / "bvp-driver-proposals.jsonl"
    monkeypatch.setattr(bvp, "PROPOSALS_PATH", proposals)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), proposals


def _write_rows(path, rows):
    path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")


def test_context_includes_pending_proposals(client):
    """_build_approvals_context must expose bvp_proposals + count and fold
    the count into total_count."""
    c, proposals = client
    _write_rows(proposals, [PENDING_ROW])

    from web.blueprints.approvals import _build_approvals_context

    ctx = _build_approvals_context()
    assert "bvp_proposals" in ctx and "bvp_proposal_count" in ctx
    assert ctx["bvp_proposal_count"] == 1
    ids = [p.get("id") for p in ctx["bvp_proposals"]]
    assert "P-deadbeef" in ids
    # total_count includes the proposal — removing the row must lower it by 1.
    total_with = ctx["total_count"]
    proposals.unlink()
    ctx_without = _build_approvals_context()
    assert ctx_without["bvp_proposal_count"] == 0
    assert ctx_without["total_count"] == total_with - 1


def test_approvals_content_renders_section_and_buttons(client):
    """/approvals/content must render the section heading, the proposal card,
    and both Approve/Reject endpoint URLs (T-2332 proxy)."""
    c, proposals = client
    _write_rows(proposals, [PENDING_ROW])

    resp = c.get("/approvals/content")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert 'id="section-bvp-proposals"' in html
    assert "BVP Driver Proposals" in html
    assert "P-deadbeef" in html
    assert "Test-Driver" in html
    assert "/api/bvp/driver/approve?id=P-deadbeef" in html
    assert "/api/bvp/driver/reject?id=P-deadbeef" in html
    # Reject must carry the hx-prompt rationale contract (T-2332: ≥30 chars).
    assert "hx-prompt" in html


def test_decided_proposals_suppress_section(client):
    """A proposal whose last row is a decision (approved) is no longer pending
    — the section must be suppressed entirely."""
    c, proposals = client
    _write_rows(proposals, [PENDING_ROW, APPROVED_ROW])

    resp = c.get("/approvals/content")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert 'id="section-bvp-proposals"' not in html
    assert "P-deadbeef" not in html
