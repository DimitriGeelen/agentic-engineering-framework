"""A second Watchtower serving a temporary fixture project (T-5168).

The arc close-recommendation panel renders only for an in-progress arc whose
close-out or anchor task carries a CLOSE / KEEP-OPEN recommendation. Whether the
live corpus holds such an arc changes from week to week, so tests that picked one
with `pick_arc(close_recommendation=True)` skipped whenever it held none, and the
panel went untested.

`start()` copies `tests/fixtures/arc-close-panel/` into a new temporary directory
laid out as a project (`.context/arcs/`, `.tasks/active/`, `.tasks/completed/`),
starts `python3 -m web.app` with PROJECT_ROOT pointing at it on a free port, and
waits until `/api/_identity` reports that directory. The real `.context/arcs` and
`.tasks` of this repo are never written. `stop()` terminates the server and
removes the directory.

The identity check is the same one conftest applies to the main test server
(T-2782): a port that answers is not proof the right project is answering.
"""
import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_SRC = REPO_ROOT / "tests" / "fixtures" / "arc-close-panel"
START_TIMEOUT_S = int(os.environ.get("FW_TEST_FIXTURE_START_TIMEOUT_S", "60"))


@dataclass
class FixtureServer:
    root: Path
    port: int
    url: str
    proc: subprocess.Popen
    stderr_path: Path


def build_project(dest: Path) -> Path:
    """Lay the committed fixture out as a project under `dest`."""
    (dest / ".context" / "working").mkdir(parents=True)
    shutil.copytree(FIXTURE_SRC / "arcs", dest / ".context" / "arcs")
    for sub in ("active", "completed"):
        shutil.copytree(FIXTURE_SRC / "tasks" / sub, dest / ".tasks" / sub)
    return dest


def _free_port() -> int:
    forced = os.environ.get("FW_TEST_FIXTURE_PORT")
    if forced:
        return int(forced)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def _identity(url: str):
    try:
        with urllib.request.urlopen(f"{url}/api/_identity", timeout=2) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, ValueError):
        return None


def start() -> FixtureServer:
    root = build_project(Path(tempfile.mkdtemp(prefix="aef-arc-fixture-")))
    port = _free_port()
    url = f"http://localhost:{port}"
    # Outside `root`, so the served project holds only the fixture.
    stderr_path = Path(tempfile.gettempdir()) / f"watchtower-arc-fixture-{port}-stderr.log"
    env = {**os.environ, "PROJECT_ROOT": str(root), "FW_PORT": str(port),
           "FLASK_ENV": "testing"}
    # stdout to DEVNULL and stderr to a file: a pipe fills after ~150 logged
    # requests and blocks the server (see conftest.watchtower_server).
    with open(stderr_path, "w") as stderr_fh:
        proc = subprocess.Popen(
            ["python3", "-m", "web.app", "--port", str(port)],
            env=env, cwd=str(REPO_ROOT),
            stdout=subprocess.DEVNULL, stderr=stderr_fh,
        )
    server = FixtureServer(root=root, port=port, url=url, proc=proc, stderr_path=stderr_path)

    deadline = time.monotonic() + START_TIMEOUT_S
    ident = None
    while time.monotonic() < deadline and proc.poll() is None:
        ident = _identity(url)
        if ident is not None:
            break
        time.sleep(0.5)

    served = os.path.realpath(str((ident or {}).get("project_root", "")))
    if ident is None or ident.get("pid") != proc.pid or served != os.path.realpath(str(root)):
        try:
            tail = stderr_path.read_text(errors="replace")[-800:]
        except OSError:
            tail = ""
        stop(server, keep_log=True)
        raise RuntimeError(
            f"fixture Watchtower on port {port} is not serving the fixture project.\n"
            f"  expected PROJECT_ROOT: {root} (pid {proc.pid})\n"
            f"  /api/_identity said:   {ident}\n"
            f"  stderr ({stderr_path}) tail: {tail}"
        )
    return server


def stop(server: FixtureServer, keep_log: bool = False) -> None:
    proc = server.proc
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)
    shutil.rmtree(server.root, ignore_errors=True)
    if not keep_log:
        try:
            server.stderr_path.unlink()
        except OSError:
            pass
