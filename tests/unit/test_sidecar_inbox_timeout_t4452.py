"""T-4452 — a termlink read that times out is NOT an empty inbox.

`inbox.default_reader` caught TimeoutExpired and returned [], the same value as
"no mail", so a slow or loaded hub silently hid pending consults from every
caller that read through it (status, doctor/audit backlog, and — via the hook
dropping the CLI's exit 3 — the agent's own prompt).

Pinned here, with a stub `termlink` on PATH that sleeps past the timeout:
  - the reader returns a `ReadFailed` (still `== []`, carries `.reason`);
  - the strict reader raises `Unreadable` naming the timeout;
  - `fw sidecar inbox`, `alerts` say NOT CHECKED (exit 3), `inbox-stale` exits 2;
  - controls: an empty read and an unknown topic are still a plain [].
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
CLI = FW_ROOT / "lib" / "sidecar_cli.py"
HUB = "abcdef0123456789"

sys.path.insert(0, str(FW_ROOT))
from lib.sidecar import alerts, inbox  # noqa: E402

# Sleeps on a read (subscribe) only, so other termlink calls stay quick.
SLEEPER = 'case "$*" in *subscribe*) sleep 10;; esac\nexit 0'


def _base_path() -> str:
    py_dir = str(Path(sys.executable).resolve().parent)
    path = os.pathsep.join([py_dir, "/usr/bin", "/bin"])
    if shutil.which("termlink", path=path) is not None:
        pytest.skip("termlink lives in a system directory that cannot be removed from PATH")
    return path


def _stub(bin_dir: Path, script: str) -> Path:
    bin_dir.mkdir(parents=True, exist_ok=True)
    tl = bin_dir / "termlink"
    tl.write_text("#!/bin/sh\n" + script + "\n")
    tl.chmod(0o755)
    return tl


@pytest.fixture
def project(tmp_path):
    root = tmp_path / "t4452"
    (root / ".context" / "sidecar").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4452\n")
    return root


def _env(root: Path, bin_dir: Path) -> dict:
    env = {k: v for k, v in os.environ.items()
           if k not in ("FW_SIDECAR_AGENT_ID", "FW_SIDECAR_REGISTRY_DIR")}
    env.update(FW_SIDECAR_HUB_ID=HUB, PROJECT_ROOT=str(root),
               PATH=f"{bin_dir}{os.pathsep}{_base_path()}",
               SIDECAR_READ_TIMEOUT="1", PYTHONDONTWRITEBYTECODE="1")
    return env


def _run(args, env) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(CLI), *args], env=env,
                          capture_output=True, text=True, timeout=60)


# --- the reader ---------------------------------------------------------------

def test_default_reader_timeout_is_read_failed_not_empty(tmp_path):
    tl = _stub(tmp_path / "bin", SLEEPER)
    got = inbox.default_reader("inbox:x", 0, binary=str(tl), timeout=1)
    assert isinstance(got, inbox.ReadFailed)
    assert got == [] and not got          # lenient callers see no envelopes
    assert "timed out" in got.reason and "inbox:x" in got.reason


def test_default_reader_hub_refusal_is_read_failed(tmp_path):
    tl = _stub(tmp_path / "bin", 'echo "hub unreachable" >&2; exit 1')
    got = inbox.default_reader("inbox:x", 0, binary=str(tl))
    assert isinstance(got, inbox.ReadFailed)
    assert "hub unreachable" in got.reason


@pytest.mark.parametrize("script", ["exit 0", 'echo "unknown topic" >&2; exit 1'])
def test_empty_read_and_unknown_topic_stay_plain_empty(tmp_path, script):
    tl = _stub(tmp_path / "bin", script)
    got = inbox.default_reader("inbox:x", 0, binary=str(tl))
    assert got == [] and not isinstance(got, inbox.ReadFailed)


def test_strict_reader_raises_on_timeout(tmp_path, monkeypatch):
    tl = _stub(tmp_path / "bin", SLEEPER)
    monkeypatch.setattr(inbox, "_binary", lambda: str(tl))
    with pytest.raises(inbox.Unreadable, match="timed out"):
        inbox.strict_reader("inbox:x", 0, timeout=1)
    # One definition, re-exported (by module name: other suites reload these modules).
    assert alerts.strict_reader.__module__.endswith("sidecar.inbox")
    assert alerts.Unreadable.__module__.endswith("sidecar.inbox")


# --- the CLI surfaces -----------------------------------------------------------

@pytest.mark.parametrize("args", [["inbox", "--peek"], ["inbox"]])
def test_cli_inbox_timeout_is_not_checked(project, tmp_path, args):
    _stub(tmp_path / "bin", SLEEPER)
    proc = _run(args, _env(project, tmp_path / "bin"))
    combined = proc.stdout + proc.stderr
    assert proc.returncode == 3, combined
    assert "NOT CHECKED" in combined and "timed out" in combined, combined
    assert "no pending consults" not in combined


def test_cli_inbox_json_timeout_says_unchecked(project, tmp_path):
    _stub(tmp_path / "bin", SLEEPER)
    proc = _run(["inbox", "--peek", "--json"], _env(project, tmp_path / "bin"))
    assert proc.returncode == 3, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["checked"] is False and "timed out" in payload["reason"]


def test_cli_alerts_timeout_is_not_checked(project, tmp_path):
    _stub(tmp_path / "bin", SLEEPER)
    proc = _run(["alerts"], _env(project, tmp_path / "bin"))
    combined = proc.stdout + proc.stderr
    assert proc.returncode == 3, combined
    assert "NOT CHECKED" in combined and "timed out" in combined, combined


def test_cli_inbox_stale_timeout_could_not_run(project, tmp_path):
    # Was: exit 0 with an empty list — "nothing waiting" for a check that never ran.
    _stub(tmp_path / "bin", SLEEPER)
    proc = _run(["inbox-stale", "--json"], _env(project, tmp_path / "bin"))
    assert proc.returncode == 2, proc.stdout + proc.stderr
    assert "timed out" in proc.stderr


def test_unread_summary_raises_rather_than_counting_zero(tmp_path, monkeypatch):
    tl = _stub(tmp_path / "bin", SLEEPER)
    monkeypatch.setattr(inbox, "_binary", lambda: str(tl))
    monkeypatch.setenv("SIDECAR_READ_TIMEOUT", "1")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", HUB)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    with pytest.raises(inbox.Unreadable):
        inbox.unread_summary()


def test_cli_inbox_empty_hub_control(project, tmp_path):
    _stub(tmp_path / "bin", "exit 0")
    proc = _run(["inbox", "--peek"], _env(project, tmp_path / "bin"))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "no pending consults" in proc.stdout
