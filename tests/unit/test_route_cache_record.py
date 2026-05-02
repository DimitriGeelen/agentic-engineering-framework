"""T-1669 Step 2 — framework dispatch records outcomes into route_cache.

Pins `_route_cache_record_outcome` and `cmd_record_outcome` in
`agents/termlink/termlink.sh`. The recording is what makes the
orchestrator-rethink arc's headline_mechanic actually fire — without
write-back the route_cache learned nothing from framework dispatches and
the read path (Step 1) had no data to act on.

Schema mirrors /opt/termlink RouteCache JSON serialization
(crates/termlink-hub/src/route_cache.rs).
"""

import json
import os
import subprocess
import threading
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TERMLINK_SH = REPO_ROOT / "agents" / "termlink" / "termlink.sh"


def _bash_eval(snippet, runtime_dir, env_extra=None):
    env = os.environ.copy()
    env["TERMLINK_RUNTIME_DIR"] = str(runtime_dir)
    if env_extra:
        env.update(env_extra)
    full = f'source "{TERMLINK_SH}" 2>/dev/null\n{snippet}\n'
    r = subprocess.run(
        ["bash", "-c", full], env=env, capture_output=True, text=True
    )
    return r.stdout.rstrip("\n"), r.returncode, r.stderr


def _read_cache(runtime_dir):
    p = Path(runtime_dir) / "route-cache.json"
    if not p.exists():
        return None
    return json.loads(p.read_text())


@pytest.fixture
def cache_dir(tmp_path):
    d = tmp_path / "tlrun"
    d.mkdir()
    return d


# ─── Function-level: _route_cache_record_outcome ─────────────────────────────

def test_record_success_creates_cache_when_absent(cache_dir):
    out, rc, err = _bash_eval(
        '_route_cache_record_outcome haiku build 0', cache_dir
    )
    assert rc == 0, err
    cache = _read_cache(cache_dir)
    assert cache is not None
    assert "model_stats" in cache
    stat = cache["model_stats"]["haiku:build"]
    assert stat["successes"] == 1
    assert stat["failures"] == 0
    assert stat["model"] == "haiku"
    assert stat["task_type"] == "build"
    assert stat["last_used"] is not None


def test_record_failure_increments_failures(cache_dir):
    _bash_eval('_route_cache_record_outcome haiku build 1', cache_dir)
    cache = _read_cache(cache_dir)
    stat = cache["model_stats"]["haiku:build"]
    assert stat["successes"] == 0
    assert stat["failures"] == 1


def test_record_increments_existing_stat(cache_dir):
    seed = {
        "entries": {},
        "model_stats": {
            "haiku:build": {
                "model": "haiku", "task_type": "build",
                "successes": 5, "failures": 2,
                "last_used": "2026-05-01T00:00:00Z",
            }
        },
    }
    (cache_dir / "route-cache.json").write_text(json.dumps(seed))
    _bash_eval('_route_cache_record_outcome haiku build 0', cache_dir)
    cache = _read_cache(cache_dir)
    stat = cache["model_stats"]["haiku:build"]
    assert stat["successes"] == 6
    assert stat["failures"] == 2


def test_record_separates_keys_by_model_and_task_type(cache_dir):
    _bash_eval('_route_cache_record_outcome haiku build 0', cache_dir)
    _bash_eval('_route_cache_record_outcome haiku inception 0', cache_dir)
    _bash_eval('_route_cache_record_outcome opus build 1', cache_dir)
    cache = _read_cache(cache_dir)
    keys = set(cache["model_stats"].keys())
    assert keys == {"haiku:build", "haiku:inception", "opus:build"}
    assert cache["model_stats"]["opus:build"]["failures"] == 1


def test_record_preserves_unrelated_entries(cache_dir):
    seed = {
        "entries": {"some": "thing"},
        "model_stats": {
            "sonnet:design": {
                "model": "sonnet", "task_type": "design",
                "successes": 3, "failures": 1, "last_used": None,
            }
        },
    }
    (cache_dir / "route-cache.json").write_text(json.dumps(seed))
    _bash_eval('_route_cache_record_outcome haiku build 0', cache_dir)
    cache = _read_cache(cache_dir)
    assert cache["entries"] == {"some": "thing"}
    assert cache["model_stats"]["sonnet:design"]["successes"] == 3


def test_record_recovers_from_corrupt_cache(cache_dir):
    (cache_dir / "route-cache.json").write_text("not json {")
    out, rc, _ = _bash_eval(
        '_route_cache_record_outcome haiku build 0', cache_dir
    )
    assert rc == 0
    cache = _read_cache(cache_dir)
    assert cache is not None
    assert cache["model_stats"]["haiku:build"]["successes"] == 1


