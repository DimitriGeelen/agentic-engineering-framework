"""T-1669 Step 1 — framework dispatch consults route_cache for model selection.

Pins `_resolve_dispatch_model_and_fallback` and `_route_cache_query_best_model`
in `agents/termlink/termlink.sh`. Pre-T-1669 the framework did env-var
lookup only; T-1669 inserts route_cache consultation BEFORE env-var fallback.

Cache schema mirrors /opt/termlink RouteCache JSON serialization
(crates/termlink-hub/src/route_cache.rs).
"""

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TERMLINK_SH = REPO_ROOT / "agents" / "termlink" / "termlink.sh"


def _bash_eval(snippet, runtime_dir, env_extra=None):
    """Source termlink.sh in a subshell and run snippet, return stdout."""
    env = os.environ.copy()
    env["TERMLINK_RUNTIME_DIR"] = str(runtime_dir)
    if env_extra:
        env.update(env_extra)
    full = (
        # Shim the funcs that the lib pulls in; we only need the dispatch helpers.
        f'source "{TERMLINK_SH}" 2>/dev/null\n'
        f'{snippet}\n'
    )
    r = subprocess.run(
        ["bash", "-c", full], env=env, capture_output=True, text=True
    )
    return r.stdout.rstrip("\n"), r.returncode, r.stderr


@pytest.fixture
def cache_dir(tmp_path):
    d = tmp_path / "tlrun"
    d.mkdir()
    return d


def _seed_cache(cache_dir, model_stats):
    cache = {"entries": {}, "model_stats": model_stats}
    (cache_dir / "route-cache.json").write_text(json.dumps(cache))


# ─── _route_cache_query_best_model ──────────────────────────────────────────

def test_query_best_model_picks_highest_success_rate(cache_dir):
    _seed_cache(cache_dir, {
        "haiku:build":  {"model":"haiku","task_type":"build","successes":8,"failures":2,"last_used":"2026-05-02T08:00:00Z"},
        "sonnet:build": {"model":"sonnet","task_type":"build","successes":3,"failures":7,"last_used":"2026-05-02T08:00:00Z"},
    })
    out, _, _ = _bash_eval('_route_cache_query_best_model build', cache_dir)
    assert out == "haiku"


def test_query_best_model_returns_empty_when_no_stat_for_task_type(cache_dir):
    _seed_cache(cache_dir, {
        "opus:design": {"model":"opus","task_type":"design","successes":5,"failures":0,"last_used":"2026-05-02T08:00:00Z"},
    })
    out, _, _ = _bash_eval('_route_cache_query_best_model build', cache_dir)
    assert out == ""


def test_query_best_model_returns_empty_when_cache_missing(tmp_path):
    out, _, _ = _bash_eval('_route_cache_query_best_model build', tmp_path)
    assert out == ""


def test_query_best_model_returns_empty_when_zero_total(cache_dir):
    """Stat exists but successes+failures == 0 → not a real signal."""
    _seed_cache(cache_dir, {
        "haiku:build": {"model":"haiku","task_type":"build","successes":0,"failures":0,"last_used":"2026-05-02T08:00:00Z"},
    })
    out, _, _ = _bash_eval('_route_cache_query_best_model build', cache_dir)
    assert out == ""


def test_query_best_model_handles_corrupt_cache_gracefully(cache_dir):
    (cache_dir / "route-cache.json").write_text("not json {")
    out, _, _ = _bash_eval('_route_cache_query_best_model build', cache_dir)
    assert out == ""


# ─── _resolve_dispatch_model_and_fallback ───────────────────────────────────

def test_resolve_explicit_model_short_circuits(cache_dir):
    _seed_cache(cache_dir, {
        "haiku:build": {"model":"haiku","task_type":"build","successes":8,"failures":2,"last_used":"2026-05-02T08:00:00Z"},
    })
    out, _, _ = _bash_eval('_resolve_dispatch_model_and_fallback opus build', cache_dir)
    assert out == "opus|false|explicit"


def test_resolve_route_cache_hit_takes_precedence_over_env(cache_dir):
    _seed_cache(cache_dir, {
        "haiku:build":  {"model":"haiku","task_type":"build","successes":8,"failures":2,"last_used":"2026-05-02T08:00:00Z"},
        "sonnet:build": {"model":"sonnet","task_type":"build","successes":3,"failures":7,"last_used":"2026-05-02T08:00:00Z"},
    })
    out, _, _ = _bash_eval(
        '_resolve_dispatch_model_and_fallback "" build', cache_dir,
        env_extra={"FW_DISPATCH_MODEL_FOR_BUILD": "fallback-pinned"},
    )
    # Cache hit MUST win even when env-per-type also pins a value.
    assert out == "haiku|true|route_cache"


def test_resolve_falls_back_to_env_per_type_on_cache_miss(cache_dir):
    out, _, _ = _bash_eval(
        '_resolve_dispatch_model_and_fallback "" build', cache_dir,
        env_extra={"FW_DISPATCH_MODEL_FOR_BUILD": "haiku"},
    )
    assert out == "haiku|true|env-per-type"


def test_resolve_falls_back_to_env_default_when_no_per_type(cache_dir):
    out, _, _ = _bash_eval(
        '_resolve_dispatch_model_and_fallback "" build', cache_dir,
        env_extra={"FW_DISPATCH_MODEL_DEFAULT": "haiku"},
    )
    assert out == "haiku|true|env-default"


def test_resolve_returns_none_when_nothing_configured(cache_dir):
    out, _, _ = _bash_eval(
        '_resolve_dispatch_model_and_fallback "" ""', cache_dir,
    )
    assert out == "||none"
