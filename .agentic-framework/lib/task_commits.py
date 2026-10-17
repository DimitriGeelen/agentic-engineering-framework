#!/usr/bin/env python3
"""lib/task_commits.py — which commits BELONG to a task (T-3189).

A commit belongs to T-XXX only when its SUBJECT opens with a task-id list naming it:
P-002's convention `T-XXX: …`, or a list such as `T-1, T-2: close` / `T-1/T-2: …`, which
belongs to each id listed. A commit that names the task anywhere else — a body
`Ref: T-XXX`, `unblocks T-XXX`, a mid-subject `… T-XXX filed` — is a cross-reference, and
the framework asks for those; reading them as authorship donates the referencing commit's
files to the referenced task (measured on T-3179: a T-3180 commit's `Ref: T-3179` fired the
render-surface gate on a task that touched no render surface).

`git log --grep` cannot answer this on its own: its `^` anchors at every line of the message,
not at the subject, so `--grep "^T-X:"` still matches a body line. The grep here is only a
prefilter; ownership is decided on the subject by `owns()`.

Single definition for every gate that resolves task -> commits/files: the render-surface gate
(lib/render_surface.sh), close-time component resolution and the T-4024 servicing ledger
(agents/task-create/update-task.sh), the judge's changed web files (lib/reviewer/judge_cli.py)
and the review-rung component count (lib/verdict_ledger.py `_owns`).

CLI:
    task_commits.py files <T-XXX> [--root DIR]   one path per line, unique, sorted
    task_commits.py shas  <T-XXX> [--root DIR]   one sha per line, newest first
Exit 0 with empty output when nothing belongs to the task or git cannot answer.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

#: The subject opens with a task-id list: "T-3580: ...", "T-3598, T-3601: ...", "T-1/T-2: ...".
OWN_SUBJECT_RE = re.compile(r"^\s*(T-\d+(?:\s*(?:,|&|/|\+|and)\s*T-\d+)*)\s*:")
_TASK_ID_RE = re.compile(r"^T-\d+$")


def owns(subject: str, task_id: str) -> bool:
    """True when `subject` opens with a task-id list that names `task_id` exactly."""
    m = OWN_SUBJECT_RE.match(subject or "")
    return bool(m) and task_id in re.findall(r"T-\d+", m.group(1))


def owned_commits(root: str | Path, task_id: str, *, all_refs: bool = True,
                  rev_range: str | None = None, timeout: int = 60
                  ) -> list[tuple[str, str, list[str]]]:
    """[(sha, subject, paths)] of the commits that belong to `task_id`, newest first.

    Raises subprocess.CalledProcessError / OSError / TimeoutExpired when git cannot answer;
    callers that must fail closed can tell that apart from "no commits"."""
    if not _TASK_ID_RE.match(task_id or ""):
        return []
    cmd = ["git", "-C", str(root), "log"]
    if rev_range:
        cmd.append(rev_range)
    elif all_refs:
        cmd.append("--all")
    # Prefilter only (see module doc); the non-digit boundary keeps T-318 off T-3186.
    cmd += ["-E", f"--grep={re.escape(task_id)}([^0-9]|$)", "--name-only",
            "--format=%x1e%H%x1f%s%x1d"]
    cp = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=True)
    out: list[tuple[str, str, list[str]]] = []
    for rec in cp.stdout.split("\x1e"):
        if "\x1d" not in rec:
            continue
        head, files = rec.split("\x1d", 1)
        sha, _, subject = head.partition("\x1f")
        if owns(subject, task_id):
            out.append((sha.strip(), subject, [f for f in files.splitlines() if f.strip()]))
    return out


def owned_files(root: str | Path, task_id: str, **kw) -> list[str]:
    """Unique, sorted paths changed by the commits that belong to `task_id`."""
    return sorted({p for _, _, paths in owned_commits(root, task_id, **kw) for p in paths})


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Commits that belong to a task (subject prefix).")
    ap.add_argument("what", choices=["files", "shas"])
    ap.add_argument("task_id")
    ap.add_argument("--root", default=".")
    a = ap.parse_args(argv)
    try:
        commits = owned_commits(a.root, a.task_id)
    except (OSError, subprocess.SubprocessError):
        return 0
    if a.what == "shas":
        lines = [sha for sha, _, _ in commits]
    else:
        lines = sorted({p for _, _, paths in commits for p in paths})
    if lines:
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
