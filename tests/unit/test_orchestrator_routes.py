"""T-1789: fw orchestrator routes — CLI mirror of web /orchestrator's
route-cache view.

Tests exercise the bin/fw subcommand directly (subprocess) so the bash
arg parsing + Python heredoc path is covered end-to-end.

Each test uses XDG_RUNTIME_DIR override to point the subcommand at a
tmp_path/termlink/route-cache.json — avoids touching real system path.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FW = REPO / "bin" / "fw"


def _run_routes(tmp_path: Path, *args: str) -> subprocess.CompletedProcess:
    """Run `bin/fw orchestrator routes` with XDG_RUNTIME_DIR=tmp_path so
    the subcommand reads tmp_path/termlink/route-cache.json."""
    env = os.environ.copy()
    env["XDG_RUNTIME_DIR"] = str(tmp_path)
    env["PROJECT_ROOT"] = str(tmp_path)
    return subprocess.run(
        [str(FW), "orchestrator", "routes", *args],
        capture_output=True,
        text=True,
        env=env,
    )


def _seed_cache(tmp_path: Path, model_stats: dict | None) -> Path:
    """Write a route-cache.json with the given model_stats. Returns path."""
    rt = tmp_path / "termlink"
    rt.mkdir(parents=True, exist_ok=True)
    cache_path = rt / "route-cache.json"
    payload = {"model_stats": model_stats} if model_stats is not None else {}
    cache_path.write_text(json.dumps(payload))
    return cache_path


# ---------------------------------------------------------------------------


def test_missing_cache_prints_friendly_notice(tmp_path):
    """No cache file → exit 0 + 'no route cache yet' (not a crash)."""
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "no route cache yet" in result.stdout
    assert "termlink/route-cache.json" in result.stdout


def test_empty_model_stats_prints_no_stats_notice(tmp_path):
    """File exists, model_stats absent/empty → distinct 'no model_stats yet'."""
    _seed_cache(tmp_path, {})
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "route cache has no model_stats yet" in result.stdout


def test_invalid_json_treated_as_unavailable(tmp_path):
    """Garbage in cache file → graceful 'no route cache yet', not a crash."""
    rt = tmp_path / "termlink"
    rt.mkdir(parents=True, exist_ok=True)
    (rt / "route-cache.json").write_text("not valid json {{{")
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "no route cache yet" in result.stdout


def test_valid_stats_render_per_task_type(tmp_path):
    """Two task_types, three models → per-task-type sections + leaderboard."""
    _seed_cache(tmp_path, {
        "haiku:build": {"model": "haiku", "task_type": "build",
                        "successes": 8, "failures": 2,
                        "last_used": "2026-05-03T00:00:00Z"},
        "opus:build": {"model": "opus", "task_type": "build",
                       "successes": 1, "failures": 3,
                       "last_used": "2026-05-02T00:00:00Z"},
        "sonnet:design": {"model": "sonnet", "task_type": "design",
                          "successes": 5, "failures": 0,
                          "last_used": "2026-05-02T00:00:00Z"},
    })
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert "task_type=build" in out
    assert "task_type=design" in out
    # haiku wins build (80%) over opus (25%) — best=haiku.
    assert "best=haiku" in out
    assert "best=sonnet" in out
    # Both candidates rendered for build.
    haiku_idx = out.index("haiku")
    opus_idx = out.index("opus")
    # Higher-rate candidate appears first.
    assert haiku_idx < opus_idx


def test_candidates_sorted_rate_desc_then_total_desc(tmp_path):
    """Tie in rate → higher total wins."""
    _seed_cache(tmp_path, {
        "a:t": {"model": "a", "task_type": "t",
                "successes": 10, "failures": 0,
                "last_used": "2026-05-01"},
        "b:t": {"model": "b", "task_type": "t",
                "successes": 5, "failures": 0,
                "last_used": "2026-05-01"},
        "c:t": {"model": "c", "task_type": "t",
                "successes": 3, "failures": 7,
                "last_used": "2026-05-01"},
    })
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    out = result.stdout
    # a (100% rate, total 10) > b (100% rate, total 5) > c (30%)
    assert out.index("\n  a ") < out.index("\n  b ")
    assert out.index("\n  b ") < out.index("\n  c ")


def test_zero_total_entries_skipped(tmp_path):
    """Entries with 0 successes AND 0 failures are not candidates (skipped)."""
    _seed_cache(tmp_path, {
        "a:t": {"model": "a", "task_type": "t",
                "successes": 0, "failures": 0,
                "last_used": "2026-05-01"},
    })
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    # 0/0 → no candidates → falls into "no model_stats yet" branch.
    assert "no model_stats yet" in result.stdout


def test_missing_model_or_task_type_skipped(tmp_path):
    """Malformed entries (no model or no task_type) are skipped."""
    _seed_cache(tmp_path, {
        "ok:t": {"model": "ok", "task_type": "t",
                 "successes": 1, "failures": 0,
                 "last_used": "2026-05-01"},
        "noModel:t": {"task_type": "t",
                      "successes": 5, "failures": 0,
                      "last_used": "2026-05-01"},
        "noTT": {"model": "x",
                 "successes": 5, "failures": 0,
                 "last_used": "2026-05-01"},
    })
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert "ok" in out
    assert "noModel" not in out
    assert "noTT" not in out


def test_last_used_surfaced(tmp_path):
    _seed_cache(tmp_path, {
        "a:t": {"model": "a", "task_type": "t",
                "successes": 1, "failures": 0,
                "last_used": "2026-05-01T12:34:56Z"},
    })
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "last_used=2026-05-01T12:34:56Z" in result.stdout


def test_json_mode_matches_web_shape(tmp_path):
    """--json output mirrors web _route_cache_learned shape."""
    _seed_cache(tmp_path, {
        "a:t": {"model": "a", "task_type": "t",
                "successes": 8, "failures": 2,
                "last_used": "2026-05-01"},
        "b:t": {"model": "b", "task_type": "t",
                "successes": 5, "failures": 0,
                "last_used": "2026-05-02"},
    })
    result = _run_routes(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["available"] is True
    assert "termlink/route-cache.json" in data["path"]
    assert data["total_stats"] == 2
    assert len(data["by_task_type"]) == 1
    row = data["by_task_type"][0]
    assert row["task_type"] == "t"
    # b has 100% rate vs a's 80% — b should win.
    assert row["best"]["model"] == "b"
    assert len(row["candidates"]) == 2
    # First candidate's rate >= second's.
    assert row["candidates"][0]["rate"] >= row["candidates"][1]["rate"]
    # rate field is normalised to 0..1 (not pct).
    for c in row["candidates"]:
        assert 0.0 <= c["rate"] <= 1.0


def test_json_unavailable_when_missing(tmp_path):
    """--json with no cache → valid JSON with available:false."""
    result = _run_routes(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["available"] is False
    assert data["by_task_type"] == []
    assert data["total_stats"] == 0


def test_task_types_sorted_alphabetically(tmp_path):
    """Multiple task_types → sorted alphabetically in output."""
    _seed_cache(tmp_path, {
        "a:zebra": {"model": "a", "task_type": "zebra",
                    "successes": 1, "failures": 0, "last_used": "2026"},
        "a:apple": {"model": "a", "task_type": "apple",
                    "successes": 1, "failures": 0, "last_used": "2026"},
        "a:middle": {"model": "a", "task_type": "middle",
                     "successes": 1, "failures": 0, "last_used": "2026"},
    })
    result = _run_routes(tmp_path)
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert out.index("task_type=apple") < out.index("task_type=middle")
    assert out.index("task_type=middle") < out.index("task_type=zebra")


# ---------------------------------------------------------------------------
# T-1790: --task-type X filter
# ---------------------------------------------------------------------------


def test_routes_task_type_filter_narrows_to_one_task_type(tmp_path):
    """--task-type build → only build's leaderboard rendered."""
    _seed_cache(tmp_path, {
        "haiku:build": {"model": "haiku", "task_type": "build",
                        "successes": 5, "failures": 1,
                        "last_used": "2026-05-01"},
        "sonnet:design": {"model": "sonnet", "task_type": "design",
                          "successes": 3, "failures": 0,
                          "last_used": "2026-05-01"},
    })
    result = _run_routes(tmp_path, "--task-type", "build")
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert "task_type=build" in out
    assert "task_type=design" not in out
    assert "haiku" in out
    assert "sonnet" not in out


