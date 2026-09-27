#!/usr/bin/env python3
"""T-3126 — attribute each RED bats test to the paths it is about.

Reads a bats TAP stream on stdin. For every `not ok` test, emits one line:

    <declaring-file>|<evidence-path>;<evidence-path>;...

Both fields are repo-relative and may be empty; an entirely empty line means the
test could not be attributed at all, which the caller treats as ref-scoped
(fail safe — an undetermined scope is not a determination that the ref is clean).

Two path classes, deliberately kept apart:

  declaring file  bats's own `# (in test file <path>, line N)` marker. This is
                  where the ASSERTION lives. If it is not in HEAD, the assertion
                  is not in any ref.

  evidence paths  every other repo-relative path the failure block names. This is
                  what the assertion is COMPLAINING ABOUT. `no-untracked-test-files`
                  is the motivating case: the assertion is committed, but every
                  path it lists exists only in the working tree.

The declaring file is excluded from the evidence set on purpose. It appears in
every failure block and is normally committed, so counting it would make the
evidence rule unreachable.

Only paths that resolve to a real file under the given root are emitted, so
prose fragments and version strings cannot be mistaken for paths.
"""
import os
import re
import sys

# A repo-relative path: has a directory separator and an extension. Anchored on
# a word boundary so trailing punctuation in prose does not attach.
PATH_RE = re.compile(r"[A-Za-z0-9_.][A-Za-z0-9_./+-]*/[A-Za-z0-9_./+-]*\.[A-Za-z0-9_]+")
DECL_RE = re.compile(r"\(in test file ([^,)]+)")


def emit(out, root, decl, evidence):
    ev = [p for p in dict.fromkeys(evidence) if p and p != decl]
    out.write("%s|%s\n" % (decl or "", ";".join(ev)))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    rows = []
    decl = None
    evidence = []
    in_red = False

    for raw in sys.stdin:
        line = raw.rstrip("\n")
        if line.startswith("not ok ") or line.startswith("ok "):
            if in_red:
                rows.append((decl, evidence))
            in_red = line.startswith("not ok ")
            decl, evidence = None, []
            continue
        if not in_red or not line.lstrip().startswith("#"):
            continue
        body = line.lstrip().lstrip("#").strip()
        m = DECL_RE.search(body)
        if m:
            cand = m.group(1).strip()
            if os.path.isfile(os.path.join(root, cand)):
                decl = cand
            # The marker line carries nothing else worth harvesting.
            continue
        for cand in PATH_RE.findall(body):
            cand = cand.strip().strip("'\"`,;:")
            if os.path.isfile(os.path.join(root, cand)):
                evidence.append(cand)
    if in_red:
        rows.append((decl, evidence))

    for d, e in rows:
        emit(sys.stdout, root, d, e)


if __name__ == "__main__":
    main()
