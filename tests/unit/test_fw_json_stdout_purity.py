"""T-2769 — `fw <cmd> --json` must emit only JSON on stdout.

Origin: `bin/fw`'s non-TTY auto-init branch called itself "silent" while
suppressing the wrong stream. It ran `do_init ... 2>/dev/null`, but do_init
writes its progress narrative to *stdout*, so every `fw <cmd> --json` invoked
from a directory that is not yet a framework project returned

    Setting up agentic governance for <dir>...
    Vendoring framework into project...
    {...the actual JSON...}

with rc=0. Exit-code checks saw success; anything that parsed the output blew
up at character 0. Two tests in test_orchestrator_status_outcomes.py had been
failing on exactly this with no owner, because the only thing running them was
T-1805's verification fallback, whose population nobody had scoped (T-2766).

The contract pinned here is a stream-separation one and it is deliberately
stated in both directions:

    stdout is the data channel   — it parses, or the command is broken
    stderr is the narration      — and the auto-init side effect MUST stay there

The second half matters as much as the first. Auto-init writes a project into
the caller's cwd and vendors the framework there; "fix" the stdout leak by
sending that to /dev/null and the output is clean but the side effect becomes
invisible, which trades one blindness for another.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"


def _run_uninitialised(tmp_path: Path, *args: str) -> subprocess.CompletedProcess:
    """Run fw in a directory that is NOT a framework project.

    PROJECT_ROOT is set to the temp dir on purpose: that is what the real
    callers do, and `_project_root_is_stale` discards it anyway for lacking a
    marker, which is precisely how execution reaches the auto-init branch.
    """
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(tmp_path)
    env.pop("CLAUDE_PROJECT_DIR", None)  # else it wins and no auto-init happens
    return subprocess.run(
        [str(FW), *args],
        capture_output=True, text=True, env=env, cwd=str(tmp_path),
        stdin=subprocess.DEVNULL,  # force the non-TTY branch under test
        timeout=300,
    )


@pytest.fixture
def fresh_root(tmp_path: Path) -> Path:
    assert not (tmp_path / ".framework.yaml").exists()
    assert not (tmp_path / ".tasks").exists()
    return tmp_path


def test_uninitialised_root_keeps_stdout_clean(fresh_root: Path) -> None:
    """T-2746: no implicit init, so no narration can reach the data channel.

    Originally (T-2769) this pinned the auto-init narration to stderr. The
    auto-init is gone; the contract that survives is that a --json caller from
    a non-project gets an empty stdout and the refusal on stderr.
    """
    result = _run_uninitialised(fresh_root, "orchestrator", "status", "--json")
    assert result.returncode != 0
    assert result.stdout == ""
    assert "not in an AEF project:" in result.stderr
    assert "Setting up agentic governance" not in result.stderr


def test_no_implicit_init(fresh_root: Path) -> None:
    """Anti-vacuity: the refusal must leave the directory untouched."""
    _run_uninitialised(fresh_root, "orchestrator", "status", "--json")
    assert list(fresh_root.iterdir()) == [], "fw created files in a non-project cwd"
