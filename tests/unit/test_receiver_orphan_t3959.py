"""T-3959 (1409): the sidecar receiver exits once the project it serves is gone.

A dispatched worker in a worktree starts its own receiver (R14); when the worktree was
removed the receiver ran on. `_watch_project` checks `<root>/.context` and calls the
server's shutdown when it disappears.
"""
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.sidecar import http_server  # noqa: E402


def test_shutdown_when_project_context_disappears(tmp_path):
    (tmp_path / ".context").mkdir()
    fired = threading.Event()
    t = http_server._watch_project(tmp_path, fired.set, interval=0.05)
    assert not fired.wait(0.3), "fired while the project still exists"
    (tmp_path / ".context").rmdir()
    assert fired.wait(2), "receiver did not shut down after its project was removed"
    t.join(1)
    assert not t.is_alive()


def test_control_no_shutdown_while_project_exists(tmp_path):
    (tmp_path / ".context").mkdir()
    fired = threading.Event()
    http_server._watch_project(tmp_path, fired.set, interval=0.05)
    assert not fired.wait(0.5)


def test_serve_wires_the_watch():
    src = (ROOT / "lib/sidecar/http_server.py").read_text(encoding="utf-8")
    body = src[src.index("def serve("):]
    assert "_watch_project(receiver._root(), server.shutdown)" in body
