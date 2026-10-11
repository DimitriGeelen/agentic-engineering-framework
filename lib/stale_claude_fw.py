#!/usr/bin/env python3
"""List running claude-fw wrapper processes for one project and flag stale ones (T-4069).

bash reads a script incrementally and keeps its own copy of the functions it has
defined, so a claude-fw started before a re-vendor keeps running the old code (a
fix such as T-4032 stays dormant) while `fw upgrade` / `fw vendor` report success.
A wrapper is STALE when its /proc start time is earlier than the mtime of the
script it runs.

A wrapper belongs to the project when the script it runs is the project's
bin/claude-fw or .agentic-framework/bin/claude-fw, or when it runs some other
claude-fw (e.g. an on-PATH copy) with its cwd inside the project.

Usage: stale_claude_fw.py PROJECT_ROOT [--stale-only]
Output, one line per wrapper (tab separated):
    pid  start_epoch  script  script_mtime_epoch  stale(0|1)
Read-only: never signals or touches any process. Exit 0 always.
"""
import os
import sys


def _proc_start(pid, btime, hz):
    with open(f"/proc/{pid}/stat") as f:
        data = f.read()
    # comm may contain spaces/parens: fields after the last ')'
    rest = data[data.rindex(")") + 2:].split()
    return btime + int(rest[19]) / hz, int(rest[1])  # starttime, ppid


def _script_of(argv):
    """The claude-fw script a bash process runs, or None."""
    if not argv or os.path.basename(argv[0]) not in ("bash", "sh"):
        return None
    for a in argv[1:]:
        if a.startswith("-"):
            continue
        return a if os.path.basename(a) == "claude-fw" else None
    return None


def _inside(path, root):
    return path == root or path.startswith(root.rstrip("/") + "/")


def find_wrappers(project):
    project = os.path.realpath(project)
    own = {os.path.join(project, "bin", "claude-fw"),
           os.path.join(project, ".agentic-framework", "bin", "claude-fw")}
    btime = 0
    with open("/proc/stat") as f:
        for line in f:
            if line.startswith("btime"):
                btime = int(line.split()[1])
    hz = os.sysconf("SC_CLK_TCK")
    found = {}
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv = f.read().decode(errors="replace").split("\0")
            script = _script_of(argv)
            if not script:
                continue
            cwd = os.path.realpath(os.readlink(f"/proc/{pid}/cwd"))
            if not os.path.isabs(script):
                script = os.path.join(cwd, script)
            script = os.path.realpath(script)
            if script not in own and not _inside(cwd, project):
                continue
            start, ppid = _proc_start(pid, btime, hz)
            mtime = os.stat(script).st_mtime
        except (OSError, ValueError, IndexError):
            continue  # process gone, or not readable
        found[int(pid)] = (int(pid), start, script, mtime, ppid)
    out = []
    for pid, (p, start, script, mtime, ppid) in sorted(found.items()):
        parent = found.get(ppid)
        if parent and parent[2] == script:
            continue  # a forked subshell of the wrapper, not a second wrapper
        out.append((p, start, script, mtime, 1 if start < mtime else 0))
    return out


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 0
    stale_only = "--stale-only" in argv
    for p, start, script, mtime, stale in find_wrappers(argv[0]):
        if stale_only and not stale:
            continue
        print(f"{p}\t{int(start)}\t{script}\t{int(mtime)}\t{stale}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
