"""T-1796 — /orchestrator surfaces outcome quality (verification pass/fail).

Pins both the pure helper `_outcome_quality()` and the rendered HTML
for the new panel. CLI parity with `fw orchestrator status --outcomes`
(T-1749) verification-style aggregation, T-1757 dedup, T-1712 synthetic
exclusion.
"""

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def client(tmp_path, monkeypatch):
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".context" / "audits").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")

    runtime = tmp_path / "tlrun"
    runtime.mkdir()

    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(runtime))

    import importlib
    import web.shared
    import web.blueprints.orchestrator
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.orchestrator)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c, tmp_path


def _seed_jsonl(tmp_path: Path, fname: str, rows: list[dict]):
    path = tmp_path / ".context" / fname
    path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")


# ─── Pure function: _outcome_quality ──────────────────────────────────────


def test_outcome_quality_unavailable_when_no_outcomes_file(client):
    c, _ = client
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    assert out["available"] is False
    assert out["total_outcomes"] == 0
    assert out["by_task_type"] == []


def test_outcome_quality_aggregates_pass_fail_per_task_type(client):
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build"},
        {"dispatch_id": "b", "task_id": "T-2", "task_type": "build"},
        {"dispatch_id": "c", "task_id": "T-3", "task_type": "design"},
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
        {"dispatch_id": "b", "ts": "2026-05-01", "outcome": {"verification_passed": False}},
        {"dispatch_id": "c", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
    ])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    assert out["available"] is True
    assert out["total_outcomes"] == 3
    rows = {r["task_type"]: r for r in out["by_task_type"]}
    assert rows["build"]["passed"] == 1
    assert rows["build"]["failed"] == 1
    assert rows["build"]["pass_rate"] == 0.5
    assert rows["design"]["passed"] == 1
    assert rows["design"]["failed"] == 0
    assert rows["design"]["pass_rate"] == 1.0


def test_outcome_quality_dedupes_by_dispatch_id_latest_wins(client):
    """Two outcomes for the same dispatch: latest ts supersedes."""
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build"},
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verification_passed": False}},
        {"dispatch_id": "a", "ts": "2026-05-05", "outcome": {"verification_passed": True}},
    ])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    # Latest outcome wins → passed=1, failed=0.
    assert out["total_outcomes"] == 1
    rows = {r["task_type"]: r for r in out["by_task_type"]}
    assert rows["build"]["passed"] == 1
    assert rows["build"]["failed"] == 0


def test_outcome_quality_excludes_synthetic_dispatches(client):
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build"},
        {"dispatch_id": "b", "task_id": "T-stress-0", "task_type": "build"},
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
        {"dispatch_id": "b", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
    ])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    # Synthetic outcome ignored.
    assert out["total_outcomes"] == 1


def test_outcome_quality_skips_outcomes_with_no_matching_dispatch(client):
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build"},
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
        {"dispatch_id": "orphan-xyz", "ts": "2026-05-01", "outcome": {"verification_passed": False}},
    ])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    assert out["total_outcomes"] == 1


def test_outcome_quality_sorted_total_desc(client):
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": f"x{i}", "task_id": f"T-{i}", "task_type": "build"}
        for i in range(5)
    ] + [
        {"dispatch_id": f"y{i}", "task_id": f"T-{i + 100}", "task_type": "design"}
        for i in range(2)
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl",
                [{"dispatch_id": f"x{i}", "ts": "2026-05-01",
                  "outcome": {"verification_passed": True}} for i in range(5)]
                + [{"dispatch_id": f"y{i}", "ts": "2026-05-01",
                    "outcome": {"verification_passed": True}} for i in range(2)])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    totals = [r["total"] for r in out["by_task_type"]]
    assert totals == sorted(totals, reverse=True)
    assert out["by_task_type"][0]["task_type"] == "build"
    assert out["by_task_type"][-1]["task_type"] == "design"


def test_outcome_quality_verdict_style_counts_but_not_pass_fail(client):
    """Verdict-style outcomes (no verification_passed) count toward total
    but not pass/fail buckets."""
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "escalation-triage"},
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verdict": "HONORED"}},
    ])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    assert out["total_outcomes"] == 1
    row = out["by_task_type"][0]
    assert row["passed"] == 0
    assert row["failed"] == 0
    assert row["total"] == 1
    # pass_rate is 0.0 when no decided outcome — template shows "—" via gating.
    assert row["pass_rate"] == 0.0


def test_outcome_quality_graceful_on_missing_dispatches_file(client):
    """outcomes.jsonl present but dispatches.jsonl missing → no joins possible."""
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
    ])
    from web.blueprints.orchestrator import _outcome_quality
    out = _outcome_quality()
    assert out["available"] is True
    assert out["total_outcomes"] == 0


# ─── Route-level: GET /orchestrator renders the panel ────────────────────────


def test_orchestrator_page_renders_outcome_quality_panel(client):
    c, tmp_path = client
    _seed_jsonl(tmp_path, "dispatches.jsonl", [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build"},
    ])
    _seed_jsonl(tmp_path, "dispatch-outcomes.jsonl", [
        {"dispatch_id": "a", "ts": "2026-05-01", "outcome": {"verification_passed": True}},
    ])
    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "Outcome quality" in html
    assert "Pass rate" in html
    assert "build" in html


def test_orchestrator_page_shows_outcome_empty_state(client):
    c, _ = client
    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "Outcome quality" in html
    assert "no outcomes" in html
