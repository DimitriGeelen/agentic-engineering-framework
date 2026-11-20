"""T-5267 (G-135): a pid-file kill signals only the process that wrote the pid file.

A pid file names a number. After a reboot or a pid wrap it can belong to an unrelated
process, and a liveness check says yes to it. Each kill site now checks identity
(start time from /proc/<pid>/stat field 22, boot id, cmdline marker) first.

Every process here is started by this file and stopped by the pid it got from Popen;
nothing is signalled by name. Projects are temp dirs (the `hermetic` fixture), so the
live Watchtower and sidecar are never touched.
"""
from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

import lib.sidecar_cli as cli  # noqa: E402
from lib.sidecar import lifecycle, watcher  # noqa: E402

pi = lifecycle.proc_identity
PID_ALIVE_SH = FW_ROOT / "lib" / "pid-alive.sh"
WATCHTOWER_SH = FW_ROOT / "bin" / "watchtower.sh"
BE_REACHABLE = FW_ROOT / "lib" / "templates" / "scripts" / "be-reachable.sh"

pytestmark = pytest.mark.skipif(not Path("/proc/self/stat").exists(), reason="needs /proc")


# ── process fixtures ───────────────────────────────────────────────────────

@pytest.fixture
def procs():
    """Start long-lived processes; every one is killed by its own pid at teardown."""
    started: list[subprocess.Popen] = []

    def spawn(*marker_args: str, child: bool = False) -> subprocess.Popen:
        # `python3 -c <sleep> <marker args>`: the marker args land in the cmdline only.
        code = ("import subprocess,sys,time\n"
                + ("c=subprocess.Popen(['sleep','300'])\nprint(c.pid,flush=True)\n" if child else "")
                + "time.sleep(300)\n")
        p = subprocess.Popen([sys.executable, "-c", code, *marker_args],
                             stdout=subprocess.PIPE if child else subprocess.DEVNULL,
                             stdin=subprocess.DEVNULL, start_new_session=True)
        started.append(p)
        if child:
            p.child_pid = int(p.stdout.readline())
        _wait_for_cmdline(p.pid, marker_args)
        return p

    yield spawn
    for p in started:
        cpid = getattr(p, "child_pid", None)
        for pid in (cpid, p.pid):
            if pid:
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
        try:
            p.wait(timeout=5)
        except Exception:
            pass
        if cpid:
            _reap_wait(cpid)


def _wait_for_cmdline(pid, args):
    deadline = time.time() + 5
    while time.time() < deadline:
        cl = pi.cmdline(pid) or ""
        if all(a in cl for a in args) and "-c" in cl:
            return
        time.sleep(0.02)


def _reap_wait(pid, timeout=5.0):
    deadline = time.time() + timeout
    while time.time() < deadline and lifecycle.pid_alive(pid):
        time.sleep(0.05)


def alive(p) -> bool:
    pid = p if isinstance(p, int) else p.pid
    if not isinstance(p, int) and p.poll() is not None:
        return False
    return lifecycle.pid_alive(pid)


def write_fake_identity(pid_file: Path, pid: int, start_delta: int = -1, marker: str = ""):
    """An identity recorded for `pid` by a DIFFERENT (earlier) process: the reused-pid case."""
    real = pi.start_ticks(pid)
    Path(f"{pid_file}.identity").write_text(
        f"pid={pid}\nstart_ticks={real + start_delta}\nboot_id={pi.boot_id()}\n"
        f"cmd_marker={marker}\n", encoding="utf-8")


def _events(name):
    return [e for e in watcher.read_events() if e.get("event") == name]


@pytest.fixture
def proj(hermetic, tmp_path, monkeypatch):
    root = hermetic.project
    (root / ".context" / "sidecar").mkdir(parents=True, exist_ok=True)
    (root / ".framework.yaml").write_text("project_name: t5267\n", encoding="utf-8")
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "enabled"))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(tmp_path / "no-hub"))
    return root


# ── the shared rule: Python and shell agree ────────────────────────────────

