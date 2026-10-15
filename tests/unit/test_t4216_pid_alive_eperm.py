"""T-4216 (055 T-509): pid_alive read EPERM as "dead".

os.kill(pid, 0) against a process owned by another user raises PermissionError.
That process EXISTS. A desktop-user Claude session (sidecar-autostart hook) probing
root's receiver took it as dead, started a second receiver and rewrote the shared
token (055's 2026-10-12 token break).
"""

from __future__ import annotations

import errno
import os
import sys
from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import lifecycle  # noqa: E402


def _kill_raising(exc):
    def fake_kill(pid, sig):
        raise exc
    return fake_kill


def test_eperm_means_alive(monkeypatch):
    monkeypatch.setattr(os, "kill", _kill_raising(PermissionError(errno.EPERM, "Operation not permitted")))
    assert lifecycle.pid_alive(4242) is True


def test_no_such_process_means_dead(monkeypatch):
    monkeypatch.setattr(os, "kill", _kill_raising(ProcessLookupError(errno.ESRCH, "No such process")))
    assert lifecycle.pid_alive(4242) is False


def test_other_oserror_means_dead(monkeypatch):
    monkeypatch.setattr(os, "kill", _kill_raising(OSError(errno.EINVAL, "Invalid argument")))
    assert lifecycle.pid_alive(4242) is False


def test_own_live_process_is_alive():
    assert lifecycle.pid_alive(os.getpid()) is True


def test_non_int_or_empty_pid_is_dead():
    assert lifecycle.pid_alive(None) is False
    assert lifecycle.pid_alive("123") is False
