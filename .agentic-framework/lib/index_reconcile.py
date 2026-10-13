#!/usr/bin/env python3
"""T-4166 / G-114: reset "armed" stale index entries to HEAD (index only).

Watchtower commits an operator decision through a scratch index (T-2708). Before
T-4081 the real index kept the pre-decision blobs, so the next ordinary commit
wrote them back and reverted the decision. T-4081/T-4127 are forward-only: a
consumer that decided BEFORE upgrading still carries those staged entries.

An entry under .tasks/ or .context/episodic/ is ARMED when it differs from HEAD and
  * its staged blob equals the blob of that path (or its active<->completed twin) in
    an EARLIER commit on HEAD's history, i.e. it is an old version coming back; or
  * it stages the deletion of an episodic that HEAD has; or
  * it stages the deletion of a task file whose twin is armed (the other half of a
    reverted active<->completed move).
A staged blob never seen in history is the user's own edit and is left alone.
Reconcile resets only those index entries to HEAD. The working tree is never touched.

Usage: index_reconcile.py [--repo DIR] [--apply] [--quiet]
Exit: 0 nothing armed (or all reset with --apply), 2 armed entries found (dry-run),
      3 git unreadable.
"""
import argparse
import subprocess
import sys

TASKS = ".tasks/"
EPISODIC = ".context/episodic/"
SCOPE = (".tasks", ".context/episodic")


def _git(repo, *args, inp=None):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True,
                       input=inp, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or "git " + " ".join(args))
    return r.stdout


def twin(path):
    if path.startswith(".tasks/active/"):
        return ".tasks/completed/" + path[len(".tasks/active/"):]
    if path.startswith(".tasks/completed/"):
        return ".tasks/active/" + path[len(".tasks/completed/"):]
    return None


def _in_scope(path):
    return path.startswith(TASKS) or path.startswith(EPISODIC)


def _staged(repo):
    """{path: status} for index-vs-HEAD differences in scope (no rename detection)."""
    out = _git(repo, "diff", "--cached", "--name-status", "-z", "--no-renames", "HEAD",
               "--", *SCOPE)
    parts = out.split("\0")
    res = {}
    for i in range(0, len(parts) - 1, 2):
        status, path = parts[i], parts[i + 1]
        if _in_scope(path):
            res[path] = status[0]
    return res


def _index_blob(repo, path):
    out = _git(repo, "ls-files", "-s", "-z", "--", ":(literal)" + path)
    for rec in out.split("\0"):
        if rec:
            return rec.split()[1]
    return None


def _history_blobs(repo, path):
    """Blob ids of `path` in every commit on HEAD's history that touched it."""
    commits = _git(repo, "log", "--format=%H", "HEAD", "--", ":(literal)" + path).split()
    if not commits:
        return set()
    spec = "".join(f"{c}:{path}\n" for c in commits)
    out = _git(repo, "cat-file", "--batch-check=%(objectname) %(objecttype)", inp=spec)
    return {ln.split()[0] for ln in out.splitlines()
            if len(ln.split()) == 2 and ln.split()[1] == "blob"}


def _head_has(repo, path):
    r = subprocess.run(["git", "-C", repo, "cat-file", "-e", "HEAD:" + path],
                       capture_output=True)
    return r.returncode == 0


def find_armed(repo):
    """[(kind, path)] of armed entries. kind: old-version | episodic-deleted | move-undone."""
    staged = _staged(repo)
    armed = {}
    for path, st in staged.items():
        if st == "D":
            if path.startswith(EPISODIC):
                armed[path] = "episodic-deleted"
            continue
        blob = _index_blob(repo, path)
        if blob is None:
            continue
        seen = _history_blobs(repo, path)
        t = twin(path)
        if t:
            seen |= _history_blobs(repo, t)
        if blob in seen:
            armed[path] = "old-version"
    # A task file deleted from the index whose twin is an armed old version is the
    # other half of a reverted move: restore it too, or the next commit deletes it.
    for path, st in staged.items():
        if st == "D" and path.startswith(TASKS) and path not in armed:
            t = twin(path)
            if t and armed.get(t) == "old-version" and _head_has(repo, path):
                armed[path] = "move-undone"
    return sorted((k, p) for p, k in armed.items())


def reconcile(repo, paths):
    """Reset index entries for `paths` to HEAD. Index only."""
    for i in range(0, len(paths), 100):
        chunk = [":(literal)" + p for p in paths[i:i + 100]]
        _git(repo, "reset", "-q", "HEAD", "--", *chunk)


def main(argv=None):
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    ap.add_argument("--repo", default=".")
    ap.add_argument("--apply", action="store_true", help="reset armed entries (default: report only)")
    ap.add_argument("--quiet", action="store_true", help="print nothing when clean")
    a = ap.parse_args(argv)
    try:
        armed = find_armed(a.repo)
        if a.apply and armed:
            reconcile(a.repo, [p for _, p in armed])
    except (RuntimeError, OSError, subprocess.SubprocessError) as e:
        print(f"index-reconcile: git unreadable: {e}", file=sys.stderr)
        return 3
    if not armed:
        if not a.quiet:
            print("index-reconcile: no armed index entries")
        return 0
    verb = "RESET" if a.apply else "ARMED"
    for kind, path in armed:
        print(f"{verb} {kind} {path}")
    if a.apply:
        print(f"index-reconcile: reset {len(armed)} index entr{'y' if len(armed) == 1 else 'ies'} to HEAD (working tree untouched)")
        return 0
    print(f"index-reconcile: {len(armed)} armed index entr{'y' if len(armed) == 1 else 'ies'} — the next commit would revert committed work")
    return 2


if __name__ == "__main__":
    sys.exit(main())
