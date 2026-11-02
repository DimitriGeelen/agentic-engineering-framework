"""T-5008 (ring20-dashboard msg b2be4058, G-128): a review seat must not signal processes it did not start.

An opencode seat stopped its own test server with `pkill -f 'uvicorn main:app'`; the pattern also
matched the live service (same host, same user, same command line). run.sh now launches every
harness seat inside its own PID namespace (`unshare --pid --fork --mount-proc --kill-child`) when
the host allows it, and says so in stderr.log and meta.json when it does not.

Fakes only: the seat is the opencode stub run through the real run.sh (from the committed
termlink.sh). Every process a test starts is stopped by the PID it was started with.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3580_round3_test as r3  # noqa: E402
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
import t3582_harness_kinds_test as hk  # noqa: E402
from t3582_harness_kinds_test import _brief, _stub_dir, hrepo  # noqa: E402,F401

TERMLINK = _HERE / "agents" / "termlink" / "termlink.sh"


def _pidns_works() -> bool:
    try:
        return subprocess.run(["unshare", "--pid", "--fork", "--mount-proc", "--kill-child", "true"],
                              capture_output=True, timeout=20).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


needs_pidns = pytest.mark.skipif(not _pidns_works(), reason="host refuses unshare --pid")

#: The opencode stub, plus what the field seat did: stop "its" server with pkill -f. It records its
#: own PID (1 inside a PID namespace) and pkill's exit code (1 = matched nothing). STUB_HANG makes
#: it start a child and never finish, for the watchdog test.
_SEAT = hk._OPENCODE.replace(
    'mode = os.environ.get("STUB_MODE", "green")',
    'mode = os.environ.get("STUB_MODE", "green")\n'
    'if a == ["--version"]:\n'   # T-4843's binary/version probe, not a seat run
    '    print("1.18.31")\n'
    '    sys.exit(0)\n'
    'import subprocess, time\n'
    'open(w + ".pid", "w").write(str(os.getpid()))\n'
    'decoy = os.environ.get("STUB_DECOY", "")\n'
    'if decoy:\n'
    '    rc = subprocess.run(["pkill", "-f", decoy]).returncode\n'
    '    open(w + ".pkill", "w").write(str(rc))\n'
    'hang = os.environ.get("STUB_HANG", "")\n'
    'if hang:\n'
    '    subprocess.Popen(["bash", "-c", "exec -a " + hang + " sleep 600"])\n'
    '    open(w + ".hung", "w").write("1")\n'
    '    time.sleep(600)\n', 1)


def _setup(root: Path) -> None:
    (_stub_dir(root) / "opencode").write_text(_SEAT)
    (_stub_dir(root) / "opencode").chmod(0o755)


def _run(root: Path, *, did: str, pidns: str = "", timeout: int = 60, extra: dict | None = None) -> Path:
    """cmd_dispatch's review leg, then the real run.sh (t4835's _run with a chosen timeout/env)."""
    rev = r3._head(root)
    w = root.parent / f"{root.name}-tl" / did
    w.mkdir(parents=True)
    brief = _brief(root, "opencode", rev)
    (w / "brief.md").write_text(brief.rstrip("\n") + "\n")
    (w / "prompt.md").write_text(vl.review_prompt(brief))
    (w / "task").write_text(TID)
    wb = _stub_dir(root) / "opencode"
    (w / "worker_bin").write_text(f"{wb}\n")
    (w / "worker_kind.txt").write_text("opencode\n")
    (w / "meta.json").write_text("{}\n")
    (w / "env.json").write_text(json.dumps({
        "FW_SIDECAR_AGENT_ID": did, "FW_REVIEW_REVISION": rev, "FW_REVIEW_WORKER": "1",
        "GIT_AUTHOR_NAME": "fw worker", "GIT_AUTHOR_EMAIL": "w@x.y",
        "GIT_COMMITTER_NAME": "fw worker", "GIT_COMMITTER_EMAIL": "w@x.y",
        "PYTHONDONTWRITEBYTECODE": "1"}))
    (w / "run.sh").write_text(r3._run_sh())
    r = subprocess.run([sys.executable, str(_HERE / "lib/verdict_ledger.py"), "register-dispatch",
                        "--dispatch-id", did, "--task", TID, "--task-type", "review",
                        "--revision", rev, "--wdir", str(w), "--worker-kind", "opencode",
                        "--worker-bin", str(wb), "--run-id", "", "--seat", ""],
                       cwd=root, env={**os.environ, "PROJECT_ROOT": str(root)},
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("FW_", "GIT_", "PYTHONDONTWRITEBYTECODE", "STUB_"))}
    env.update(PATH=f"{_stub_dir(root)}:{os.environ['PATH']}", STUB_MODE="green",
               LEDGER=str(_HERE / "lib/verdict_ledger.py"), WDIR_EXPECTED=str(w),
               _FW_RUNTIME_ENV_CLEAN="1", **(extra or {}))
    if pidns:
        env["FW_SEAT_PIDNS"] = pidns
    env.pop("PROJECT_ROOT", None)
    with (w.parent / f"{did}.out").open("w") as fh:
        subprocess.run(["bash", str(w / "run.sh"), did, str(root), str(w), str(timeout), "", "review", ""],
                       stdout=fh, stderr=subprocess.STDOUT, env=env, timeout=180)
    return w


def _procs_with(token: str) -> list[int]:
    """PIDs whose command line contains token, read from /proc (no pgrep)."""
    found = []
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            if token.encode() in (d / "cmdline").read_bytes():
                found.append(int(d.name))
        except OSError:
            continue
    return found


@pytest.fixture
def decoy():
    """A long-running process OUTSIDE the seat with a distinctive command line (the live service)."""
    line = f"fw-t5008-decoy-{uuid.uuid4().hex[:12]}"
    p = subprocess.Popen(["bash", "-c", f"exec -a {line} sleep 600"])
    time.sleep(0.3)
    try:
        yield line, p
    finally:
        if p.poll() is None:
            p.kill()   # by the PID this fixture started
        p.wait(timeout=10)


class TestTheSeatCannotReachTheDecoy:
    @needs_pidns
    def test_pkill_inside_the_seat_leaves_the_outside_decoy_alive(self, hrepo, decoy):
        line, p = decoy
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pidns000001", extra={"STUB_DECOY": line})
        assert Path(str(w) + ".pkill").read_text() == "1"   # pkill matched nothing it could see
        assert p.poll() is None, "the decoy outside the seat was killed"
        assert Path(str(w) + ".pid").read_text() == "1"     # the seat is init of its own namespace
        log = (w / "stderr.log").read_text()
        assert "seat process isolation: own PID namespace" in log, log[-2000:]
        assert json.loads((w / "meta.json").read_text())["seat_pid_isolation"] == "own PID namespace"
        assert (w / "exit_code").read_text().strip() == "0"


class TestFallbackWhenIsolationIsMissing:
    def test_off_writes_the_line_and_still_launches(self, hrepo):
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pidnsoff001", pidns="off")
        log = (w / "stderr.log").read_text()
        assert "seat process isolation not available: FW_SEAT_PIDNS=off" in log, log[-2000:]
        assert json.loads((w / "meta.json").read_text())["seat_pid_isolation"] == \
            "not available: FW_SEAT_PIDNS=off"
        assert Path(str(w) + ".pid").read_text() != "1"     # launched exactly as before
        assert (w / "exit_code").read_text().strip() == "0"


class TestWatchdogEndsANamespacedSeat:
    @needs_pidns
    def test_timeout_kills_the_worker_and_its_children(self, hrepo):
        token = f"fw-t5008-hang-{uuid.uuid4().hex[:12]}"
        _setup(hrepo)
        t0 = time.monotonic()
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pidnswd0001", timeout=3,
                 extra={"STUB_HANG": token, "WATCHDOG_KILL_GRACE": "2"})
        assert time.monotonic() - t0 < 120
        assert Path(str(w) + ".hung").is_file()             # the seat really was hanging
        assert (w / "timed_out").is_file()
        assert "TIMEOUT" in (w / "stderr.log").read_text()
        time.sleep(0.5)
        assert _procs_with(token) == [], "an orphan of the namespaced seat survived the watchdog"


class TestTheLaunchLines:
    def test_every_harness_kind_launches_through_the_namespace(self):
        src = TERMLINK.read_text()
        for kind in ("codex", "opencode", "antigravity"):
            block = src[src.index(f"            {kind})\n", src.index("_fw_seat_pidns\n        case")):]
            line = next(ln for ln in block.splitlines() if "( cd \"$TREE\"" in ln)
            assert 'exec ${SEAT_PIDNS[@]+"${SEAT_PIDNS[@]}"} ' in line, (kind, line)
        # antigravity: unshare as the launching user, sudo inside the namespace
        assert 'exec ${SEAT_PIDNS[@]+"${SEAT_PIDNS[@]}"} /usr/bin/sudo -n -u ' in src

    def test_the_probe_is_the_documented_command(self):
        assert "cmd=(unshare --pid --fork --mount-proc --kill-child)" in TERMLINK.read_text()


def test_the_brief_tells_every_harness_seat_not_to_signal_what_it_did_not_start():
    for kind in ("codex", "opencode"):
        b = _brief(Path("."), kind, "abc")
        assert "Never stop or signal a process you did not start" in b, kind
        for word in ("`pkill`", "`killall`", "`kill $(pgrep …)`"):
            assert word in b, (kind, word)
