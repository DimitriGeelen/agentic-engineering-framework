"""Test double for the review-dispatch RUNTIME (T-3580 round 3).

The real runtime is run.sh in agents/termlink/termlink.sh: the dispatcher registers the dispatch
with its worker directory and reviewed revision, the worker runs, and after it exits run.sh writes
`exit_code` and calls `verdict_ledger.py complete`. These helpers do exactly those two steps
against a fixture repo, so tests can say "the worker exited" without a TermLink session. The
worker directory lives OUTSIDE the fixture repo, like /tmp/tl-dispatch/<name>.
"""
import os
from pathlib import Path

from lib import verdict_ledger as vl


def wdir_for(root: Path, did: str) -> Path:
    return Path(root).parent / f"{Path(root).name}-tl-dispatch" / did


def dispatch(root, did, task, *, task_type="review", issuer_session="S-test",
             issuer_identity="dispatcher", revision=""):
    """Register a dispatch exactly as the dispatcher does: with its worker dir and revision."""
    w = wdir_for(root, did)
    w.mkdir(parents=True, exist_ok=True)
    vl.register_dispatch(did, task, task_type, issuer_session=issuer_session,
                         issuer_identity=issuer_identity, revision=revision, wdir=str(w),
                         root=Path(root))
    return did


def finish(root, did, exit_code=0, result=b'{"type":"result","result":"done"}\n'):
    """The worker exited: write its exit state and result stream, then sign as the runtime does
    (outside the worker's environment)."""
    w = wdir_for(root, did)
    w.mkdir(parents=True, exist_ok=True)
    (w / "result.jsonl").write_bytes(result)
    (w / "exit_code").write_text(f"{exit_code}\n")
    saved = os.environ.pop(vl._WORKER_ENV, None)
    try:
        return vl.complete(did, wdir=str(w), exit_code=exit_code, session=did, root=Path(root))
    finally:
        if saved is not None:
            os.environ[vl._WORKER_ENV] = saved
