"""T-3600: the dashboard tile reads counts-only, and one approvals build scans the corpus once.

1. Parity: `approval_summary()` and `_build_approvals_context()` produce the same
   four tile counts, because both go through `_approval_counts()`. Fixture corpus,
   with the per-criterion display parser made to raise, so the summary is shown not
   to render anything.
2. Bound: one `_build_approvals_context()` calls `get_all_task_metadata` at most 3
   times and never re-parses a task file through `arc_close_readiness._read_fm`
   (the per-arc-member and corpus-median re-scans that cost 15s cold here).
3. The dashboard tile does not build the page.
"""
import os
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web.app import app  # noqa: E402
import web.shared as shared  # noqa: E402
import web.blueprints.approvals as ap  # noqa: E402

NEEDS_REVIEW = """# T-9101: fixture

## Acceptance Criteria

### Agent
- [x] done

### Human
- [ ] [REVIEW] look at it
  **Steps:** 1. look
  **Expected:** fine
  **If not:** say so
"""

NO_HUMAN = """# T-9102: fixture

## Acceptance Criteria

### Agent
- [ ] not yet
"""

TICKED = """# T-9103: fixture

## Acceptance Criteria

### Human
- [x] [REVIEW] already looked
"""

BODIES = {"T-9101": NEEDS_REVIEW, "T-9102": NO_HUMAN, "T-9103": TICKED, "T-9104": NEEDS_REVIEW}


@pytest.fixture()
def fixture_corpus(monkeypatch):
    meta = [
        {"id": tid, "name": tid, "status": "work-completed", "workflow_type": "build",
         "_location": "active", "_path": f"/fixture/{tid}.md"}
        for tid in BODIES
    ]
    monkeypatch.setattr(ap, "get_all_task_metadata", lambda: meta)
    monkeypatch.setattr(ap, "_get_body_cached", lambda p: BODIES[Path(str(p)).stem])
    monkeypatch.setattr(ap, "_load_pending_approvals", lambda: [
        {"status": "pending", "command_preview": "x"},
        {"status": "pending", "command_preview": "y"},
        {"status": "approved", "command_preview": "z"},
    ])
    monkeypatch.setattr(ap, "_load_resolved_approvals", lambda: [])
    monkeypatch.setattr(ap, "_load_pending_go_decisions", lambda: [{"task_id": "T-9201"}])
    monkeypatch.setattr(ap, "_load_decided_unclosed", lambda: [{"task_id": "T-9202"}])
    monkeypatch.setattr(ap, "_count_deferred_inceptions", lambda: 0)
    monkeypatch.setattr(ap, "_load_paused_dispatches", lambda: [{"dispatch_id": "d1"}])
    # T-3782: the waiting-for-a-recipient section reads the live sidecar; pin it empty.
    monkeypatch.setattr(ap, "_load_waiting_messages",
                        lambda: {"items": [], "error": None, "warn_hours": 4.0})
    monkeypatch.setattr(ap, "_load_close_ready_arcs", lambda threshold=0.80: [{"slug": "a"}, {"slug": "b"}])
    import web.blueprints.bvp as bvp_bp
    monkeypatch.setattr(bvp_bp, "_load_proposals", lambda: [{"id": "p1"}, {"id": "p2"}, {"id": "p3"}])
    return meta


TILE_KEYS = ("total_count", "tier0_count", "go_count", "ac_task_count")


def test_summary_counts_equal_page_counts_on_fixture(fixture_corpus):
    with app.test_request_context("/"):
        ctx = ap._build_approvals_context()
        summary = ap.approval_summary()
    assert {k: summary[k] for k in TILE_KEYS} == {k: ctx[k] for k in TILE_KEYS}
    # 2 pending tier0 + 1 go + 2 AC tasks + 1 paused + 2 arcs + 3 bvp + 1 decided
    assert summary == {"total_count": 12, "tier0_count": 2, "go_count": 1, "ac_task_count": 2}


def test_summary_does_not_render_criteria(fixture_corpus, monkeypatch):
    import web.blueprints.tasks as tasks_bp

    def boom(*_a, **_k):
        raise AssertionError("approval_summary rendered per-criterion detail")

    monkeypatch.setattr(tasks_bp, "_parse_acceptance_criteria", boom)
    with app.test_request_context("/"):
        assert ap.approval_summary()["ac_task_count"] == 2


def test_one_build_scans_the_corpus_at_most_three_times(monkeypatch):
    lib_dir = str(Path(ap.__file__).resolve().parents[2] / "lib")
    import sys
    if lib_dir not in sys.path:
        sys.path.insert(0, lib_dir)
    import arc_close_readiness as acr

    calls = {"meta": 0, "read_fm": 0}
    real_meta = shared.get_all_task_metadata
    real_read_fm = acr._read_fm

    def counting_meta():
        calls["meta"] += 1
        return real_meta()

    def counting_read_fm(*a, **k):
        calls["read_fm"] += 1
        return real_read_fm(*a, **k)

    monkeypatch.setattr(shared, "get_all_task_metadata", counting_meta)
    monkeypatch.setattr(ap, "get_all_task_metadata", counting_meta)
    monkeypatch.setattr(acr, "_read_fm", counting_read_fm)
    monkeypatch.setattr(ap, "_READINESS_MEDIANS", {})  # cold: medians recomputed too
    monkeypatch.setattr(ap, "_arc_demo_state", lambda arc: {"state": "absent", "detail": "stub"})

    with app.test_request_context("/"):
        ap._build_approvals_context()
    assert calls["meta"] <= 3, calls
    assert calls["read_fm"] == 0, calls


def test_dashboard_tile_does_not_build_the_page(monkeypatch):
    import web.blueprints.core as core

    def boom(*_a, **_k):
        raise AssertionError("dashboard tile built the full approvals page")

    monkeypatch.setattr(ap, "_build_approvals_context", boom)
    monkeypatch.setattr(ap, "approval_summary", lambda: {
        "total_count": 5, "tier0_count": 1, "go_count": 2, "ac_task_count": 2})
    monkeypatch.setitem(core._qr_cache, "data", None)
    with app.test_request_context("/"):
        summary, _qr, _url = core._get_approval_qr()
    assert summary is not None and summary["total"] == 5 and summary["go"] == 2
