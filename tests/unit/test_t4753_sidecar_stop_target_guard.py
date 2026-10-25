"""T-4753: a sidecar start/stop acts on the project it is run in.

An agent shell carries the session's PROJECT_ROOT, and bin/fw keeps a valid
inherited one, so `fw sidecar receiver stop` typed inside a temp t3693 agent
root stopped the LIVE project's watcher (2026-10-21, 2026-10-25). Here both
projects are fixtures under tmp_path: "live" plays the running project, "agent"
the temp root the stop is typed in. The real project is never touched.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]
FW = str(FW_ROOT / "bin" / "fw")


def _project(base: Path, name: str) -> Path:
    root = base / name
    (root / ".context" / "sidecar" / "watcher").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {name}\n", encoding="utf-8")
    return root


@pytest.fixture
def two(tmp_path):
    live = _project(tmp_path, "live")
    agent = _project(tmp_path, "agent")
    (live / ".context" / "sidecar" / "watcher" / "enabled.json").write_text(
        json.dumps({"agent": "live-fixture", "project_root": str(live)}), encoding="utf-8")
    env = {k: os.environ[k] for k in ("HOME", "PATH", "USER", "LANG") if k in os.environ}
    env.update(FW_SIDECAR_ENABLED_DIR=str(tmp_path / "enabled"),
               FW_SIDECAR_REGISTRY_DIR=str(tmp_path / "registry"),
               XDG_STATE_HOME=str(tmp_path / "state"),
               TERMLINK_RUNTIME_DIR=str(tmp_path / "no-hub"),
               FW_SIDECAR_AGENT_ID="t4753-fixture")
    return live, agent, env


def _untouched(live: Path) -> None:
    w = live / ".context" / "sidecar" / "watcher"
    assert not (w / "stopped").exists(), "the stop wrote the OTHER project's stopped marker"
    assert (w / "enabled.json").exists(), "the stop disabled the OTHER project's sidecar"
    ev = w / "events.jsonl"
    assert not ev.exists() or "STOP_REQUESTED" not in ev.read_text(encoding="utf-8")


@pytest.mark.parametrize("verb", [["receiver", "stop", "--quiet"], ["stop", "--quiet"],
                                  ["receiver", "start", "--quiet"], ["start", "--quiet"]])
def test_inherited_root_of_another_project_is_refused(two, verb):
    live, agent, env = two
    proc = subprocess.run(CLI + verb, cwd=agent, env=dict(env, PROJECT_ROOT=str(live)),
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 2, proc.stdout + proc.stderr
    assert "T-4753" in proc.stderr and str(agent) in proc.stderr
    _untouched(live)


def test_bin_fw_teardown_shape_from_agent_root_is_refused(two):
    """The 13:53 incident shape: bin/fw from the temp agent root, session env."""
    live, agent, env = two
    proc = subprocess.run([FW, "sidecar", "receiver", "stop", "--quiet"], cwd=agent,
                          env=dict(env, PROJECT_ROOT=str(live)),
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 2, proc.stdout + proc.stderr
    _untouched(live)


def test_clean_env_stop_acts_on_the_project_it_runs_in(two):
    """The t3693/t3684 teardown env: no PROJECT_ROOT, cwd = agent root."""
    live, agent, env = two
    proc = subprocess.run([FW, "sidecar", "stop", "--quiet"], cwd=agent, env=env,
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert (agent / ".context" / "sidecar" / "watcher" / "stopped").exists()
    _untouched(live)


def test_explicit_project_flag_names_the_target(two):
    live, agent, env = two
    proc = subprocess.run(CLI + ["stop", "--quiet", "--project", str(agent)], cwd=agent,
                          env=dict(env, PROJECT_ROOT=str(live)),
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert (agent / ".context" / "sidecar" / "watcher" / "stopped").exists()
    _untouched(live)


def test_project_flag_must_be_a_project(two, tmp_path):
    live, agent, env = two
    proc = subprocess.run(CLI + ["stop", "--quiet", "--project", str(tmp_path / "nope")],
                          cwd=agent, env=env, capture_output=True, text=True, timeout=60)
    assert proc.returncode == 2
    _untouched(live)


def test_outside_any_project_the_env_root_still_wins(two, tmp_path):
    """Cron and supervisor shape: PROJECT_ROOT set, cwd in no project."""
    live, agent, env = two
    elsewhere = tmp_path / "plain"
    elsewhere.mkdir()
    proc = subprocess.run(CLI + ["stop", "--quiet"], cwd=elsewhere,
                          env=dict(env, PROJECT_ROOT=str(agent)),
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert (agent / ".context" / "sidecar" / "watcher" / "stopped").exists()
    _untouched(live)
