"""T-4378: the shared `hermetic` fixture (tests/unit/_hermetic.py) does what it says.

Each tripwire is driven by a deliberate leak aimed at a fake, never at the real
checkout, and the leak is undone before teardown so the fixture's own check passes.
"""
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest

from _hermetic import _snapshot

FW = Path(__file__).resolve().parents[2] / "bin" / "fw"


@pytest.fixture
def inherited(monkeypatch):
    """What a worker shell or the nightly cron hands a test; applied before `hermetic`."""
    for k, v in {"PROJECT_ROOT": "/nonexistent/inherited", "FRAMEWORK_ROOT": "/nonexistent/fw",
                 "FW_T4378_PROBE": "1", "CLAUDECODE": "1", "CLAUDE_T4378_PROBE": "1",
                 "TERMLINK_SESSION_ID": "tl-t4524"}.items():
        monkeypatch.setenv(k, v)


def test_inherited_env_is_stripped_in_process_and_in_subprocess_env(inherited, hermetic):
    for k in ("FRAMEWORK_ROOT", "FW_T4378_PROBE", "CLAUDECODE", "CLAUDE_T4378_PROBE",
              "TERMLINK_SESSION_ID"):
        assert k not in os.environ
        assert k not in hermetic.env()
    assert os.environ["PROJECT_ROOT"] == str(hermetic.project)
    assert hermetic.env()["PROJECT_ROOT"] == str(hermetic.project)
    assert "/nonexistent/" not in repr(hermetic.env())


def test_clean_keeps_only_the_named_keys(inherited, hermetic):
    built = dict(os.environ, FW_ISSUES_DIR="/x", FW_OTHER="y", CLAUDECODE="1")
    out = hermetic.clean(built, keep=("FW_ISSUES_DIR",))
    assert out["FW_ISSUES_DIR"] == "/x"
    assert "FW_OTHER" not in out and "CLAUDECODE" not in out
    assert out["TMPDIR"] == str(hermetic.tmp)


def test_private_tmpdir_and_project_markers(hermetic):
    import tempfile
    assert os.environ["TMPDIR"] == str(hermetic.tmp)
    assert hermetic.env()["TMPDIR"] == str(hermetic.tmp)
    assert (hermetic.project / ".tasks" / "active").is_dir()
    assert (hermetic.project / ".context" / "working").is_dir()
    assert hermetic.home.is_dir() and not any(hermetic.home.iterdir())
    tempfile.tempdir = None  # tempfile caches gettempdir(); re-read TMPDIR
    try:
        assert tempfile.mkdtemp().startswith(str(hermetic.tmp))
    finally:
        tempfile.tempdir = None


def test_fw_call_routes_to_the_temp_project_and_decoy_port(hermetic):
    r = hermetic.run([FW, "watchtower", "port"])
    assert r.returncode == 0, r.stderr
    assert str(hermetic.decoy.port) in r.stdout
    assert hermetic.tripwires(_snapshot(hermetic.repo), True) == []


def test_tripwire_watchtower_connection(hermetic):
    socket.create_connection(("127.0.0.1", hermetic.decoy.port), 2).close()
    for _ in range(100):
        if hermetic.decoy.connections:
            break
        time.sleep(0.02)
    fired = hermetic.tripwires(_snapshot(hermetic.repo), True)
    assert any("connected to Watchtower" in f for f in fired), fired
    hermetic.decoy.connections = 0


def test_tripwire_live_sidecar_stop_marker(hermetic):
    hermetic.sidecar_stopped = hermetic.root / "fake-sidecar-stopped"
    hermetic.sidecar_stopped.touch()
    fired = hermetic.tripwires(_snapshot(hermetic.repo), False)
    assert any("live sidecar was explicitly stopped" in f for f in fired), fired
    hermetic.sidecar_stopped.unlink()


def test_tripwire_new_entry_in_the_checkout(hermetic):
    fake = hermetic.root / "fake-repo"
    (fake / ".context").mkdir(parents=True)
    before = _snapshot(fake)
    (fake / ".context" / "leaked").mkdir()
    real = hermetic.repo
    hermetic.repo = fake
    try:
        fired = hermetic.tripwires(before, True)
        assert any(".context/leaked" in f for f in fired), fired
    finally:
        hermetic.repo = real


def test_teardown_fails_a_test_that_leaks(tmp_path):
    """End to end: a test that connects to Watchtower is failed by the fixture itself."""
    (tmp_path / "conftest.py").write_text(
        f"import sys; sys.path.insert(0, {str(Path(__file__).parent)!r})\n"
        "from _hermetic import hermetic  # noqa\n")
    (tmp_path / "test_leak.py").write_text(
        "import socket, time\n"
        "def test_leak(hermetic):\n"
        "    socket.create_connection(('127.0.0.1', hermetic.decoy.port), 2).close()\n"
        "    for _ in range(100):\n"
        "        if hermetic.decoy.connections:\n"
        "            break\n"
        "        time.sleep(0.02)\n")
    r = subprocess.run([sys.executable, "-m", "pytest", "-q", "-p", "no:cacheprovider", str(tmp_path)],
                       cwd=str(tmp_path), capture_output=True, text=True, timeout=120)
    assert r.returncode != 0, r.stdout
    assert "1 passed, 1 error" in r.stdout, r.stdout
    assert "hermetic tripwire" in r.stdout and "connected to Watchtower" in r.stdout, r.stdout


def test_allow_watchtower_needs_a_reason_and_silences_only_that_tripwire(hermetic):
    with pytest.raises(ValueError):
        hermetic.allow_watchtower("")
    socket.create_connection(("127.0.0.1", hermetic.decoy.port), 2).close()
    for _ in range(100):
        if hermetic.decoy.connections:
            break
        time.sleep(0.02)
    hermetic.allow_watchtower("self-test: probing on purpose")
    assert hermetic.tripwires(_snapshot(hermetic.repo), True) == []
