#!/usr/bin/env python3
"""
worker_identity — the git identity a dispatch-spawned worker commits under (T-2917).

A worker inherits the repo's ambient git identity unless something overrides
it. Nothing did, so a resolver-loop worker's 923-line source commit and the
operator's hand-typed commit were byte-identical in every field git records
(origin: T-2917 Context — commit d3d759b41). `lib/init.sh:752` already solves
this for `fw init`'s own bootstrap commit by scoping GIT_AUTHOR_*/GIT_COMMITTER_*
via env vars for that one commit; this module generalises the same technique
to every dispatch-spawned worker.

Two things travel in the identity, both readable off a bare `git log`:
  - the MECHANISM that spawned the worker (name), so a reader can tell a
    resolver-loop worker from a raw TermLink dispatch without cross-referencing
    anything else.
  - the DISPATCH ID (email local-part), so a worker's commit joins back to its
    row in `.context/dispatches.jsonl` (`fw outcome read <dispatch_id>`)
    without depending on the worker to write a commit trailer — the identity
    IS the join key, which survives even a worker that never reads this file.

Bash callers get the same contract from `lib/git-identity.sh:fw_worker_git_identity_env`
— kept as a second implementation (bash can't cheaply import this module across
the process boundary spawn.py crosses to reach `fw termlink dispatch`) but the
same format string, pinned by tests on both sides.
"""

from __future__ import annotations

from typing import Dict

# Anchors the format both implementations must match — pinned by
# tests/unit/worker_identity.py and tests/unit/git_identity_worker_env.bats.
EMAIL_DOMAIN = "aef.local"
EMAIL_LOCAL_PREFIX = "dispatch"


def mechanism_from_origin(origin: str) -> str:
    """Map a `_dispatch_origin()` string to a short, human-readable mechanism name.

    `origin` already distinguishes systemd units from interactive/cli sessions
    (T-2914); this just renders it as something worth reading in `git log
    --author`, rather than requiring the reader to decode the origin string's
    own colon-delimited shape.
    """
    origin = (origin or "").strip()
    if origin.startswith("systemd:resolver-loop"):
        return "resolver-loop"
    if origin.startswith("systemd:"):
        return f"resolver-loop:{origin.split(':', 1)[1]}"
    if origin.startswith("interactive:"):
        return "resolver-manual"
    if origin.startswith("cli:"):
        return "resolver-cli"
    return "resolver"


def worker_git_env(mechanism: str, dispatch_id: str) -> Dict[str, str]:
    """GIT_AUTHOR_*/GIT_COMMITTER_* env overlay for a dispatch-spawned worker.

    `short` is the dispatch_id's first 8 hex chars — the same truncation
    `_recent_dispatches_summary` already uses for display, so identity and
    dashboard both show the same short id for the same dispatch.
    """
    short = (dispatch_id or "unknown")[:8] or "unknown"
    name = f"fw worker ({mechanism})"
    email = f"{EMAIL_LOCAL_PREFIX}+{short}@{EMAIL_DOMAIN}"
    return {
        "GIT_AUTHOR_NAME": name,
        "GIT_AUTHOR_EMAIL": email,
        "GIT_COMMITTER_NAME": name,
        "GIT_COMMITTER_EMAIL": email,
    }