def _sh_check(pid_file, pid, marker) -> int:
    r = subprocess.run(["bash", "-c", f'source "{PID_ALIVE_SH}"; fw_pid_same_process "$1" "$2" "$3"',
                        "_", str(pid_file), str(pid), marker], capture_output=True, text=True)
    return r.returncode


def _py_check(pid_file, pid, marker) -> int:
    ok, _ = pi.check_pid_file(pid_file, pid, marker)
    return 0 if ok else (2 if ok is None else 1)


def test_identity_reads_field_22_after_the_last_paren(procs):
    p = procs("t5267-a")
    raw = Path(f"/proc/{p.pid}/stat").read_text()
    assert pi.start_ticks(p.pid) == int(raw.rsplit(")", 1)[1].split()[19])
    rec = pi.identity(p.pid, "t5267-a")
    assert rec["pid"] == p.pid and rec["cmd_marker"] == "t5267-a" and rec["boot_id"]
    assert pi.identity(p.pid, "not-in-cmdline")["cmd_marker"] == ""


@pytest.mark.parametrize("case", ["same", "reused", "legacy-match", "legacy-nomatch",
                                  "legacy-nomarker", "gone", "recorded-marker-missing",
                                  "previous-boot", "identity-for-other-pid"])
@pytest.mark.parametrize("writer", ["py", "sh"])
def test_python_and_shell_agree(procs, tmp_path, case, writer):
    p = procs("t5267-mark")
    pid = p.pid
    pf = tmp_path / "x.pid"
    pf.write_text(str(pid))
    marker = "t5267-mark"

    def write(pid_, mk):
        if writer == "py":
            pi.write_identity(pf, pid_, mk)
        else:
            subprocess.run(["bash", "-c", f'source "{PID_ALIVE_SH}"; fw_pid_identity_write "$1" "$2" "$3"',
                            "_", str(pf), str(pid_), mk], check=True)

    expect = None
    if case == "same":
        write(pid, marker); expect = 0
    elif case == "reused":
        write_fake_identity(pf, pid, -7, marker); expect = 1
    elif case == "legacy-match":
        expect = 0
    elif case == "legacy-nomatch":
        marker = "something-else"; expect = 1
    elif case == "legacy-nomarker":
        marker = ""; expect = 1
    elif case == "gone":
        write(pid, marker)
        os.kill(pid, signal.SIGKILL); p.wait(5)
        expect = 1
    elif case == "recorded-marker-missing":
        Path(f"{pf}.identity").write_text(
            f"pid={pid}\nstart_ticks={pi.start_ticks(pid)}\nboot_id={pi.boot_id()}\n"
            f"cmd_marker=never-in-cmdline\n")
        expect = 1
    elif case == "previous-boot":
        Path(f"{pf}.identity").write_text(
            f"pid={pid}\nstart_ticks={pi.start_ticks(pid)}\nboot_id=00000000-dead\ncmd_marker=\n")
        expect = 1
    elif case == "identity-for-other-pid":
        # identity names another pid: the legacy rule applies to this one
        Path(f"{pf}.identity").write_text(f"pid=1\nstart_ticks=1\nboot_id=\ncmd_marker=\n")
        expect = 0
    py, sh = _py_check(pf, pid, marker), _sh_check(pf, pid, marker)
    assert (py, sh) == (expect, expect), f"{case}: python={py} shell={sh} expected={expect}"


def test_writers_produce_the_same_record(procs, tmp_path):
    p = procs("t5267-w")
    a, b = tmp_path / "a.pid", tmp_path / "b.pid"
    pi.write_identity(a, p.pid, "t5267-w")
    subprocess.run(["bash", "-c", f'source "{PID_ALIVE_SH}"; fw_pid_identity_write "$1" "$2" "$3"',
                    "_", str(b), str(p.pid), "t5267-w"], check=True)
    assert pi.read_identity(a) == pi.read_identity(b)


def test_no_proc_means_cannot_tell(monkeypatch, tmp_path):
    monkeypatch.setattr(pi, "PROC_ROOT", str(tmp_path / "noproc"))
    assert pi.verdict({"pid": os.getpid(), "start_ticks": None, "cmd_marker": "x"})[0] is None
    r = subprocess.run(["bash", "-c", f'source "{PID_ALIVE_SH}"; fw_pid_same_process "" "$1" x',
                        "_", str(os.getpid())], capture_output=True, text=True,
                       env={**os.environ, "FW_PROC_ROOT": str(tmp_path / "noproc")})
    assert r.returncode == 2


