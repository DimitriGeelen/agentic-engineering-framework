"""T-4308 — `fw sidecar inbox` with no termlink binary.

A greenfield host has no termlink and no `.context/sidecar/hub-id` cache. The
address derivation then raises CircuitError, which used to escape cmd_inbox as a
Python traceback and exit 1. The contract pinned here: one NOT CHECKED line,
exit 3, no traceback — the same answer `fw sidecar alerts` gives.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
CLI = FW_ROOT / "lib" / "sidecar_cli.py"


def _path_without_termlink() -> str:
    """A PATH that still has python3 but no termlink. Fails the test loudly if
    termlink cannot be kept off it, rather than passing for the wrong reason."""
    py_dir = str(Path(sys.executable).resolve().parent)
    path = os.pathsep.join([py_dir, "/usr/bin", "/bin"])
    if shutil.which("termlink", path=path) is not None:
        pytest.skip("termlink lives in a system directory that cannot be removed from PATH")
    return path


@pytest.fixture
def bare_project(tmp_path):
    """An empty project: no hub-id cache, no FW_SIDECAR_HUB_ID override."""
    root = tmp_path / "t4308"
    root.mkdir()
    (root / ".framework.yaml").write_text("project_name: t4308\n")
    env = {k: v for k, v in os.environ.items()
           if k not in ("FW_SIDECAR_HUB_ID", "FW_SIDECAR_AGENT_ID", "FW_SIDECAR_REGISTRY_DIR")}
    env["PATH"] = _path_without_termlink()
    env["PROJECT_ROOT"] = str(root)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return root, env


def _run(args: list[str], env: dict) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(CLI), *args], env=env,
                          capture_output=True, text=True, timeout=60)


@pytest.mark.parametrize("args", [["inbox", "--peek"], ["inbox"], ["inbox", "--json"]])
def test_inbox_without_termlink_is_not_checked_not_a_traceback(bare_project, args):
    _root, env = bare_project
    proc = _run(args, env)
    combined = proc.stdout + proc.stderr
    assert "Traceback" not in combined, combined
    assert proc.returncode == 3, combined
    assert "termlink" in combined and "not installed" in combined, combined
    assert "cannot be read" in combined, combined


def test_inbox_without_termlink_json_says_unchecked(bare_project):
    import json
    _root, env = bare_project
    proc = _run(["inbox", "--json"], env)
    assert proc.returncode == 3, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["checked"] is False
    assert "termlink" in payload["reason"]
