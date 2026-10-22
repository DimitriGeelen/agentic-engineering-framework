"""T-4637: fragile-placement classifier against fixture /proc trees (no systemd)."""

from __future__ import annotations

import importlib.util
import os
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("process_placement", ROOT / "lib" / "process_placement.py")
assert _spec is not None and _spec.loader is not None
pp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pp)

SESSION = "0::/user.slice/user-{uid}.slice/session-c1.scope\n"


def _proc(root, pid, cgroup, comm="bash", argv=("bash",)):
    d = root / str(pid)
    d.mkdir(parents=True)
    if cgroup is not None:
        (d / "cgroup").write_text(cgroup)
    (d / "comm").write_text(comm + "\n")
    (d / "cmdline").write_bytes(b"\0".join(a.encode() for a in argv) + b"\0")


def _user(uid):
    return pp.user_name(uid)


def test_session_scope_without_linger_is_fragile(tmp_path):
    hit = pp.classify(SESSION.format(uid=0).split("::")[1].strip(), str(tmp_path))
    assert hit and hit["uid"] == 0 and hit["scope"] == "session-c1.scope"


def test_lingering_user_is_not_fragile(tmp_path):
    (tmp_path / _user(0)).write_text("")
    assert pp.classify("/user.slice/user-0.slice/session-c1.scope", str(tmp_path)) is None


def test_service_and_dedicated_scope_are_not_fragile(tmp_path):
    assert pp.classify("/system.slice/termlink-hub.service", str(tmp_path)) is None
    assert pp.classify("/user.slice/user-0.slice/user@0.service/app.slice/x.scope", str(tmp_path)) is None
    assert pp.classify("/fw.slice/run-u12.scope", str(tmp_path)) is None
    assert pp.classify(None, str(tmp_path)) is None


def test_v1_name_systemd_fallback(tmp_path):
    _proc(tmp_path, 7, "12:memory:/x\n1:name=systemd:/user.slice/user-0.slice/session-9.scope\n")
    assert pp.cgroup_of(str(tmp_path), 7) == "/user.slice/user-0.slice/session-9.scope"


def test_scan_finds_watched_kinds_and_uses_slice_uid(tmp_path):
    proc, linger = tmp_path / "proc", tmp_path / "linger"
    linger.mkdir()
    # slice uid 0 without linger: all four kinds fragile
    _proc(proc, 10, SESSION.format(uid=0), comm="tmux: server", argv=("tmux", "new-session"))
    _proc(proc, 11, SESSION.format(uid=0), argv=("/bin/bash", "/opt/x/.agentic-framework/bin/claude-fw", "-c"))
    _proc(proc, 12, SESSION.format(uid=0), comm="termlink", argv=("/root/.cargo/bin/termlink", "hub", "start"))
    _proc(proc, 13, SESSION.format(uid=0), comm="python3", argv=("python3", "-m", "web.app"))
    # not watched / not fragile
    _proc(proc, 14, SESSION.format(uid=0), argv=("bash",))
    _proc(proc, 15, "0::/system.slice/tmux.service\n", comm="tmux: server")
    _proc(proc, 16, None, comm="tmux: server")  # unreadable cgroup
    _proc(proc, 17, SESSION.format(uid=0), comm="termlink", argv=("termlink", "list"))
    groups = pp.scan(str(proc), str(linger), watchtower_pids=[13])
    kinds = {g["kind"]: g["pids"] for g in groups}
    assert kinds == {"tmux server": [10], "claude-fw": [11], "TermLink hub": [12], "Watchtower": [13]}

    # the same tree under a lingering slice user reports nothing
    (linger / _user(0)).write_text("")
    assert pp.scan(str(proc), str(linger), watchtower_pids=[13]) == []


def test_main_exit_codes_and_fix_text(tmp_path, capsys):
    proc, linger = tmp_path / "proc", tmp_path / "linger"
    linger.mkdir()
    _proc(proc, 10, SESSION.format(uid=0), comm="tmux: server")
    assert pp.main(["--proc-root", str(proc), "--linger-dir", str(linger)]) == 1
    out = capsys.readouterr().out
    assert f"loginctl enable-linger {_user(0)}" in out and "T-4636" in out and "session-c1.scope" in out
    (linger / _user(0)).write_text("")
    assert pp.main(["--proc-root", str(proc), "--linger-dir", str(linger)]) == 0
    assert pp.main(["--proc-root", str(tmp_path / "missing"), "--linger-dir", str(linger)]) == 2


def test_watchtower_pid_file(tmp_path):
    f = tmp_path / "wt.pid"
    f.write_text("4242\n")
    assert pp._watchtower_pids([str(f), str(tmp_path / "nope")]) == [4242]
    assert os.path.exists(f)
