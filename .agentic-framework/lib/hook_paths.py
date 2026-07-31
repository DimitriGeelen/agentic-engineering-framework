"""Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd.

T-2468 (generalizes T-2465 / OBS-080 to the python hooks): when a hook fires inside a
git-worktree (or spawned) session, `bin/fw` resolves `PROJECT_ROOT` from the hook's
process cwd / inherited env, so a hook that reads `os.environ['PROJECT_ROOT']` can
inspect the wrong tree's `.context/arcs` / `.tasks` / bypass-log.

T-2709 UPDATE — this docstring previously asserted "every framework hook is wired into
Claude Code settings.json by MAIN's absolute path (`<main>/bin/fw hook …`)". That
premise is now FALSE. Both generators emit `${CLAUDE_PROJECT_DIR}/bin/fw hook …`, which
Claude Code expands to the session's project root — the WORKTREE root in a worktree
session, so the worktree's own `bin/fw` executes rather than main's. Legacy
settings.json files still carrying the baked absolute path retain the old main-anchored
behaviour, so both shapes exist in the wild. The re-derivation below is correct under
either, and is a no-op when the anchoring is already right. See
docs/reports/T-2704-hook-path-portability.md §8.

Claude Code passes the authoritative per-call working directory as the top-level `cwd`
key on the hook's stdin JSON ("working directory when the event fired"). This module
re-derives the project root from that cwd. Per-call stdin cwd is FRESH (not inherited),
so it is immune to the T-2446 daemon-poison class that limits CLAUDE_PROJECT_DIR trust.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Mapping


def reanchor_project_root(payload: Mapping[str, Any] | None, fallback: str | Path) -> Path:
    """Return the project root the hook should operate on.

    Walks up from the stdin payload's top-level `cwd` looking for a project marker
    (`.framework.yaml` file or `.tasks` dir). Returns that root when found and it
    differs from `fallback`; otherwise returns `fallback` unchanged.

    No-op (returns `fallback`) when: payload is falsy, has no `cwd`, the cwd is not an
    existing directory, or no project root is found above it — so normal (non-worktree)
    sessions are unaffected. Mirrors lib/paths.sh:fw_reanchor_from_cwd.
    """
    fb = Path(fallback)
    cwd = (payload or {}).get("cwd") or "" if payload else ""
    if not cwd:
        return fb
    try:
        d = Path(cwd).resolve()
    except (OSError, ValueError):
        return fb
    if not d.is_dir():
        return fb
    for cand in (d, *d.parents):
        if (cand / ".framework.yaml").is_file() or (cand / ".tasks").is_dir():
            return cand
    return fb