# ── sidecar receiver: stop and stale-code restart ──────────────────────────

def _receiver_triple(pid):
    lifecycle._triple_file_path("pid").write_text(str(pid))
    lifecycle._triple_file_path("port").write_text("1")
    lifecycle._triple_file_path("url").write_text("http://127.0.0.1:1")


def _stop_receiver():
    cli.cmd_receiver_stop(type("A", (), {"quiet": True, "agent": "t5267-agent"})())


def test_receiver_stop_spares_a_reused_pid(proj, procs):
    p = procs("unrelated")
    _receiver_triple(p.pid)
    write_fake_identity(lifecycle.receiver_pid_file(), p.pid)
    _stop_receiver()
    assert alive(p), "receiver stop signalled an unrelated process that reused the pid"
    assert lifecycle.read_triple_file() is None, "stale triple file left behind"
    assert not Path(f"{lifecycle.receiver_pid_file()}.identity").exists()
    assert _events("KILL_REFUSED")


def test_receiver_stop_legacy_pidfile_nonmatching_cmdline_is_spared(proj, procs):
    p = procs("unrelated")
    _receiver_triple(p.pid)            # no identity file: a pid file written before T-5267
    _stop_receiver()
    assert alive(p)


def test_receiver_stop_legacy_pidfile_matching_cmdline_is_stopped(proj, procs):
    p = procs("http_server.py")
    _receiver_triple(p.pid)
    _stop_receiver()
    p.wait(5)
    assert not alive(p)


def test_receiver_stop_real_process_with_identity_is_stopped(proj, procs):
    p = procs("http_server.py")
    lifecycle.write_triple_file(p.pid, 1, "http://127.0.0.1:1")
    assert pi.read_identity(lifecycle.receiver_pid_file())["cmd_marker"] == "http_server.py"
    _stop_receiver()
    p.wait(5)
    assert not alive(p)


class _Stop(Exception):
    pass


def _run_stale_restart(monkeypatch):
    # Stop right after the stale-code branch: nothing further (no real receiver start).
    def halt(*a, **k):
        raise _Stop
    monkeypatch.setattr(cli, "_reclaim_orphan_receivers", halt)
    monkeypatch.setattr(lifecycle, "live_receiver_pids", lambda agent: [])
    with pytest.raises(_Stop):
        cli._start_receiver("t5267-agent", None, True, True)


def test_stale_code_restart_spares_a_reused_pid(proj, procs, monkeypatch):
    p = procs("unrelated")
    _receiver_triple(p.pid)
    write_fake_identity(lifecycle.receiver_pid_file(), p.pid)
    _run_stale_restart(monkeypatch)
    assert alive(p), "stale-code restart signalled an unrelated process that reused the pid"
    assert lifecycle.read_triple_file() is None


def test_stale_code_restart_stops_the_real_receiver(proj, procs, monkeypatch):
    p = procs("http_server.py")
    lifecycle.write_triple_file(p.pid, 1, "http://127.0.0.1:1")
    _run_stale_restart(monkeypatch)
    p.wait(5)
    assert not alive(p)


def test_orphan_reclaim_spares_a_non_receiver(proj, procs, monkeypatch):
    p = procs("unrelated")
    monkeypatch.setattr(lifecycle, "live_receiver_pids", lambda agent: [p.pid])
    monkeypatch.setattr(lifecycle, "process_cwd", lambda pid: proj.resolve())
    monkeypatch.setattr(watcher, "process_started_at", lambda pid: 0.0)
    left = cli._reclaim_orphan_receivers("t5267-agent", proj.resolve(), True)
    assert alive(p) and left == []


def test_orphan_reclaim_stops_a_receiver(proj, procs, monkeypatch):
    p = procs("http_server.py")
    monkeypatch.setattr(lifecycle, "live_receiver_pids", lambda agent: [p.pid])
    monkeypatch.setattr(lifecycle, "process_cwd", lambda pid: proj.resolve())
    monkeypatch.setattr(watcher, "process_started_at", lambda pid: 0.0)
    cli._reclaim_orphan_receivers("t5267-agent", proj.resolve(), True)
    p.wait(5)
    assert not alive(p)


