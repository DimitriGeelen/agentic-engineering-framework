"""Unit tests for `discover_parametrized_routes()` (T-2088).

Pins the sampler's contract in isolation from Playwright + the live app:
- per_pattern_limit cap is honoured
- top-N is ordered by source-file byte size (proxy for rendered content size)
- empty-fixture safety (no .context/arcs or .tasks → returns [])
- task-id parsing handles the T-NNNN-slug.md filename shape

The Playwright guard in tests/playwright/test_all_routes_height.py consumes this
sampler — unit tests here keep the sampler correct without spinning up a browser.
"""
import importlib.util
import os
import tempfile

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _load_uxr():
    """Load agents/ux-review/ux-review.py by path (hyphenated module name)."""
    path = os.path.join(ROOT, "agents", "ux-review", "ux-review.py")
    spec = importlib.util.spec_from_file_location("uxr_t2088_unit", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def fake_project(tmp_path):
    """Build a minimal PROJECT_ROOT skeleton with arcs + tasks of varied sizes."""
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)

    # Arcs of different sizes — alpha=largest, charlie=smallest
    (tmp_path / ".context" / "arcs" / "alpha.yaml").write_text("x" * 5000)
    (tmp_path / ".context" / "arcs" / "bravo.yaml").write_text("x" * 3000)
    (tmp_path / ".context" / "arcs" / "charlie.yaml").write_text("x" * 1000)

    # Tasks — active T-1001 (largest), completed T-1002 (medium), active T-1003 (small)
    (tmp_path / ".tasks" / "active" / "T-1001-foo-bar.md").write_text(
        "---\nid: T-1001\nworkflow_type: build\n---\n" + ("body\n" * 800)
    )
    (tmp_path / ".tasks" / "completed" / "T-1002-baz.md").write_text(
        "---\nid: T-1002\nworkflow_type: build\n---\n" + ("body\n" * 400)
    )
    (tmp_path / ".tasks" / "active" / "T-1003-tiny.md").write_text(
        "---\nid: T-1003\nworkflow_type: build\n---\nbody\n"
    )

    # Inception task — active T-1004 (large), completed T-1005 (medium)
    (tmp_path / ".tasks" / "active" / "T-1004-grill.md").write_text(
        "---\nid: T-1004\nworkflow_type: inception\n---\n" + ("body\n" * 600)
    )
    (tmp_path / ".tasks" / "completed" / "T-1005-explore.md").write_text(
        "---\nid: T-1005\nworkflow_type: inception\n---\n" + ("body\n" * 200)
    )

    return tmp_path


def test_returns_all_patterns_when_fixtures_exist(fake_project):
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=5, project_root=str(fake_project))
    assert any(r.startswith("/arcs/") for r in routes), f"no /arcs/ routes: {routes}"
    assert any(r.startswith("/tasks/") for r in routes), f"no /tasks/ routes: {routes}"
    assert any(r.startswith("/review/") for r in routes), f"no /review/ routes: {routes}"
    assert any(r.startswith("/inception/") for r in routes), f"no /inception/ routes: {routes}"


def test_sorted_and_deduped(fake_project):
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=5, project_root=str(fake_project))
    assert routes == sorted(routes), "routes must be sorted"
    assert len(routes) == len(set(routes)), "routes must be deduped"


def test_per_pattern_limit_caps_arcs(fake_project):
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=2, project_root=str(fake_project))
    arc_routes = [r for r in routes if r.startswith("/arcs/")]
    assert len(arc_routes) == 2, f"expected 2 arc routes at limit=2, got {arc_routes}"


def test_top_n_by_size_picks_largest_first(fake_project):
    """At limit=1, the largest arc (alpha) must be the chosen sample."""
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=1, project_root=str(fake_project))
    arc_routes = [r for r in routes if r.startswith("/arcs/")]
    assert arc_routes == ["/arcs/alpha"], f"expected /arcs/alpha (largest), got {arc_routes}"


def test_tasks_top_n_picks_largest_first(fake_project):
    """At limit=1 for tasks, the largest task (T-1001, 800-line body) must be chosen."""
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=1, project_root=str(fake_project))
    task_routes = [r for r in routes if r.startswith("/tasks/")]
    assert task_routes == ["/tasks/T-1001"], f"expected /tasks/T-1001 (largest), got {task_routes}"


def test_inception_filter_excludes_non_inception_tasks(fake_project):
    """Only tasks with `workflow_type: inception` show up under /inception/."""
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=5, project_root=str(fake_project))
    inception_routes = [r for r in routes if r.startswith("/inception/")]
    # T-1004 (active) and T-1005 (completed) are inception; T-1001/1002/1003 are build.
    assert sorted(inception_routes) == ["/inception/T-1004", "/inception/T-1005"], (
        f"inception filter wrong: {inception_routes}"
    )


def test_review_route_is_active_only(fake_project):
    """/review/<id> is for in-flight work — completed tasks must not be sampled."""
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=5, project_root=str(fake_project))
    review_routes = [r for r in routes if r.startswith("/review/")]
    # T-1001, T-1003 active build; T-1004 active inception. T-1002, T-1005 are completed.
    for r in review_routes:
        assert "T-1002" not in r and "T-1005" not in r, (
            f"completed task leaked into /review/ sample: {r}"
        )


def test_empty_fixture_safety(tmp_path):
    """Missing .context/arcs and .tasks directories return [] without raising."""
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=5, project_root=str(tmp_path))
    assert routes == [], f"expected [] for empty fixture, got {routes}"


def test_per_pattern_limit_zero_returns_empty(fake_project):
    """A 0 limit silently returns [] — defensive against bad caller args."""
    routes = _load_uxr().discover_parametrized_routes(per_pattern_limit=0, project_root=str(fake_project))
    assert routes == [], f"expected [] for limit=0, got {routes}"
