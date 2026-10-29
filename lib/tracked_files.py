"""Find named files among what a project tracks, without walking its tree (T-4891).

A project root can be a home directory: dimitri-mint-dev's is ~500 GB of VM images,
.cache and downloads, and one `glob.glob(root/**/name, recursive=True)` in the
pre-push audit never finished there (killed at 15 min), so every push waited out the
audit's 300 s read cap. Files the framework looks for by name live in the project's
own content, so the search asks git for tracked paths (index speed, ignored trees
never touched) and, outside a git repo, looks only in `.context/` and `policy/`.
"""

from __future__ import annotations

import os
import subprocess

#: Directories searched when the project is not a git repository.
FALLBACK_DIRS = (".context", "policy")


def find_named(root: str, names, *, timeout: float = 10) -> list[str]:
    """Paths (relative to `root`) of tracked files whose basename is in `names`.

    Uses `git ls-files` when `root` is inside a git work tree. Otherwise, or when
    git fails, scans only FALLBACK_DIRS under `root`. Never walks `root` itself.
    """
    names = set(names)
    try:
        proc = subprocess.run(
            ["git", "-C", root, "ls-files", "-z", "--"]
            + [f"*{n}" for n in sorted(names)],
            capture_output=True, timeout=timeout,
        )
    except (OSError, subprocess.SubprocessError):
        proc = None
    if proc is not None and proc.returncode == 0:
        out = proc.stdout.decode("utf-8", "replace").split("\0")
        return sorted(p for p in out if p and os.path.basename(p) in names)
    found = []
    for d in FALLBACK_DIRS:
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            continue
        for dirpath, _, files in os.walk(base):
            for f in files:
                if f in names:
                    found.append(os.path.relpath(os.path.join(dirpath, f), root))
    return sorted(found)