# ── sidecar watcher / supervisor ───────────────────────────────────────────

@pytest.mark.parametrize("which", ["supervisor", "watcher"])
def test_stop_processes_spares_a_reused_pid(proj, procs, which):
    p = procs("unrelated")
    watcher._pidfile(which).write_text(str(p.pid))
    write_fake_identity(watcher._pidfile(which), p.pid)
    stopped = watcher.stop_processes(timeout=1)
    assert alive(p) and which not in stopped
    assert not watcher._pidfile(which).exists(), "stale pid file left behind"


@pytest.mark.parametrize("which", ["supervisor", "watcher"])
def test_stop_processes_legacy_nonmatching_is_spared(proj, procs, which):
    p = procs("unrelated")
    watcher._pidfile(which).write_text(str(p.pid))
    watcher.stop_processes(timeout=1)
    assert alive(p)


@pytest.mark.parametrize("which,marker", [("supervisor", "watcher.py supervise"),
                                          ("watcher", "watcher.py run")])
def test_stop_processes_legacy_matching_is_stopped(proj, procs, which, marker):
    p = procs(*marker.split())
    watcher._pidfile(which).write_text(str(p.pid))
    stopped = watcher.stop_processes(timeout=2)
    p.wait(5)
    assert not alive(p) and stopped.get(which) == p.pid


@pytest.mark.parametrize("which,marker", [("supervisor", "watcher.py supervise"),
                                          ("watcher", "watcher.py run")])
def test_stop_processes_real_process_with_identity_is_stopped(proj, procs, which, marker):
    p = procs(*marker.split())
    watcher._write_pid(which, p.pid)
    assert pi.read_identity(watcher._pidfile(which))["cmd_marker"] == marker
    watcher.stop_processes(timeout=2)
    p.wait(5)
    assert not alive(p)


def _run_supervise_once(monkeypatch):
    monkeypatch.setattr(watcher, "_single_instance", lambda which: object())
    monkeypatch.setattr(watcher, "read_enabled", lambda: None)   # exits the loop at once
    old = {s: signal.getsignal(s) for s in (signal.SIGTERM, signal.SIGINT)}
    try:
        watcher.supervise()
    finally:
        for s, h in old.items():
            signal.signal(s, h)


def test_supervisor_orphan_watcher_spares_a_reused_pid(proj, procs, monkeypatch):
    p = procs("unrelated")
    watcher._pidfile("watcher").write_text(str(p.pid))
    write_fake_identity(watcher._pidfile("watcher"), p.pid)
    _run_supervise_once(monkeypatch)
    assert alive(p)
    assert not watcher._pidfile("watcher").exists()
    assert not _events("ORPHAN_WATCHER_REPLACED")


def test_supervisor_orphan_watcher_real_one_is_replaced(proj, procs, monkeypatch):
    p = procs("watcher.py", "run")
    watcher._write_pid("watcher", p.pid)
    _run_supervise_once(monkeypatch)
    p.wait(5)
    assert not alive(p)
    assert _events("ORPHAN_WATCHER_REPLACED")


# ── Watchtower stop (pid AND its children) ─────────────────────────────────

def _wt_stop(hermetic, tmp_path):
    stub = tmp_path / "stubbin"
    stub.mkdir(exist_ok=True)
    (stub / "ufw").write_text('#!/bin/sh\necho "Status: inactive"\n')
    (stub / "ufw").chmod(0o755)
    env = hermetic.env(PATH=f"{stub}:{os.environ['PATH']}", NO_COLOR="1")
    return subprocess.run([str(WATCHTOWER_SH), "stop"], env=env, cwd=str(hermetic.project),
                          capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)


def _wt_pidfile(hermetic) -> Path:
    w = hermetic.project / ".context" / "working"
    w.mkdir(parents=True, exist_ok=True)
    return w / "watchtower.pid"