def test_record_noop_on_missing_args(cache_dir):
    out, rc, _ = _bash_eval(
        '_route_cache_record_outcome "" build 0', cache_dir
    )
    assert rc == 0
    assert _read_cache(cache_dir) is None  # no file written

    _bash_eval('_route_cache_record_outcome haiku "" 0', cache_dir)
    assert _read_cache(cache_dir) is None

    _bash_eval('_route_cache_record_outcome haiku build ""', cache_dir)
    assert _read_cache(cache_dir) is None


def test_record_concurrent_writes_dont_lose_updates(cache_dir):
    """20 concurrent recorder processes → final successes == 20.

    File lock + tmpfile-rename should make this race-free. If the lock
    is dropped, this test will flake under load (lost-update race).
    """
    def fire(i):
        _bash_eval('_route_cache_record_outcome haiku build 0', cache_dir)

    threads = [threading.Thread(target=fire, args=(i,)) for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    cache = _read_cache(cache_dir)
    assert cache["model_stats"]["haiku:build"]["successes"] == 20


# ─── Subcommand-level: cmd_record_outcome ────────────────────────────────────

def test_cmd_record_outcome_via_flags(cache_dir):
    out, rc, _ = _bash_eval(
        'cmd_record_outcome --model haiku --task-type build --exit-code 0',
        cache_dir,
    )
    assert rc == 0
    cache = _read_cache(cache_dir)
    assert cache["model_stats"]["haiku:build"]["successes"] == 1


def test_cmd_record_outcome_failure_path(cache_dir):
    _bash_eval(
        'cmd_record_outcome --model opus --task-type design --exit-code 137',
        cache_dir,
    )
    cache = _read_cache(cache_dir)
    assert cache["model_stats"]["opus:design"]["failures"] == 1


# ─── Integration with read path (Step 1 + Step 2 together) ───────────────────

def test_recorded_outcomes_drive_subsequent_resolution(cache_dir):
    """Record enough successes for haiku:build → resolver picks haiku."""
    for _ in range(5):
        _bash_eval('_route_cache_record_outcome haiku build 0', cache_dir)
    _bash_eval('_route_cache_record_outcome opus build 1', cache_dir)
    out, _, _ = _bash_eval(
        '_resolve_dispatch_model_and_fallback "" build', cache_dir
    )
    assert out == "haiku|true|route_cache"


# ─── Source-level pin: run.sh wires record-outcome ───────────────────────────

def test_dispatch_run_sh_calls_record_outcome():
    """Pin the heredoc that wires record-outcome after worker exit.

    A future refactor that drops the call would silently break the
    learning loop — the orchestrator-rethink arc's headline_mechanic
    depends on this line being present.
    """
    src = TERMLINK_SH.read_text()
    dispatch_block = src.split("cmd_dispatch() {", 1)[1].split("cmd_wait() {", 1)[0]
    # The run.sh heredoc must:
    assert "TASK_TYPE=" in dispatch_block, "run.sh must accept TASK_TYPE arg"
    assert "FW_BIN=" in dispatch_block, "run.sh must accept FW_BIN arg"
    assert "termlink record-outcome" in dispatch_block, (
        "run.sh must invoke fw termlink record-outcome after EXIT_CODE"
    )
    # And the inject call must pass the new args:
    assert "'$task_type' '$fw_bin'" in dispatch_block, (
        "pty inject must pass task_type + fw_bin to run.sh"
    )


def test_dispatch_run_sh_updates_meta_json_post_exit():
    """Pin the heredoc that rewrites meta.json after worker exit (T-1681).

    Pre-T-1681: meta.json was written at spawn with status:running and
    never updated. `fw termlink dispatch_status` reported running forever
    even after exit_code/finished_at/record-outcome had all fired. Fix is
    a jq-based atomic rewrite in run.sh. Drop this rewrite and the
    dispatch_status surface goes stale again.
    """
    src = TERMLINK_SH.read_text()
    dispatch_block = src.split("cmd_dispatch() {", 1)[1].split("cmd_wait() {", 1)[0]
    assert "T-1681" in dispatch_block, "run.sh must reference T-1681 (the meta.json post-exit rewrite)"
    assert "command -v jq" in dispatch_block, "meta.json rewrite must guard on jq presence"
    assert ".status = $s" in dispatch_block, "meta.json rewrite must set status field"
    assert ".exit_code = $ec" in dispatch_block, "meta.json rewrite must set exit_code field"
    assert ".ended = $fa" in dispatch_block, "meta.json rewrite must set ended timestamp"
    assert "meta.json.tmp" in dispatch_block, "meta.json rewrite must use atomic tmp+mv"
