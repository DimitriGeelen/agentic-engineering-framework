#!/usr/bin/env python3
"""lib/proc_identity.py — is this pid still the process that wrote the pid file? (T-5267, G-135)

A pid file names a number. After a reboot or a pid wrap that number can belong to an
unrelated process, and a liveness check (`kill -0`, lib/pid-alive.sh, lifecycle.pid_alive)
says yes to it. Every pid-file kill therefore checks IDENTITY first:

  start_ticks  /proc/<pid>/stat field 22 (process start, in clock ticks since boot),
               parsed after the LAST ')' because comm may contain spaces and parens.
               Two processes never share (pid, start_ticks) within one boot.
  boot_id      /proc/sys/kernel/random/boot_id, so a pid file that survived a reboot
               cannot vouch for a process of the next boot with the same start tick.
  cmd_marker   a short substring the caller names (e.g. "web.app", "http_server.py").
               It is recorded only when the cmdline contains it at write time (a
               process that has not exec'd yet, or one run in-process by a test, is
               identified by start_ticks + boot_id alone), and checked when recorded.

The identity is written beside the pid file as `<pidfile>.identity` (key=value lines),
so every existing reader of the bare-pid file keeps working unchanged. The shell mirror
is lib/pid-alive.sh fw_pid_identity_write / fw_pid_same_process; both follow the same
rule and tests/unit/test_t5267_pid_identity.py runs them on the same cases.

Rule (same_process):
  - no /proc on this host (macOS)            -> None  (cannot tell; caller keeps the
                                                       old behaviour and logs it)
  - pid not present                           -> False
  - identity recorded for this pid with start_ticks:
        boot_id recorded and differs          -> False (previous boot)
        start_ticks differ                    -> False (pid reused)
        recorded marker not in cmdline        -> False
        otherwise                             -> True
  - legacy (no identity, or identity for another pid):
        caller's marker given and in cmdline  -> True
        otherwise                             -> False (never a blind kill)

CLI (used by shell callers that prefer the Python implementation):
  proc_identity.py write <pidfile> <pid> <marker>
  proc_identity.py check <pidfile> <pid> <marker>   exit 0 same, 1 different, 2 cannot tell
"""
from __future__ import annotations

import os
import sys

PROC_ROOT = os.environ.get("FW_PROC_ROOT", "/proc")


def identity_path(pid_file) -> str:
    return f"{pid_file}.identity"


def has_proc() -> bool:
    return os.path.isdir(os.path.join(PROC_ROOT, "self")) or os.path.isfile(
        os.path.join(PROC_ROOT, "1", "stat"))


def start_ticks(pid) -> int | None:
    """Field 22 of /proc/<pid>/stat, or None (gone, unreadable, no /proc)."""
    try:
        with open(os.path.join(PROC_ROOT, str(int(pid)), "stat"), encoding="utf-8",
                  errors="replace") as fh:
            rest = fh.read().rsplit(")", 1)[1].split()
        # rest[0] is field 3 (state); field 22 is rest[19]
        return int(rest[19])
    except (OSError, ValueError, IndexError, TypeError):
        return None


def cmdline(pid) -> str | None:
    try:
        with open(os.path.join(PROC_ROOT, str(int(pid)), "cmdline"), "rb") as fh:
            raw = fh.read()
    except (OSError, ValueError, TypeError):
        return None
    return raw.replace(b"\0", b" ").decode("utf-8", "replace").strip()


