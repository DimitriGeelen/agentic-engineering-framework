#!/usr/bin/env python3
"""T-4692: name the files `fw upgrade` left for the consumer to commit.

An upgrade creates governance files (e.g. .context/.gitignore, T-4684) and
rewrites tracked ones, then ends without saying any of them need committing.
This compares the target's git-dirty paths before and after the upgrade.

  snapshot <target>            print "<sha1>\\t<path>" for every dirty path
  report <target> <before>     print the paths the upgrade created or changed
                               that git shows untracked/modified, plus one
                               `git add` line. Prints nothing when there are none.

A path dirty before the upgrade is listed only if its content changed. Paths
are root-relative, restricted to the target directory. Non-git targets print
nothing. Vendored `.agentic-framework/` files collapse to one entry.
"""
import hashlib
import os
import shlex
import subprocess
import sys

VENDORED = ".agentic-framework/"


def _git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True)
    return r.stdout if r.returncode == 0 else None


def _dirty(target):
    """{path: (status, sha1)} for dirty paths under target; None if not git."""
    top = _git(target, "rev-parse", "--show-toplevel")
    if top is None:
        return None, None
    top = top.decode().strip()
    prefix = (_git(target, "rev-parse", "--show-prefix") or b"").decode().strip()
    out = _git(top, "status", "--porcelain=v1", "-z", "-uall")
    if out is None:
        return None, None
    found = {}
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
        name = entry[3:].decode("utf-8", "surrogateescape")
        if "\n" in name or "\t" in name or not name.startswith(prefix):
            continue
        path = os.path.join(top, name)
        try:
            if os.path.islink(path):
                data = os.readlink(path).encode("utf-8", "surrogateescape")
            else:
                with open(path, "rb") as f:
                    data = f.read()
            digest = hashlib.sha1(data).hexdigest()
        except OSError:
            digest = "-"
        found[name] = (status, digest)
    return top, found


def snapshot(target):
    _, found = _dirty(target)
    for name, (_, digest) in sorted((found or {}).items()):
        print(f"{digest}\t{name}")
    return 0


def report(target, before_file):
    top, found = _dirty(target)
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
    changed = sorted(n for n, (_, d) in found.items() if before.get(n) != d)
    if not changed:
        return 0
    plain = [n for n in changed if not n.startswith(VENDORED)]
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
    print("  Commit them with:")
    print(f"    cd {shlex.quote(top)} && git add -- {' '.join(shlex.quote(a) for a in add)}")
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "snapshot":
        return snapshot(argv[1])
    if len(argv) == 3 and argv[0] == "report":
        return report(argv[1], argv[2])
    print("usage: upgrade_commit_list.py snapshot <target> | report <target> <before>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
