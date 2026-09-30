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


#: What run.sh holds in memory after it took the completion secret and deleted its file (round 4).
_HELD: dict = {}


def dispatch(root, did, task, *, task_type="review", issuer_session="S-test",
             issuer_identity="dispatcher", revision="", worker_kind="claude", vendor=""):
    """Register a dispatch exactly as the dispatcher does: with its worker dir, revision and worker
    kind (round 5: the ledger derives the vendor; `vendor` is only an assertion)."""
    w = wdir_for(root, did)
    w.mkdir(parents=True, exist_ok=True)
    vl.register_dispatch(did, task, task_type, issuer_session=issuer_session,
                         issuer_identity=issuer_identity, revision=revision, wdir=str(w),
                         worker_kind=worker_kind, vendor=vendor, root=Path(root))
    return did


def take_secret(root, did, *, start=True) -> str:
    """run.sh's first act: read the completion secret, delete its file and (round 5) record the
    signed runtime START for the dispatch. `start=False` only reads, like a caller who finds a
    leftover file of a dispatch that never ran."""
    key = (str(Path(root).resolve()), did)
    if key not in _HELD:
        f = wdir_for(root, did) / vl.COMPLETION_SECRET_FILE
        _HELD[key] = f.read_text().strip() if f.is_file() else ""
        f.unlink(missing_ok=True)
        if start and _HELD[key]:
            saved = os.environ.pop(vl._WORKER_ENV, None)
            try:
                vl.start(did, wdir=str(wdir_for(root, did)), secret=_HELD[key], root=Path(root))
            except vl.VerdictRefused:
                pass
            finally:
                if saved is not None:
                    os.environ[vl._WORKER_ENV] = saved
    return _HELD[key]


def finish(root, did, exit_code=0, result=b'{"type":"result","result":"done"}\n'):
    """The worker exited: write its exit state and result stream, then sign as the runtime does
    (outside the worker's environment)."""
    w = wdir_for(root, did)
    w.mkdir(parents=True, exist_ok=True)
    (w / "result.jsonl").write_bytes(result)
    (w / "exit_code").write_text(f"{exit_code}\n")
    secret = take_secret(root, did)
    rec, _ = vl.dispatch_record(Path(root), did)
    saved = os.environ.pop(vl._WORKER_ENV, None)
    try:
        return vl.complete(did, wdir=str(w), exit_code=exit_code, session=did, secret=secret,
                           worker_kind=(rec or {}).get("worker_kind") or "claude", root=Path(root))
    finally:
        if saved is not None:
            os.environ[vl._WORKER_ENV] = saved
