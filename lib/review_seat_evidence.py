"""Copy the evidence a review brief cites into a harness seat's export (T-4933).

A harness reviewer (codex, opencode, antigravity) runs inside `$WDIR/tree`, a `git archive`
export of the reviewed revision that excludes `.context/` (T-3582). The brief names its
screenshots by `.context/...` paths, so inside the export they did not exist, and opencode
refuses reads outside its working directory: every render judge ended with no verdict.

This copies exactly the files the brief cites, from the two evidence areas only, to the
same relative path inside the export. run.sh runs it after the export and BEFORE the
export is fingerprinted, so the unchanged-export check (T-3986) still covers them.

    python3 lib/review_seat_evidence.py <brief.md> <project_dir> <tree>
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

#: The evidence areas `fw reviewer judge` cites; nothing else under `.context/` is copied.
AREAS = (".context/working/judge-evidence/", ".context/visual/")
_CITED_RE = re.compile(r"`(\.context/[^`\s]+)`")


def cited(brief: str) -> list[str]:
    out: list[str] = []
    for rel in _CITED_RE.findall(brief):
        if rel.startswith(AREAS) and ".." not in Path(rel).parts and rel not in out:
            out.append(rel)
    return out


def copy_cited(brief: str, project: Path, tree: Path) -> list[str]:
    """Copy each cited evidence file; returns the relative paths copied.

    A path that is not a regular file, or that resolves outside its evidence area
    (a symlink out), is skipped."""
    project = project.resolve()
    copied = []
    for rel in cited(brief):
        src = project / rel
        area = next(a for a in AREAS if rel.startswith(a))
        try:
            real = src.resolve(strict=True)
        except OSError:
            continue
        if not real.is_file() or not str(real).startswith(str(project / area)):
            continue
        dst = tree / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(real, dst)
        os.chmod(dst, 0o644)
        copied.append(rel)
    return copied


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    brief, project, tree = Path(argv[0]), Path(argv[1]), Path(argv[2])
    copied = copy_cited(brief.read_text(errors="replace"), project, tree)
    print(f"review-seat-evidence: copied {len(copied)} cited file(s) into the export")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