def boot_id() -> str:
    try:
        with open(os.path.join(PROC_ROOT, "sys", "kernel", "random", "boot_id"),
                  encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return ""


def identity(pid, cmd_marker: str = "") -> dict | None:
    """{pid, start_ticks, boot_id, cmd_marker} for a live pid, or None when unreadable.
    cmd_marker is kept only when the pid's cmdline contains it now."""
    st = start_ticks(pid)
    if st is None:
        return None
    marker = cmd_marker or ""
    if marker and marker not in (cmdline(pid) or ""):
        marker = ""
    return {"pid": int(pid), "start_ticks": st, "boot_id": boot_id(), "cmd_marker": marker}


def write_identity(pid_file, pid, cmd_marker: str = "") -> bool:
    """Write `<pid_file>.identity` atomically. False when there is nothing to record
    (no /proc, or the pid is already gone) — the identity file is then removed so a
    stale one cannot vouch for the new pid."""
    path = identity_path(pid_file)
    rec = identity(pid, cmd_marker)
    if rec is None:
        try:
            os.unlink(path)
        except OSError:
            pass
        return False
    tmp = f"{path}.tmp.{os.getpid()}-{os.urandom(4).hex()}"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(f"pid={rec['pid']}\nstart_ticks={rec['start_ticks']}\n"
                     f"boot_id={rec['boot_id']}\ncmd_marker={rec['cmd_marker']}\n")
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False
    return True


def read_identity(pid_file) -> dict | None:
    try:
        with open(identity_path(pid_file), encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return None
    rec: dict = {}
    for ln in lines:
        k, sep, v = ln.partition("=")
        if sep:
            rec[k.strip()] = v.strip()
    try:
        out = {"pid": int(rec["pid"]), "cmd_marker": rec.get("cmd_marker", ""),
               "boot_id": rec.get("boot_id", "")}
        out["start_ticks"] = int(rec["start_ticks"]) if rec.get("start_ticks") else None
        return out
    except (KeyError, ValueError):
        return None


def remove_identity(pid_file) -> None:
    try:
        os.unlink(identity_path(pid_file))
    except OSError:
        pass


def same_process(record: dict) -> bool | None:
    """True/False/None per the module rule. `record` = {pid, start_ticks|None, cmd_marker}."""
    return verdict(record)[0]


def verdict(record: dict) -> tuple[bool | None, str]:
    """(same_process, reason)."""
    if not has_proc():
        return None, "no /proc on this host: identity cannot be checked"
    pid = _int(record.get("pid"))
    if pid is None or pid <= 0:
        return False, "no pid"
    marker = record.get("cmd_marker") or ""
    now = start_ticks(pid)
    if now is None:
        return False, f"pid {pid} is not running"
    want = record.get("start_ticks")
    if want is not None:
        rec_boot = record.get("boot_id") or ""
        if rec_boot and boot_id() and rec_boot != boot_id():
            return False, f"pid {pid}: pid file is from a previous boot"
        if int(want) != now:
            return False, (f"pid {pid} was reused: start_ticks {now} != recorded {want}")
        if marker:
            cl = cmdline(pid) or ""
            if marker not in cl:
                return False, f"pid {pid} cmdline lacks {marker!r}"
        return True, "identity matches"
    # legacy: no recorded start
    if not marker:
        return False, f"pid {pid}: no recorded identity and no cmdline marker to check"
    cl = cmdline(pid) or ""
    if marker in cl:
        return True, f"legacy pid file: cmdline contains {marker!r}"
    return False, f"legacy pid file: pid {pid} cmdline lacks {marker!r}"


def check_pid_file(pid_file, pid, cmd_marker: str) -> tuple[bool | None, str]:
    """Verdict for killing `pid` read from `pid_file`, expecting `cmd_marker`.
    Uses the recorded identity when it names this pid; otherwise the legacy rule."""
    rec = read_identity(pid_file) if pid_file else None
    if rec is not None and rec["pid"] == _int(pid) and rec.get("start_ticks") is not None:
        return verdict(rec)   # the recorded marker (present at write time), not the caller's
    return verdict({"pid": pid, "start_ticks": None, "cmd_marker": cmd_marker})


def _int(v) -> int | None:
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 4 and argv[0] == "write":
        return 0 if write_identity(argv[1], argv[2], argv[3]) else 1
    if len(argv) == 4 and argv[0] == "check":
        ok, why = check_pid_file(argv[1], argv[2], argv[3])
        print(why)
        return 0 if ok else (2 if ok is None else 1)
    print("usage: proc_identity.py write|check <pidfile> <pid> <marker>", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main())
