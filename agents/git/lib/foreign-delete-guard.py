#!/usr/bin/env python3
"""Foreign-delete guard (T-4528) — refuse a commit that deletes another task's files.

Two workers share one checkout. Worker B builds a scratch index early
(`GIT_INDEX_FILE=... git read-tree HEAD`), worker A then commits new files, and B
commits from its scratch index later. B's tree is the OLD HEAD plus B's changes
while its parent is the NEW HEAD, so every file A added arrives as a deletion
nobody typed. Origin: 290e149d6 (T-3866) deleted T-4520's conformance suite,
committed 44 s earlier in eac91df2f. The T-4167 stale-index guard did not fire:
it checks staged blobs, and a deletion has none.

The check (commit-msg hook: it is the only hook that sees the message):

    for each path the commit DELETES (renames and active<->completed moves excluded)
        owner = first T-NNN in the subject of the last commit that touched it
        refuse if owner exists, differs from this commit's subject task,
               and the message does not name the owner anywhere

Naming the owning task in the message is the sanctioned way to say "I mean it"
(a decommission, a revert). Override: FW_ALLOW_FOREIGN_DELETE=1 git commit ...
(Tier-2, logged to .context/working/.gate-bypass-log.yaml).

Reads the index git is committing: every git call inherits GIT_INDEX_FILE. Never
unset it. Exit 0 = nothing qualifies, 1 = refused, 0 with a WARNING when git
cannot answer (a guard must not block every commit on its own failure).
"""
import datetime
import os
import re
import subprocess
import sys

OVERRIDE = "FW_ALLOW_FOREIGN_DELETE"
TASK_RE = re.compile(r"T-[0-9]+")


def git(*args):
    return subprocess.run(["git", "-c", "core.quotepath=off", *args],
                          capture_output=True, text=True)


def message(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = [l.rstrip("\n") for l in f if not l.startswith("#")]
    return lines


def staged_deletions():
    r = git("diff-index", "--cached", "-M", "--name-status", "-z", "HEAD")
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or "git diff-index failed")
    fields = r.stdout.split("\0")
    deleted, added = [], set()
    i = 0
    while i < len(fields) and fields[i]:
        kind = fields[i][0]
        if kind in "RC":
            i += 3
            continue
        path = fields[i + 1]
        i += 2
        if kind == "D":
            deleted.append(path)
        elif kind == "A":
            added.add(os.path.basename(path))
    # A task file moving active/ -> completed/ with enough edits that -M does not
    # pair it is a delete + add under the same name: a move, not a deletion.
    return [p for p in deleted if os.path.basename(p) not in added]


def last_subjects(paths):
    """Map path -> subject of the most recent commit (from HEAD) that touched it."""
    wanted, found = set(paths), {}
    # Stream the log without a pathspec and stop as soon as every path is found:
    # per-pathspec matching is what made T-4167's exact walk slow past ~16 paths.
    p = subprocess.Popen(["git", "-c", "core.quotepath=off", "log", "--no-renames",
                          "--name-only", "--format=%x01%s", "HEAD"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                         errors="replace")
    subject = None
    try:
        for line in p.stdout:
            line = line.rstrip("\n")
            if line.startswith("\x01"):
                subject = line[1:]
            elif line in wanted and line not in found:
                found[line] = subject
                if len(found) == len(wanted):
                    break
    finally:
        p.kill()
        p.wait()
    return found


def log_bypass(root, own, hits):
    logf = os.path.join(root, ".context", "working", ".gate-bypass-log.yaml")
    if not os.path.isdir(os.path.dirname(logf)):
        return
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    paths = ", ".join(f"{p} ({o})" for p, o in hits)
    with open(logf, "a") as f:
        f.write(f"- timestamp: '{ts}'\n")
        f.write(f"  task: '{own}'\n")
        f.write(f"  flag: '{OVERRIDE}=1'\n")
        f.write("  caller: 'commit-msg foreign-delete-guard (T-4528)'\n")
        f.write("  tier: 2\n")
        f.write(f"  paths: '{paths.replace(chr(39), chr(39) * 2)}'\n")


def main(argv):
    if len(argv) < 2:
        return 0
    lines = message(argv[1])
    subject = next((l for l in lines if l.strip()), "")
    m = TASK_RE.search(subject)
    if not m:
        return 0
    own = m.group(0)
    named = set(TASK_RE.findall("\n".join(lines)))
    if git("rev-parse", "-q", "--verify", "HEAD").returncode != 0:
        return 0
    try:
        deleted = staged_deletions()
        if not deleted:
            return 0
        subjects = last_subjects(deleted)
    except (RuntimeError, OSError) as e:
        print(f"WARNING: foreign-delete guard (T-4528) could not run: {e}", file=sys.stderr)
        return 0

    hits = []
    for path in deleted:
        om = TASK_RE.search(subjects.get(path) or "")
        if not om:
            continue  # no attributable owner
        owner = om.group(0)
        if owner == own or owner in named:
            continue
        hits.append((path, owner))
    if not hits:
        return 0

    root = os.environ.get("PROJECT_ROOT") or git("rev-parse", "--show-toplevel").stdout.strip()
    if os.environ.get(OVERRIDE) == "1":
        print(f"WARN: foreign-delete guard bypassed via {OVERRIDE}=1 (Tier-2, logged) — "
              f"{len(hits)} file(s) of other tasks deleted by {own}", file=sys.stderr)
        log_bypass(root, own, hits)
        return 0

    owners = sorted({o for _, o in hits})
    print("", file=sys.stderr)
    print(f"ERROR: Commit blocked — {own} deletes files last committed by another task (T-4528):",
          file=sys.stderr)
    for path, owner in hits[:20]:
        print(f"  {path}  (last committed by {owner})", file=sys.stderr)
    if len(hits) > 20:
        print(f"  ... and {len(hits) - 20} more", file=sys.stderr)
    print("", file=sys.stderr)
    print("Usually the index is stale: it was built (read-tree, scratch GIT_INDEX_FILE) before",
          file=sys.stderr)
    print("another worker committed those files, and committing it would silently undo that commit.",
          file=sys.stderr)
    print("Rebuild the index from HEAD, then re-stage only your paths:", file=sys.stderr)
    print("  git read-tree HEAD   (on the scratch index)   or   git reset -q -- <path>",
          file=sys.stderr)
    print(f"Deliberate deletion: name the owning task(s) in the message ({', '.join(owners)}),",
          file=sys.stderr)
    print(f"  or {OVERRIDE}=1 git commit ...   (Tier-2, logged)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
