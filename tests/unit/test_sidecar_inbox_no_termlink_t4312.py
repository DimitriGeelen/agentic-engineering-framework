"""T-4312 — `fw sidecar inbox` must not report "no pending consults" when the
hub could not be read.

T-4308 covered a host with no hub anchor (CircuitError → NOT CHECKED). This
covers the other half: the anchor is known (FW_SIDECAR_HUB_ID set) but the
termlink binary is absent, or the hub refuses the read. `inbox.default_reader`
swallows every such failure into [], so the CLI printed an empty inbox with
exit 0 — a false green on the one command an operator runs to see mail.

Pinned here:
  - the CLI answers NOT CHECKED (exit 3) for an unreadable hub, text and JSON;
  - a real empty inbox and an unknown topic (no mail yet) still read as empty;
  - `--show` never touches the hub and does not traceback without termlink;
  - `inbox.default_reader` keeps its lenient contract for the other callers.
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


def _path_without_termlink() -> str:
    py_dir = str(Path(sys.executable).resolve().parent)
    path = os.pathsep.join([py_dir, "/usr/bin", "/bin"])
    if shutil.which("termlink", path=path) is not None:
        pytest.skip("termlink lives in a system directory that cannot be removed from PATH")
    return path


def _fake_termlink(bin_dir: Path, script: str) -> str:
    """A `termlink` stub on a private PATH dir. `script` is the sh body."""
    bin_dir.mkdir(parents=True, exist_ok=True)
    tl = bin_dir / "termlink"
    tl.write_text("#!/bin/sh\n" + script + "\n")
    tl.chmod(0o755)
    return f"{bin_dir}{os.pathsep}{_path_without_termlink()}"


@pytest.fixture
def project(tmp_path):
    root = tmp_path / "t4312"
    root.mkdir()
    (root / ".framework.yaml").write_text("project_name: t4312\n")
    return root


def _env(root: Path, path: str) -> dict:
    env = {k: v for k, v in os.environ.items()
           if k not in ("FW_SIDECAR_AGENT_ID", "FW_SIDECAR_REGISTRY_DIR")}
    env["FW_SIDECAR_HUB_ID"] = HUB
    env["PATH"] = path
    env["PROJECT_ROOT"] = str(root)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def _run(args: list[str], env: dict) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(CLI), *args], env=env,
                          capture_output=True, text=True, timeout=60)


# --- the false green: hub id known, termlink absent -------------------------

@pytest.mark.parametrize("args", [["inbox", "--peek"], ["inbox"]])
def test_inbox_hub_id_known_no_termlink_is_not_checked(project, args):
    proc = _run(args, _env(project, _path_without_termlink()))
    combined = proc.stdout + proc.stderr
    assert "Traceback" not in combined, combined
    assert "no pending consults" not in combined, combined
    assert proc.returncode == 3, combined
    assert "NOT CHECKED" in combined and "not installed" in combined, combined


def test_inbox_hub_id_known_no_termlink_json_says_unchecked(project):
    proc = _run(["inbox", "--json"], _env(project, _path_without_termlink()))
    assert proc.returncode == 3, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["checked"] is False
    assert "termlink" in payload["reason"]


def test_inbox_hub_refuses_read_is_not_checked(project, tmp_path):
    # termlink is present but the hub fails the read: unknown, not empty.
    path = _fake_termlink(tmp_path / "bin", 'echo "hub unreachable" >&2; exit 1')
    proc = _run(["inbox", "--peek"], _env(project, path))
    combined = proc.stdout + proc.stderr
    assert proc.returncode == 3, combined
    assert "NOT CHECKED" in combined and "hub unreachable" in combined, combined
    assert "no pending consults" not in combined


# --- controls: a readable inbox still reads as empty ------------------------

def test_inbox_empty_topic_still_reads_empty(project, tmp_path):
    path = _fake_termlink(tmp_path / "bin", "exit 0")
    proc = _run(["inbox", "--peek"], _env(project, path))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "no pending consults" in proc.stdout


def test_inbox_unknown_topic_still_reads_empty(project, tmp_path):
    # No inbox topic on the hub yet means no mail, not an unreadable inbox.
    path = _fake_termlink(tmp_path / "bin", 'echo "unknown topic" >&2; exit 1')
    proc = _run(["inbox", "--peek"], _env(project, path))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "no pending consults" in proc.stdout


# --- --show never reads the hub --------------------------------------------

def test_show_stored_message_without_termlink_prints_it(project):
    store = project / ".context" / "sidecar" / "receiver" / "messages"
    store.mkdir(parents=True)
    (store / "m-t4312-1.json").write_text(
        json.dumps({"body": "hello peer", "from_agent": "peer", "conversation_id": "c1"}))
    proc = _run(["inbox", "--show", "m-t4312-1"], _env(project, _path_without_termlink()))
    assert "Traceback" not in proc.stderr, proc.stderr
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "hello peer" in proc.stdout


def test_show_missing_message_without_termlink_is_clean(project):
    proc = _run(["inbox", "--show", "m-absent"], _env(project, _path_without_termlink()))
    assert "Traceback" not in proc.stderr, proc.stderr
    assert proc.returncode == 1
    assert "no stored message" in proc.stderr


# --- the library contract the other callers depend on -----------------------

def test_default_reader_stays_lenient_for_other_callers(monkeypatch):
    sys.path.insert(0, str(FW_ROOT / "lib"))
    try:
        from sidecar import inbox
        monkeypatch.setattr(inbox, "_binary", lambda: "/nonexistent/termlink")
        assert inbox.default_reader("inbox:x", 0) == []
    finally:
        sys.path.remove(str(FW_ROOT / "lib"))
