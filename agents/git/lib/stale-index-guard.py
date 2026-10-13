#!/usr/bin/env python3
"""Stale-index guard (T-4167) — refuse a commit that reverts committed task state.

A writer that leaves the index holding an OLDER blob for a `.tasks/**` or
`.context/episodic/**` path (a scratch index built before a later commit, a
`git mv` on a stale entry, a `git commit --only` over a file the index never
saw updated) turns the next ordinary commit into a silent revert: the file goes
back to a version that was already superseded, and nobody typed anything that
looks like a revert. Origin: ring20-manager T-2215 (msg 05d50237) — decided
inceptions reverted to their pre-decision state by an unrelated later commit.

The check, per staged path under a governed prefix:

    staged blob != HEAD's blob for that path        (it is a change)
    AND staged blob == some OLDER committed version (the change is backwards)

For a rename (`git mv active/T-X completed/T-X`), "that path" is the rename
SOURCE: the stale blob arriving at the new name matches an older version of the
old name. A re-added path is checked against its own history.

It reads the index git is about to commit: every git call inherits
GIT_INDEX_FILE, which git sets for hooks when it commits from a temporary index
(`git commit --only`, `git commit <paths>`, a scratch index). Never unset it.

Exit 0 = nothing qualifies (or override), 1 = refused, 0 with a WARNING when git
itself cannot answer (a guard must not block every commit on its own failure).

Override: FW_ALLOW_STALE_INDEX=1 git commit ...   (Tier-2, logged to
.context/working/.gate-bypass-log.yaml). Not a general --no-verify: the other
pre-commit gates still run.
"""
import datetime
import os
import subprocess
import sys

GOVERNED = (".tasks/", ".context/episodic/")
OVERRIDE = "FW_ALLOW_STALE_INDEX"
EXACT_MAX = 16


def git(*args, env=None):
    return subprocess.run(["git", "-c", "core.quotepath=off", *args],
                          capture_output=True, text=True, env=env)


def governed(path):
    return path.startswith(GOVERNED)


def staged_changes():
    """Yield (status, history_path, path, head_blob, staged_blob) for governed paths."""
    r = git("diff-index", "--cached", "-M", "--raw", "-z", "--no-abbrev", "HEAD")
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or "git diff-index failed")
    fields = r.stdout.split("\0")
    added, deleted = [], []
    i = 0
    while i < len(fields):
        meta = fields[i]
        if not meta.startswith(":"):
            i += 1
            continue
        old_sha, new_sha, status = meta[1:].split(" ", 4)[2:]
        kind = status[0]
        if kind in "RC":
            src, dst = fields[i + 1], fields[i + 2]
            i += 3
        else:
            src = dst = fields[i + 1]
            i += 2
        if not governed(dst):
            continue
        if kind == "D":
            deleted.append(dst)
            continue
        if kind == "C":
            continue  # source still exists unchanged; a copy reverts nothing
        if kind == "R":
            # Pure rename of HEAD's content is the normal move; only a rename
            # that also changes content can carry an older blob.
            if new_sha == old_sha:
                continue
            yield kind, src, dst, old_sha, new_sha
        elif kind == "M":
            yield kind, dst, dst, old_sha, new_sha
        elif kind == "A":
            added.append((dst, new_sha))
    # An add is checked against its own history and against any governed path
    # deleted in the same commit under the same file name: the active <-> completed
    # move, which -M misses when the content changed too much to pair (L-573:
    # small files, or a stale blob far from HEAD's).
    for dst, new_sha in added:
        base = os.path.basename(dst)
        for src in [dst] + [d for d in deleted if os.path.basename(d) == base]:
            yield "R" if src != dst else "A", src, dst, None, new_sha


