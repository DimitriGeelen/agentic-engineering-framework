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


def test_json_stdout_parses_on_uninitialised_root(fresh_root: Path) -> None:
    """The regression itself: stdout must be JSON and nothing else."""
    result = _run_uninitialised(fresh_root, "orchestrator", "status", "--json")
    assert result.returncode == 0, result.stderr
    # Not `in`/startswith — the whole channel has to parse, which is the only
    # assertion a downstream consumer's json.loads actually makes.
    data = json.loads(result.stdout)
    assert isinstance(data, dict)


def test_auto_init_narration_goes_to_stderr(fresh_root: Path) -> None:
    """The side effect must remain announced — just not on the data channel.

    Pairs with the test above: together they say "moved", where either alone
    would also be satisfied by "discarded".
    """
    result = _run_uninitialised(fresh_root, "orchestrator", "status", "--json")
    assert result.returncode == 0, result.stderr
    assert "Setting up agentic governance" in result.stderr
    assert "Setting up agentic governance" not in result.stdout


def test_auto_init_actually_fired(fresh_root: Path) -> None:
    """Guard against the tests passing because the branch was never reached.

    If a future change stops auto-initialising here, the two assertions above
    would still hold — vacuously, on a command that never had a banner to
    misplace. This test fails loudly in that case so the contract above is
    re-derived rather than silently retired (see T-2770, which may legitimately
    change this behaviour; it should have to update this test to do so).
    """
    _run_uninitialised(fresh_root, "orchestrator", "status", "--json")
    assert (fresh_root / ".framework.yaml").exists(), (
        "auto-init did not fire — the stdout-purity tests above are now vacuous"
    )
