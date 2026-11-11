#!/usr/bin/env python3
"""T-5080 — `fw config components`: choose the optional components a project leaves
out (operator request 2026-11-11: "arrow keys and space ... included, excluded").
Writes ABSENT_COMPONENTS (T-4355). The interactive screen is driven through a real
pseudo-terminal, the way a person would use it."""
import os
import pty
import select
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
FW = str(ROOT / "bin" / "fw")
import sys
sys.path.insert(0, str(ROOT / "lib"))
from optional_components import NAMES  # noqa: E402


@pytest.fixture
def proj(tmp_path):
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text("project_name: t5080\nversion: 1.0\n")
    return tmp_path


def env(proj):
    e = {k: v for k, v in os.environ.items() if k != "FW_ABSENT_COMPONENTS"}
    e.update(PROJECT_ROOT=str(proj), FRAMEWORK_ROOT=str(ROOT), TERM="xterm")
    return e


def fw(proj, *args):
    return subprocess.run([FW, "config", "components", *args], env=env(proj),
                          capture_output=True, text=True, stdin=subprocess.DEVNULL)


def stored(proj):
    for ln in (proj / ".framework.yaml").read_text().splitlines():
        if ln.startswith("ABSENT_COMPONENTS:"):
            return ln.split(":", 1)[1].strip().strip("'\"")
    return None


def test_list_names_every_component_with_its_state(proj):
    r = fw(proj, "--list")
    assert r.returncode == 0, r.stderr
    for n in NAMES:
        assert n in r.stdout
    assert "included" in r.stdout and "excluded" not in r.stdout


def test_set_writes_in_list_order_and_list_shows_it(proj):
    r = fw(proj, "--set", "node termlink")
    assert r.returncode == 0, r.stderr
    assert stored(proj) == "termlink node"
    out = fw(proj, "--list").stdout
    assert any(ln.split()[:2] == ["termlink", "excluded"] for ln in out.splitlines())


def test_set_refuses_an_unknown_name_and_writes_nothing(proj):
    r = fw(proj, "--set", "termlnk")
    assert r.returncode == 2
    assert "Unknown component" in r.stderr
    assert stored(proj) is None


def test_set_empty_clears_it(proj):
    fw(proj, "--set", "bats")
    assert stored(proj) == "bats"
    assert fw(proj, "--set", "").returncode == 0
    assert stored(proj) is None


def test_without_a_terminal_it_refuses_and_names_the_other_forms(proj):
    r = fw(proj)
    assert r.returncode == 2
    assert "--list" in r.stderr and "--set" in r.stderr


def _drive(proj, keys: list[bytes], timeout=20) -> bytes:
    pid, fd = pty.fork()
    if pid == 0:
        os.execve(FW, [FW, "config", "components"], env(proj))
    out = b""
    deadline = time.time() + timeout

    def pump(until=None, secs=1.5):
        nonlocal out
        end = time.time() + secs
        while time.time() < min(end, deadline):
            r, _, _ = select.select([fd], [], [], 0.1)
            if r:
                try:
                    out += os.read(fd, 4096)
                except OSError:
                    return False
                if until and until in out:
                    return True
        return True

    pump(until=b"Enter save", secs=10)
    for k in keys:
        os.write(fd, k)
        pump(secs=0.4)
    pump(secs=3)
    os.waitpid(pid, 0)
    os.close(fd)
    return out


def test_screen_space_toggles_and_enter_saves(proj):
    # Start on the first line (termlink); Down (ESC O B: what a terminal sends once curses turns keypad mode on) moves to node; Space excludes node; Enter saves.
    out = _drive(proj, [b"\x1bOB", b" ", b"\r"])
    assert b"Optional components" in out
    assert stored(proj) == NAMES[1]


def test_screen_q_leaves_without_saving(proj):
    out = _drive(proj, [b" ", b"q"])
    assert b"nothing changed" in out
    assert stored(proj) is None


def test_doctor_and_screen_share_one_list():
    src = (ROOT / "bin/fw").read_text()
    assert "lib/optional_components.py" in src
    assert '"termlink node bats shellcheck pi ollama litellm"' not in src
