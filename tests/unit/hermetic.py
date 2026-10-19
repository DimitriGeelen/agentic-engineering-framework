"""One hermetic fixture for pytest (T-4378); the bats twin is tests/unit/helpers/hermetic.bash.

Registered in tests/unit/conftest.py, so any test can ask for it:

    def test_x(hermetic):
        r = hermetic.run([FW, "orchestrator", "status"])   # cwd = hermetic.project

What a test gets:
  .root      private tmp dir (pytest's tmp_path)
  .tmp       private TMPDIR, also set in os.environ for in-process code
  .home      an empty directory; HOME is NOT redirected (git and ~/.claude read it)
  .project   a project carrying the markers fw needs (.tasks/, .context/), so fw never
             auto-inits; PROJECT_ROOT in os.environ points at it for in-process code
  .env(**extra)       os.environ minus PROJECT_ROOT/FRAMEWORK_ROOT/CLAUDE*/FW_*, with
                      PROJECT_ROOT=.project, the decoy FW_PORT, then `extra`
  .clean(env, keep=)  the same stripping applied to an env dict a test built itself
  .run(argv, **kw)    subprocess.run with .env(), cwd=.project, captured text, stdin closed

Tripwires, checked at teardown (pytest.fail names the leak):
  termlink    the autouse T-4205 tripwire in conftest (unchanged)
  watchtower  FW_PORT names a decoy listener; any connection fails the test unless it
              called hermetic.allow_watchtower("<reason>")
  live state  the live sidecar's explicit-stop marker appears (T-4315), or a new
              top-level entry appears in the real checkout or its .context/
Limit: a hard-coded `localhost:3000` bypasses FW_PORT and is not seen.
"""

from __future__ import annotations

import os
import socket
import subprocess
import threading
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SIDECAR_STOPPED = REPO / ".context" / "sidecar" / "watcher" / "stopped"


def stripped(name: str) -> bool:
    return name in ("PROJECT_ROOT", "FRAMEWORK_ROOT") or name.startswith(("CLAUDE", "FW_"))


def make_project(root: Path) -> Path:
    for sub in (".tasks/active", ".tasks/completed", ".context/working", ".context/project"):
        (root / sub).mkdir(parents=True, exist_ok=True)
    return root


def _snapshot(repo: Path) -> set[str]:
    names = set()
    for base, prefix in ((repo, ""), (repo / ".context", ".context/")):
        try:
            names.update(prefix + n for n in os.listdir(base))
        except OSError:
            pass
    return names


class _Decoy:
    """A Watchtower stand-in on an ephemeral port that counts connections."""

    def __init__(self):
        self.sock = socket.socket()
        self.sock.bind(("127.0.0.1", 0))
        self.sock.listen(16)
        self.port = self.sock.getsockname()[1]
        self.connections = 0
        self.requests: list[str] = []
        self._thread = threading.Thread(target=self._serve, daemon=True)
        self._thread.start()

    def _serve(self):
        while True:
            try:
                conn, _ = self.sock.accept()
            except OSError:
                return
            conn.settimeout(0.5)
            try:
                first = conn.recv(256).split(b"\r\n", 1)[0].decode("latin-1")
            except OSError:
                first = ""
            self.requests.append(first or "(no request)")
            self.connections += 1
            conn.close()

    def close(self):
        self.sock.close()


class Hermetic:
    def __init__(self, root: Path, decoy: _Decoy):
        self.root = root
        self.tmp = root / "tmp"
        self.home = root / "home"
        self.project = make_project(root / "project")
        self.tmp.mkdir()
        self.home.mkdir()
        self.decoy = decoy
        self.repo = REPO
        self.sidecar_stopped = SIDECAR_STOPPED
        self.watchtower_allowed = ""

    def allow_watchtower(self, reason: str) -> None:
        """The code under test probes Watchtower on purpose (e.g. fw init's /api/_identity
        check, lib/watchtower.sh:67). The decoy still answers, so the live server is never
        reached; only the tripwire is silenced. The reason is required."""
        if not reason:
            raise ValueError("allow_watchtower needs a reason")
        self.watchtower_allowed = reason

    def clean(self, env: dict, keep=()) -> dict:
        out = {k: v for k, v in env.items() if k in keep or not stripped(k)}
        out.update(TMPDIR=str(self.tmp), FW_PORT=str(self.decoy.port))
        out.setdefault("PROJECT_ROOT", str(self.project))
        return out

    def env(self, **extra) -> dict:
        out = self.clean(dict(os.environ))
        out.update(extra)
        return out

    def run(self, argv, env=None, **kw) -> subprocess.CompletedProcess:
        kw.setdefault("cwd", str(self.project))
        kw.setdefault("capture_output", True)
        kw.setdefault("text", True)
        kw.setdefault("stdin", subprocess.DEVNULL)
        return subprocess.run([str(a) for a in argv], env=env or self.env(), **kw)

    def tripwires(self, before: set[str], sidecar_was_stopped: bool) -> list[str]:
        fired = []
        if self.decoy.connections and not self.watchtower_allowed:
            fired.append(f"the test connected to Watchtower (decoy port {self.decoy.port}): "
                         + " | ".join(self.decoy.requests[:3]))
        if not sidecar_was_stopped and os.path.exists(self.sidecar_stopped):
            fired.append(f"the live sidecar was explicitly stopped ({self.sidecar_stopped}); "
                         "restart: bin/fw sidecar start")
        new = sorted(_snapshot(self.repo) - before)
        if new:
            fired.append("new entries in the real checkout: " + " ".join(new))
        return fired


@pytest.fixture
def hermetic(request, monkeypatch, tmp_path):
    decoy = _Decoy()
    h = Hermetic(tmp_path, decoy)
    before = _snapshot(h.repo)
    sidecar_was_stopped = os.path.exists(h.sidecar_stopped)
    for name in list(os.environ):
        if stripped(name):
            monkeypatch.delenv(name)
    monkeypatch.setenv("TMPDIR", str(h.tmp))
    monkeypatch.setenv("FW_PORT", str(decoy.port))
    monkeypatch.setenv("PROJECT_ROOT", str(h.project))
    try:
        yield h
    finally:
        fired = h.tripwires(before, sidecar_was_stopped)
        decoy.close()
    if fired:
        pytest.fail(f"T-4378 hermetic tripwire in {request.node.nodeid}: " + "; ".join(fired),
                    pytrace=False)