def test_watchtower_stop_spares_a_reused_pid_and_its_children(hermetic, tmp_path, procs):
    p = procs("unrelated", child=True)
    pf = _wt_pidfile(hermetic)
    pf.write_text(f"{p.pid}\n")
    write_fake_identity(pf, p.pid, marker="")
    r = _wt_stop(hermetic, tmp_path)
    assert r.returncode == 0, r.stdout + r.stderr
    assert alive(p), "watchtower stop signalled an unrelated process that reused the pid"
    assert alive(p.child_pid), "watchtower stop signalled a child of a reused pid (pkill -P)"
    assert not pf.exists() and not Path(f"{pf}.identity").exists()
    assert "no longer the Watchtower" in r.stdout + r.stderr


def test_watchtower_stop_legacy_nonmatching_is_spared(hermetic, tmp_path, procs):
    p = procs("unrelated", child=True)
    pf = _wt_pidfile(hermetic)
    pf.write_text(f"{p.pid}\n")
    r = _wt_stop(hermetic, tmp_path)
    assert r.returncode == 0, r.stdout + r.stderr
    assert alive(p) and alive(p.child_pid)


def test_watchtower_stop_legacy_matching_is_stopped(hermetic, tmp_path, procs):
    p = procs("-m", "web.app")
    pf = _wt_pidfile(hermetic)
    pf.write_text(f"{p.pid}\n")
    r = _wt_stop(hermetic, tmp_path)
    assert r.returncode == 0, r.stdout + r.stderr
    p.wait(5)
    assert not alive(p)


def test_watchtower_stop_real_process_and_children_are_stopped(hermetic, tmp_path, procs):
    p = procs("-m", "web.app", child=True)
    pf = _wt_pidfile(hermetic)
    pf.write_text(f"{p.pid}\n")
    subprocess.run(["bash", "-c", f'source "{PID_ALIVE_SH}"; fw_pid_identity_write "$1" "$2" web.app',
                    "_", str(pf), str(p.pid)], check=True)
    r = _wt_stop(hermetic, tmp_path)
    assert r.returncode == 0, r.stdout + r.stderr
    p.wait(5)
    _reap_wait(p.child_pid)
    assert not alive(p)
    assert not lifecycle.pid_alive(p.child_pid) or \
        (Path(f"/proc/{p.child_pid}/stat").read_text().rsplit(")", 1)[1].split()[0] == "Z")
    assert not Path(f"{pf}.identity").exists()


# ── be-reachable stop (state-file pid) ─────────────────────────────────────

def _be_stop(tmp_path, state: Path):
    env = {**os.environ, "BE_REACHABLE_STATE": str(state), "BE_REACHABLE_STATE_DIR": str(tmp_path)}
    return subprocess.run(["bash", str(BE_REACHABLE), "stop"], env=env, capture_output=True,
                          text=True, timeout=30, stdin=subprocess.DEVNULL)


def _be_state(path: Path, pid: int, start_ticks: str | None):
    st = "" if start_ticks is None else f'  "start_ticks": "{start_ticks}",\n'
    path.write_text("{\n" f'  "agent_id": "t5267",\n  "pid": {pid},\n{st}  "role": "x"\n' "}\n")


def test_be_reachable_stop_spares_a_reused_pid(tmp_path, procs):
    p = procs("unrelated")
    state = tmp_path / "be.state"
    _be_state(state, p.pid, str(pi.start_ticks(p.pid) - 3))
    r = _be_stop(tmp_path, state)
    assert r.returncode == 0, r.stdout + r.stderr
    assert alive(p) and not state.exists()


def test_be_reachable_stop_legacy_nonmatching_is_spared(tmp_path, procs):
    p = procs("unrelated")
    state = tmp_path / "be.state"
    _be_state(state, p.pid, None)
    _be_stop(tmp_path, state)
    assert alive(p)


def test_be_reachable_stop_stops_its_listener(tmp_path, procs):
    p = procs("listener-heartbeat.sh")
    state = tmp_path / "be.state"
    _be_state(state, p.pid, str(pi.start_ticks(p.pid)))
    _be_stop(tmp_path, state)
    p.wait(5)
    assert not alive(p)