def history(paths):
    """Map path -> {blob: commit} over HEAD's history (most recent commit wins)."""
    # Pathspec matching is per-entry x per-pathspec: a few exact paths walk the
    # history in about a second, 2000 of them did not finish in four minutes. Past
    # EXACT_MAX, walk the governed prefixes once (bounded, ~4s on 11k commits) and
    # keep only the wanted paths. Measured in T-4167 ## Decisions.
    wanted = set(paths)
    spec = sorted(wanted) if len(wanted) <= EXACT_MAX else [p.rstrip("/") for p in GOVERNED]
    env = dict(os.environ, GIT_LITERAL_PATHSPECS="1")
    r = git("log", "--no-renames", "--raw", "--no-abbrev", "--format=commit %H",
            "HEAD", "--", *spec, env=env)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or "git log failed")
    seen = {}
    commit = None
    for line in r.stdout.splitlines():
        if line.startswith("commit "):
            commit = line[7:]
        elif line.startswith(":"):
            meta, _, path = line.partition("\t")
            parts = meta[1:].split(" ")
            blob = parts[3]
            if set(blob) == {"0"} or path not in wanted:
                continue  # deletion post-image, or a path we were not asked about
            seen.setdefault(path, {}).setdefault(blob, commit)
    return seen


def merge_head_blob(path):
    r = git("rev-parse", "-q", "--verify", "MERGE_HEAD:" + path)
    return r.stdout.strip() if r.returncode == 0 else None


def log_bypass(root, hits):
    logf = os.path.join(root, ".context", "working", ".gate-bypass-log.yaml")
    if not os.path.isdir(os.path.dirname(logf)):
        return
    task = ""
    try:
        with open(os.path.join(root, ".context", "working", "focus.yaml")) as f:
            for line in f:
                if line.startswith("current_task:"):
                    task = line.split(":", 1)[1].strip().strip("'\"")
    except OSError:
        pass
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    paths = ", ".join(h[0] for h in hits)
    with open(logf, "a") as f:
        f.write(f"- timestamp: '{ts}'\n")
        f.write(f"  task: '{task}'\n")
        f.write(f"  flag: '{OVERRIDE}=1'\n")
        f.write("  caller: 'pre-commit stale-index-guard (T-4167)'\n")
        f.write("  tier: 2\n")
        f.write(f"  paths: '{paths.replace(chr(39), chr(39) * 2)}'\n")


def main():
    root = os.environ.get("PROJECT_ROOT") or git("rev-parse", "--show-toplevel").stdout.strip()
    if git("rev-parse", "-q", "--verify", "HEAD").returncode != 0:
        return 0  # initial commit: there is no history to revert to
    try:
        cands = list(staged_changes())
        if not cands:
            return 0
        hist = history({c[1] for c in cands})
    except RuntimeError as e:
        print(f"WARNING: stale-index guard (T-4167) could not run: {e}", file=sys.stderr)
        return 0

    hits = []
    for kind, hpath, path, head_blob, blob in cands:
        older = hist.get(hpath, {})
        if blob not in older or any(h[0] == path for h in hits):
            continue
        if head_blob is None and hpath != path:
            r = git("rev-parse", "-q", "--verify", "HEAD:" + hpath)
            head_blob = r.stdout.strip() if r.returncode == 0 else None
        if blob == head_blob:
            continue  # carries HEAD's own content: a move, not a revert
        if merge_head_blob(path) == blob:
            continue  # resolving a merge by taking the other side is a choice
        hits.append((path, hpath, older[blob][:12], kind))
    if not hits:
        return 0

    if os.environ.get(OVERRIDE) == "1":
        print(f"WARN: stale-index guard bypassed via {OVERRIDE}=1 (Tier-2, logged) — "
              f"{len(hits)} path(s) reverted to an older committed version", file=sys.stderr)
        log_bypass(root, hits)
        return 0

    print("", file=sys.stderr)
    print("ERROR: Commit blocked — staged task/episodic file is an OLDER committed version (T-4167):",
          file=sys.stderr)
    for path, hpath, commit, kind in hits:
        src = f" (renamed from {hpath})" if hpath != path else ""
        print(f"  {path}{src}: staged blob matches {hpath} as of {commit}, not HEAD", file=sys.stderr)
    print("", file=sys.stderr)
    print("The index holds a stale copy: committing it would silently undo later commits.",
          file=sys.stderr)
    print("Refresh the index from the working tree:  git add <path>", file=sys.stderr)
    print("  or from HEAD (discards the stale entry): git reset -q HEAD -- <path>", file=sys.stderr)
    print("Deliberate revert:  FW_ALLOW_STALE_INDEX=1 git commit ...   (Tier-2, logged)",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
