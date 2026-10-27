#!/usr/bin/env python3
"""T-4692: name the files `fw upgrade` left for the consumer to commit.

An upgrade creates governance files (e.g. .context/.gitignore, T-4684) and
rewrites tracked ones, then ends without saying any of them need committing.
This compares the target's git-dirty paths before and after the upgrade.

  snapshot <target>                  print "<sha1>\\t<path>" for every dirty path
  report <target> <before> [<wrote>] print the paths the upgrade created or changed
                                     that git shows untracked/modified, plus one
                                     `git add` line. Prints nothing when there are none.

T-4697: <wrote> is the journal do_upgrade keeps of every path it writes (one per
line, relative to <target> or absolute; a trailing "/" covers a directory). When
given, a path is listed only if the journal names it: a file another process
wrote during the upgrade window changed too, and must never be offered for
`git add`. A path dirty before the upgrade is listed only if its content changed,
or (T-4712) it is a vendored file holding what this run's vendor wrote. Paths
are root-relative, restricted to the target directory. Non-git targets print
nothing. Vendored `.agentic-framework/` files collapse to one entry.

T-4723: the snapshot uses normal untracked mode (a wholly untracked directory is
one entry, never read) and the report expands only the journal's paths, so the
work scales with what the upgrade wrote, not with the tree (a home-directory
consumer has ~700 k untracked files). A collapsed directory holding at most
DIR_CAP files is expanded (EXPAND_BUDGET in total), so a small untracked tree
such as a fresh .agentic-framework/ still compares file by file; a bigger one
stays one entry and a journalled file inside it counts as new. Files are hashed
in chunks; one above BIG is recorded by size and mtime instead of read.
"""
import hashlib
import json
import os
import shlex
import subprocess
import sys

VENDORED = ".agentic-framework/"
STAMP = ".fw-vendor-stamp.json"
UPSTREAM = ".upstream"
CHUNK = 1 << 20
BIG = 64 << 20
DIR_CAP = 5000
EXPAND_BUDGET = 20000


def _git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True)
    return r.stdout if r.returncode == 0 else None


def _digest(path, algo):
    """Chunked content hash of path; "stat:<size>:<mtime_ns>" above BIG."""
    st = os.stat(path)
    if st.st_size > BIG:
        return f"stat:{st.st_size}:{st.st_mtime_ns}"
    h = hashlib.new(algo)
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(CHUNK), b""):
            h.update(block)
    return h.hexdigest()


def _dirty(target, pathspecs=None):
    """{path: (status, sha1)} for dirty paths under target; None if not git.

    pathspecs None: normal untracked mode (snapshot). A list: every untracked
    file, but only under those top-relative paths (report, T-4723)."""
    top = _git(target, "rev-parse", "--show-toplevel")
    if top is None:
        return None, None
    top = top.decode().strip()
    prefix = (_git(target, "rev-parse", "--show-prefix") or b"").decode().strip()
    if pathspecs is None:
        args = ["-unormal"]
    else:
        # ":(top,literal)." matches nothing; the whole tree is a bare ":(top)"
        args = ["-uall", "--"] + [":(top,literal)" + p.rstrip("/") if p.rstrip("/") else ":(top)"
                                  for p in pathspecs]
    out = _git(top, "status", "--porcelain=v1", "-z", *args)
    if out is None:
        return None, None
    entries = list(_entries(out))
    if pathspecs is None:
        budget = EXPAND_BUDGET
        # only git's own entries: an expanded nested repo comes back as "sub/" again
        for k, (status, name) in enumerate(entries[:len(entries)]):
            if status == "??" and name.endswith("/") and budget > 0:
                inner = _expand(top, name, min(DIR_CAP, budget))
                if inner is not None:
                    entries[k:k + 1] = [None]  # placeholder, appended below
                    entries.extend(inner)
                    budget -= len(inner)
    found = {}
    for item in entries:
        if item is None:
            continue
        status, name = item
        if "\n" in name or "\t" in name or not name.startswith(prefix):
            continue
        path = os.path.join(top, name)
        try:
            if os.path.islink(path):
                digest = hashlib.sha1(os.readlink(path).encode("utf-8", "surrogateescape")).hexdigest()
            elif name.endswith("/"):
                digest = "dir"  # collapsed untracked directory: never read
            else:
                digest = _digest(path, "sha1")
        except OSError:
            digest = "-"
        found[name] = (status, digest)
    return top, found


def _entries(out):
    """(status, name) from `git status --porcelain=v1 -z` output."""
    parts = out.split(b"\0")
    i = 0
    while i < len(parts):
        entry = parts[i]
        i += 1
        if len(entry) < 4:
            continue
        status = entry[:2].decode()
        if status[0] in "RC":
            i += 1  # -z puts the rename source in the next field
        yield status, entry[3:].decode("utf-8", "surrogateescape")


