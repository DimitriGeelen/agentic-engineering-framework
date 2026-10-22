#!/usr/bin/env python3
"""T-4637 (T-4635 RCA): fragile placement of long-lived agent processes.

Origin. On 2026-10-22 the parent claude-fw session and six TermLink workers died
at once: they lived in a `user-<uid>.slice/session-*.scope` of a user without
linger, and systemd's slice teardown (which cron triggers every minute) timed out
under load and SIGKILLed everything still in the slice. Nothing checked where
those processes live, so the kill looked like an ordinary exit from inside.

A process is FRAGILE when its cgroup (from /proc/<pid>/cgroup) is a session scope
of a user slice, `/user.slice/user-<uid>.slice/session-<id>.scope`, and the uid
OWNING THE SLICE has no linger file. The slice uid is what matters, not the
process owner: `su` from a uid-1000 login leaves root processes in user-1000.slice.
Processes in a service or a dedicated scope (systemd-run --scope), or in a
lingering user's slice, are not fragile. Unreadable pids are skipped.

Watched: claude-fw, Watchtower (pid file), the TermLink hub, tmux servers.

Shared by `fw doctor` ([host] WARN) and agents/audit/audit.sh (WARN), per G-079:
one predicate, two verdict surfaces.

Exit codes: 0 nothing fragile, 1 fragile processes found (one WARN line each kind
and scope), 2 not applicable (no /proc).
Hermetic hooks: --proc-root / FW_PROC_ROOT, --linger-dir / FW_LINGER_DIR.
"""

from __future__ import annotations

import argparse
import json
import os
import pwd
import re
import sys

SESSION_SCOPE_RE = re.compile(r"/user\.slice/user-(\d+)\.slice/(session-[^/]+\.scope)")


def _read(path: str, binary: bool = False):
    try:
        with open(path, "rb" if binary else "r") as fh:
            return fh.read()
    except OSError:
        return None


def cgroup_of(proc_root: str, pid: int) -> str | None:
    """The unified (v2) cgroup path of pid, else the first v1 name=systemd path."""
    text = _read(os.path.join(proc_root, str(pid), "cgroup"))
    if text is None:
        return None
    fallback = None
    for line in text.splitlines():
        parts = line.split(":", 2)
        if len(parts) != 3:
            continue
        if parts[0] == "0" and parts[1] == "":
            return parts[2]
        if parts[1] == "name=systemd" and fallback is None:
            fallback = parts[2]
    return fallback


def user_name(uid: int) -> str:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)


def has_linger(linger_dir: str, uid: int) -> bool:
    return os.path.exists(os.path.join(linger_dir, user_name(uid)))


def classify(cgroup: str | None, linger_dir: str) -> dict | None:
    """Return {uid, user, scope} when cgroup is a non-lingering session scope."""
    if not cgroup:
        return None
    m = SESSION_SCOPE_RE.search(cgroup)
    if not m:
        return None
    uid = int(m.group(1))
    if has_linger(linger_dir, uid):
        return None
    return {"uid": uid, "user": user_name(uid), "scope": m.group(2), "cgroup": cgroup}


def kind_of(proc_root: str, pid: int) -> str | None:
    """Which watched kind pid is, from comm and cmdline; None when not watched."""
    comm = (_read(os.path.join(proc_root, str(pid), "comm")) or "").strip()
    if comm == "tmux: server":
        return "tmux server"
    raw = _read(os.path.join(proc_root, str(pid), "cmdline"), binary=True)
    if not raw:
        return None
    argv = [a.decode("utf-8", "replace") for a in raw.split(b"\0") if a]
    names = [os.path.basename(a) for a in argv[:2]]
    if "claude-fw" in names:
        return "claude-fw"
    if names and names[0] == "termlink" and len(argv) > 1 and argv[1] == "hub":
        return "TermLink hub"
    return None


def scan(proc_root: str, linger_dir: str, watchtower_pids=()) -> list[dict]:
    """Fragile watched processes, grouped by (kind, cgroup)."""
    wt = {int(p) for p in watchtower_pids}
    groups: dict[tuple, dict] = {}
    try:
        entries = os.listdir(proc_root)
    except OSError:
        return []
    for entry in entries:
        if not entry.isdigit():
            continue
        pid = int(entry)
        kind = "Watchtower" if pid in wt else kind_of(proc_root, pid)
        if kind is None:
            continue
        hit = classify(cgroup_of(proc_root, pid), linger_dir)
        if hit is None:
            continue
        g = groups.setdefault((kind, hit["cgroup"]), dict(hit, kind=kind, pids=[]))
        g["pids"].append(pid)
    out = sorted(groups.values(), key=lambda g: (g["kind"], g["cgroup"]))
    for g in out:
        g["pids"].sort()
    return out


def warn_line(g: dict) -> str:
    pids = ",".join(str(p) for p in g["pids"][:5]) + (" …" if len(g["pids"]) > 5 else "")
    return (
        f"{g['kind']} (pid {pids}) lives in {g['scope']} of user {g['user']} (uid {g['uid']}), "
        f"which has no linger — a session teardown can SIGKILL it (T-4635). "
        f"Fix: loginctl enable-linger {g['user']}; durable: start it outside login "
        f"sessions (systemd-run --scope --slice=…, T-4636)"
    )


def _watchtower_pids(pid_files) -> list[int]:
    pids = []
    for f in pid_files or ():
        text = (_read(f) or "").strip()
        if text.isdigit():
            pids.append(int(text))
    return pids


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="WARN when claude-fw, Watchtower, the TermLink hub or a tmux server "
        "lives in a session-*.scope of a user without linger (T-4637).")
    ap.add_argument("--proc-root", default=os.environ.get("FW_PROC_ROOT", "/proc"))
    ap.add_argument("--linger-dir", default=os.environ.get("FW_LINGER_DIR", "/var/lib/systemd/linger"))
    ap.add_argument("--watchtower-pid-file", action="append", default=[])
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if not os.path.isdir(args.proc_root):
        return 2
    groups = scan(args.proc_root, args.linger_dir, _watchtower_pids(args.watchtower_pid_file))
    if args.json:
        print(json.dumps(groups, indent=2))
    else:
        for g in groups:
            print(warn_line(g))
    return 1 if groups else 0


if __name__ == "__main__":
    sys.exit(main())
