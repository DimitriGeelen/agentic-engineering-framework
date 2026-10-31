#!/usr/bin/env python3
"""Tell old framework text from a consumer's own lines in CLAUDE.md governance (T-4894).

`fw upgrade` step 1 refuses when rebuilding CLAUDE.md would delete governance lines that
are not in the new template (T-4232). Its only exemption is a section identical to the
template the project was LAST vendored from, so a project whose governance predates even
that (0506: an earlier re-vendor never refreshed CLAUDE.md) was told 15 lines of verbatim
framework text were local edits that "would be deleted".

    governance_known.py filter <framework_root>   < at-risk lines
        prints the lines no version of lib/templates/claude-project.md (renames followed)
        ever contained, i.e. the consumer's own. With no git history to read (a shallow or
        non-git framework copy) every line is printed: no exemption is better than a wrong
        one. The count of lines set aside goes to stderr as `known=N`.
"""

from __future__ import annotations

import subprocess
import sys

TEMPLATE = "lib/templates/claude-project.md"


def _git(root: str, *args: str) -> str | None:
    try:
        r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def known_lines(root: str) -> set[str]:
    """Every line any committed version of the template ever held (stripped of the newline)."""
    log = _git(root, "log", "--follow", "--format=%H", "--name-only", "--", TEMPLATE)
    if not log:
        return set()
    seen: set[str] = set()
    sha = None
    for line in log.splitlines():
        line = line.strip()
        if not line:
            continue
        if len(line) == 40 and all(c in "0123456789abcdef" for c in line):
            sha = line
            continue
        if sha:
            body = _git(root, "show", f"{sha}:{line}")
            if body:
                seen.update(body.splitlines())
            sha = None
    return seen


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[0] != "filter":
        print(__doc__, file=sys.stderr)
        return 2
    lines = sys.stdin.read().splitlines()
    known = known_lines(argv[1])
    out = [ln for ln in lines if ln not in known]
    for ln in out:
        print(ln)
    print(f"known={len(lines) - len(out)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