def _expand(top, name, cap):
    """The untracked files under collapsed dir `name`, or None past `cap`.

    Streams git's output and stops it at the cap, so a directory holding
    hundreds of thousands of files costs `cap` entries, not a full listing."""
    proc = subprocess.Popen(
        ["git", "-C", top, "status", "--porcelain=v1", "-z", "-uall", "--",
         ":(top,literal)" + name.rstrip("/")],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    buf, count = b"", 0
    try:
        for block in iter(lambda: proc.stdout.read(65536), b""):
            buf += block
            count += block.count(b"\0")
            if count > cap:
                return None
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.stdout.close()
        proc.wait()
    if proc.returncode != 0:
        return None
    return list(_entries(buf))


def snapshot(target):
    _, found = _dirty(target)
    for name, (_, digest) in sorted((found or {}).items()):
        print(f"{digest}\t{name}")
    return 0


def _journal(target, top, wrote_file):
    """(exact paths, directory prefixes) the upgrade recorded, top-relative."""
    exact, prefixes = set(), []
    base = os.path.realpath(target)
    real_top = os.path.realpath(top)
    try:
        with open(wrote_file, encoding="utf-8", errors="surrogateescape") as f:
            lines = f.read().splitlines()
    except OSError:
        return exact, prefixes
    for entry in lines:
        entry = entry.strip()
        if not entry:
            continue
        is_dir = entry.endswith("/")
        path = os.path.normpath(os.path.join(base, entry.rstrip("/")))
        # resolve symlinked parents (a /tmp alias) but not the entry itself
        path = os.path.join(os.path.realpath(os.path.dirname(path)), os.path.basename(path))
        rel = os.path.relpath(path, real_top)
        if rel == os.pardir or rel.startswith(os.pardir + os.sep):
            continue
        if is_dir:
            prefixes.append("" if rel == os.curdir else rel + "/")
        else:
            exact.add(rel)
    return exact, prefixes


def _vendor_wrote(top):
    """T-4712: predicate for dirty vendored paths that hold what the vendor wrote.

    A consumer an earlier upgrade left uncommitted already carries the vendored
    diff, and a re-run writes the same bytes, so "content changed" drops it. The
    vendor stamp (T-3850) holds the sha256 of every file the vendor wrote: a file
    matching it, a deletion of a path it no longer lists, or the stamp itself is
    the vendor's work. A kept-local or locally edited file does not match."""
    try:
        with open(os.path.join(top, VENDORED, STAMP), encoding="utf-8") as f:
            files = json.load(f).get("files") or {}
    except (OSError, ValueError, AttributeError):
        return lambda name, status: False

    def wrote(name, status):
        rel = name[len(VENDORED):]
        if not name.startswith(VENDORED) or not rel:
            return False
        if rel == STAMP:
            return True
        path = os.path.join(top, name)
        if "D" in status and not os.path.lexists(path):
            return rel not in files
        try:
            if os.path.islink(path):
                digest = "link:" + os.readlink(path)
            else:
                digest = _digest(path, "sha256")
        except OSError:
            return False
        return files.get(rel) == digest
    return wrote


def report(target, before_file, wrote_file=None):
    if wrote_file is None:
        top, found = _dirty(target, [""])
    else:
        top = _git(target, "rev-parse", "--show-toplevel")
        if top is None:
            return 0
        top = top.decode().strip()
        exact, prefixes = _journal(target, top, wrote_file)
        if not exact and not prefixes:
            return 0
        _, found = _dirty(target, sorted(exact) + prefixes)
        found = {n: v for n, v in (found or {}).items()
                 if n in exact or any(n.startswith(p) for p in prefixes)}
    if not found:
        return 0
    before = {}
    try:
        with open(before_file, encoding="utf-8", errors="surrogateescape") as f:
            for line in f:
                digest, _, name = line.rstrip("\n").partition("\t")
                if name:
                    before[name] = digest
    except OSError:
        pass
    vendor_wrote = _vendor_wrote(top)
    changed = sorted(n for n, (st, d) in found.items()
                     if before.get(n) != d or vendor_wrote(n, st))
    if not changed:
        if wrote_file is not None:
            # T-4717: paths this run wrote are uncommitted, but each was already
            # dirty with the same bytes before it. Say so rather than print nothing.
            print("")
            print(f"  Upgrade file list: {len(found)} path(s) this upgrade wrote are still"
                  " uncommitted but were already dirty, unchanged, before it ran."
                  f" Check: cd {shlex.quote(top)} && git status")
        return 0
    # T-4814: a <file>.upstream is a template copy to resolve and delete, not to
    # commit; do_upgrade names each one with its diff after this list.
    upstream = [n for n in changed if n.endswith(UPSTREAM) and not n.startswith(VENDORED)]
    plain = [n for n in changed if not n.startswith(VENDORED) and n not in upstream]
    vendored = [n for n in changed if n.startswith(VENDORED)]
    print("")
    print("  Files this upgrade created or changed (not committed yet):")
    for name in plain:
        state = "new" if found[name][0] == "??" else "modified"
        print(f"    {state:<9} {name}")
    add = list(plain)
    if vendored:
        print(f"    {'vendored':<9} {VENDORED} ({len(vendored)} file(s))")
        add.append(VENDORED)
    if add:
        print("  Commit them with:")
        print(f"    cd {shlex.quote(top)} && git add -- {' '.join(shlex.quote(a) for a in add)}")
    if upstream:
        print(f"  {len(upstream)} {UPSTREAM} template cop{'y is' if len(upstream) == 1 else 'ies are'}"
              " left out of the git add line on purpose: resolve each, then delete it.")
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "snapshot":
        return snapshot(argv[1])
    if len(argv) in (3, 4) and argv[0] == "report":
        return report(*argv[1:])
    print("usage: upgrade_commit_list.py snapshot <target> | report <target> <before> [<wrote>]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
