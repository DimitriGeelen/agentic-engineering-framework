"""T-1244: /approvals page uses shared task metadata cache instead of inline globbing.

Verifies that:
1. _load_pending_go_decisions filters via get_all_task_metadata cache (active+inception only)
2. _load_pending_human_acs filters via cache (active only)
3. Cache entries include _path so bodies can be re-read without re-glob
"""

import os
from pathlib import Path

# Force PROJECT_ROOT to framework repo before importing web modules
os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))


def test_task_cache_includes_path():
    """Cache entries must include _path key (T-1244 prerequisite)."""
    from web.shared import get_all_task_metadata

    tasks = get_all_task_metadata()
    assert tasks, "expected at least one task in cache"
    sample = tasks[0]
    assert "_path" in sample, f"_path missing from cache entry: {list(sample.keys())}"
    assert "_location" in sample
    assert Path(sample["_path"]).exists(), f"path does not exist: {sample['_path']}"


def test_pending_go_uses_cache_filter():
    """_load_pending_go_decisions should only return inception tasks from active/."""
    from web.blueprints.approvals import _load_pending_go_decisions

    results = _load_pending_go_decisions()
    # Each result must be an inception task that's still active and pending decision
    for r in results:
        task_id = r.get("task_id", "")
        assert task_id.startswith("T-"), f"unexpected task_id format: {task_id}"
        assert "name" in r and r["name"]
        assert "rec_decision" in r
        assert "go_nogo_criteria" in r
        # T-1537: verdict field surfaced for top-level badge parity with partial-completes
        assert "verdict" in r, f"verdict field missing from {task_id}"
        assert r["verdict"] in ("GO", "DEFER", "NO-GO", "?"), \
            f"unexpected verdict value for {task_id}: {r['verdict']!r}"


def test_pending_human_acs_uses_cache_filter():
    """_load_pending_human_acs should return active tasks with unchecked Human ACs."""
    from web.blueprints.approvals import _load_pending_human_acs

    results = _load_pending_human_acs()
    for r in results:
        assert "task_id" in r
        assert "human_acs" in r
        # At least one Human AC must be unchecked (else not in results)
        unchecked = [ac for ac in r["human_acs"] if not ac["checked"]]
        assert unchecked, f"task {r['task_id']} has no unchecked Human ACs but appeared in results"


def test_cache_filter_skips_completed_tasks():
    """Cache iteration must skip tasks in completed/ — only active/ should appear."""
    from web.blueprints.approvals import _load_pending_go_decisions, _load_pending_human_acs
    from web.shared import get_all_task_metadata

    all_tasks = get_all_task_metadata()
    completed_ids = {fm.get("id") for fm in all_tasks if fm.get("_location") == "completed"}

    go_results = _load_pending_go_decisions()
    ac_results = _load_pending_human_acs()

    for r in go_results:
        assert r["task_id"] not in completed_ids, f"completed task leaked into go list: {r['task_id']}"
    for r in ac_results:
        assert r["task_id"] not in completed_ids, f"completed task leaked into ac list: {r['task_id']}"
