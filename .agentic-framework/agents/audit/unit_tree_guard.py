#!/usr/bin/env python3
"""unit_tree_guard.py — T-4523: did the unit suite change the checkout it ran in?

A clean-room run of tests/unit (ring20, Ubuntu 24.04) left ~146 tracked files
modified or deleted in the clone it ran in. Tests that write into the real tree
instead of a temp copy mutate whatever checkout runs them, the shared
development checkout included, and nothing noticed: the runner graded tests,
never the tree they ran against.

The runner snapshots the git working tree before the tests and again after, and
compares the two. A snapshot maps every path `git status` reports (tracked
changes and untracked files, ignored files excluded) to its status code plus
the blob hash of its current content, so a file that was already dirty and is
written again by a test still counts as changed.

    snapshot REPO OUT [--exclude PATH ...]   write the snapshot (JSON) to OUT
    state SNAPSHOT                           print clean | dirty
    diff BEFORE AFTER                        print "XY path" per changed path

Excludes are paths (absolute, or relative to the repo top) whose subtree is
left out: the runner's own report directory and lock live inside the tree by
default. Exit 0 always for snapshot/state/diff on success; 2 on usage error.
Outside a git repo, snapshot writes {"git": false} and state prints unknown.
"""
import json
import os
import subprocess
import sys


def _git(repo, *args, stdin=None):
    return subprocess.run(["git", "-C", repo, *args], input=stdin,
                          capture_output=True, check=False)


def _rel_excludes(top, excludes):
    out = []
    for e in excludes:
        if not e:
            continue
        p = os.path.realpath(e if os.path.isabs(e) else os.path.join(top, e))
        rel = os.path.relpath(p, top)
        if rel == "." or rel.startswith(".."):
            continue  # the whole repo, or outside it: nothing to leave out
        out.append(rel.rstrip("/"))
    return out


def snapshot(repo, excludes):
    top_r = _git(repo, "rev-parse", "--show-toplevel")
    if top_r.returncode != 0:
        return {"git": False}
    top = os.path.realpath(top_r.stdout.decode().strip())
    st = _git(top, "-c", "core.quotepath=off", "status", "--porcelain=v1", "-z",
              "--untracked-files=all", "--no-renames")
    if st.returncode != 0:
        return {"git": False}
    skip = _rel_excludes(top, excludes)
    entries = {}
    for rec in st.stdout.decode("utf-8", "surrogateescape").split("\0"):
        if len(rec) < 4:
            continue
        code, path = rec[:2], rec[3:]
        if any(path == s or path.startswith(s + "/") for s in skip):
            continue
        entries[path] = code
    # Content hash of every listed path that still exists as a file, so a second
    # write to an already-dirty file is visible. Deleted paths hash as "-".
    files = [p for p in entries if os.path.isfile(os.path.join(top, p))
             and not os.path.islink(os.path.join(top, p))]
    hashes = {}
    if files:
        h = _git(top, "hash-object", "--no-filters", "--stdin-paths",
                 stdin="\n".join(files).encode("utf-8", "surrogateescape") + b"\n")
        if h.returncode == 0:
            hashes = dict(zip(files, h.stdout.decode().split()))
    for p in entries:
        full = os.path.join(top, p)
        if os.path.islink(full):
            hashes[p] = "link:" + os.readlink(full)
    return {"git": True, "top": top, "excludes": skip,
            "entries": {p: [c, hashes.get(p, "-")] for p, c in entries.items()}}


def changed(before, after):
    if not before.get("git") or not after.get("git"):
        return []
    b, a = before.get("entries", {}), after.get("entries", {})
    out = []
    for p in sorted(set(b) | set(a)):
        if b.get(p) != a.get(p):
            # "->" = the path is back to its committed state: something rewrote
            # or restored a file that was dirty when the run began.
            out.append("%s %s" % (a[p][0] if p in a else "->", p))
    return out


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "snapshot" and len(argv) >= 4:
        rest, excludes = argv[4:], []
        while rest:
            if rest[0] == "--exclude" and len(rest) > 1:
                excludes.append(rest[1])
                rest = rest[2:]
            else:
                print("unit_tree_guard: unknown argument %r" % rest[0], file=sys.stderr)
                return 2
        snap = snapshot(argv[2], excludes)
        with open(argv[3], "w") as fh:
            json.dump(snap, fh)
        return 0
    if cmd == "state" and len(argv) == 3:
        snap = json.load(open(argv[2]))
        if not snap.get("git"):
            print("unknown")
        else:
            print("dirty" if snap.get("entries") else "clean")
        return 0
    if cmd == "diff" and len(argv) == 4:
        for line in changed(json.load(open(argv[2])), json.load(open(argv[3]))):
            print(line)
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
