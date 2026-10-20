"""T-3709 — build-class dispatches never take their model from the route cache.

The route cache ranks models by close-gate outcomes a worker can satisfy with its
own tests, so on 2026-10-02 it routed every build dispatch to haiku. Build-class
types (build, design, specification, refactor) now resolve explicit → per-type
config → default config → the strongest model, and dispatch prints its choice.
"""

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TERMLINK_SH = REPO_ROOT / "agents" / "termlink" / "termlink.sh"

HAIKU_WINS = {
    "haiku:{t}": {"successes": 9, "failures": 1},
    "opus:{t}": {"successes": 5, "failures": 5},
}


def _seed(cache_dir, task_type):
    stats = {}
    for key, v in HAIKU_WINS.items():
        model = key.split(":")[0]
        stats[key.format(t=task_type)] = {
            "model": model, "task_type": task_type, "last_used": None, **v,
        }
    (cache_dir / "route-cache.json").write_text(
        json.dumps({"entries": {}, "model_stats": stats}))


def _resolve(tmp_path, task_type, extra_env=None):
    rt = tmp_path / "tlrun"
    rt.mkdir(exist_ok=True)
    _seed(rt, task_type)
    (tmp_path / ".framework.yaml").write_text("")
    env = os.environ.copy()
    for k in list(env):
        if k.startswith("FW_DISPATCH_MODEL"):
            del env[k]
    env.update({"TERMLINK_RUNTIME_DIR": str(rt), "PROJECT_ROOT": str(tmp_path)})
    env.update(extra_env or {})
    r = subprocess.run(
        ["bash", "-c", f'source "{TERMLINK_SH}" 2>/dev/null\n'
                       f'_resolve_dispatch_model_and_fallback "" "{task_type}"'],
        env=env, capture_output=True, text=True, cwd=tmp_path)
    return r.stdout.strip()


@pytest.mark.parametrize("task_type", ["build", "design", "specification", "refactor"])
def test_build_class_ignores_route_cache_and_defaults_to_strongest(tmp_path, task_type):
    assert _resolve(tmp_path, task_type) == "opus|true|strongest-default"


def test_build_class_honours_operator_config_over_strongest_default(tmp_path):
    out = _resolve(tmp_path, "build", {"FW_DISPATCH_MODEL_FOR_BUILD": "sonnet"})
    assert out == "sonnet|true|env-per-type"


def test_non_build_type_still_uses_route_cache(tmp_path):
    assert _resolve(tmp_path, "test") == "haiku|true|route_cache"


def test_dispatch_prints_resolved_model_to_stderr():
    src = TERMLINK_SH.read_text()
    block = src.split("cmd_dispatch() {", 1)[1].split("cmd_wait() {", 1)[0]
    line = next((l for l in block.splitlines() if 'echo "Model: ' in l), "")
    assert "${resolution_source" in line and line.rstrip().endswith(">&2")