def test_routes_task_type_filter_no_match_prints_notice(tmp_path):
    """--task-type with no matching entry → distinct notice."""
    _seed_cache(tmp_path, {
        "haiku:build": {"model": "haiku", "task_type": "build",
                        "successes": 5, "failures": 0,
                        "last_used": "2026"},
    })
    result = _run_routes(tmp_path, "--task-type", "missing")
    assert result.returncode == 0, result.stderr
    assert "no route cache entries for task_type missing" in result.stdout
    # Not the bare "no model_stats yet" notice — different code path.
    assert "no model_stats yet" not in result.stdout


def test_routes_task_type_filter_with_json(tmp_path):
    """--task-type --json → filtered list + accurate total_stats."""
    _seed_cache(tmp_path, {
        "haiku:build": {"model": "haiku", "task_type": "build",
                        "successes": 5, "failures": 1,
                        "last_used": "2026"},
        "opus:build": {"model": "opus", "task_type": "build",
                       "successes": 1, "failures": 3,
                       "last_used": "2026"},
        "sonnet:design": {"model": "sonnet", "task_type": "design",
                          "successes": 3, "failures": 0,
                          "last_used": "2026"},
    })
    result = _run_routes(tmp_path, "--task-type", "build", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["available"] is True
    # Only build entry retained — total_stats reflects filter.
    assert data["total_stats"] == 2
    assert len(data["by_task_type"]) == 1
    assert data["by_task_type"][0]["task_type"] == "build"


def test_routes_task_type_filter_no_match_json(tmp_path):
    """--task-type --json with no match → valid JSON (empty list)."""
    _seed_cache(tmp_path, {
        "haiku:build": {"model": "haiku", "task_type": "build",
                        "successes": 1, "failures": 0,
                        "last_used": "2026"},
    })
    result = _run_routes(tmp_path, "--task-type", "missing", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["available"] is True
    assert data["by_task_type"] == []
    assert data["total_stats"] == 0
