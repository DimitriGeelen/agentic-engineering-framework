"""Test double for the review-dispatch RUNTIME (T-3580 round 3).

The real runtime is run.sh in agents/termlink/termlink.sh: the dispatcher registers the dispatch
with its worker directory and reviewed revision, the worker runs, and after it exits run.sh writes
`exit_code` and calls `verdict_ledger.py complete`. These helpers do exactly those two steps
against a fixture repo, so tests can say "the worker exited" without a TermLink session. The
worker directory lives OUTSIDE the fixture repo, like /tmp/tl-dispatch/<name>.
"""
import os
from contextlib import contextmanager
from pathlib import Path

from lib import verdict_ledger as vl


def wdir_for(root: Path, did: str) -> Path:
    return Path(root).parent / f"{Path(root).name}-tl-dispatch" / did


#: What run.sh holds in memory after its authenticated start issued the completion secret.
_HELD: dict = {}


@contextmanager
def as_runtime():
    """Stand in for run.sh in THIS process (round 6). `start` and `complete` authenticate their
    caller in the ledger itself (`_runtime_fault`: the parent process must be the canonical
    `<wdir>/run.sh`); a pytest process is not, so this double replaces that one check — and only
    while it is held — plus strips the worker marker as run.sh does. The check itself is proven
    against a REAL run.sh (t3580_round3/5/6 `_run_worker`) and refused without this double
    (t3580_round6_test.TestRuntimeCapability)."""
    saved_fault = vl._runtime_fault
    saved_env = os.environ.pop(vl._WORKER_ENV, None)
    vl._runtime_fault = lambda wdir: ""
    try:
        yield
    finally:
        vl._runtime_fault = saved_fault
        if saved_env is not None:
            os.environ[vl._WORKER_ENV] = saved_env


def dispatch(root, did, task, *, task_type="review", issuer_session="S-test",
             issuer_identity="dispatcher", revision="", worker_kind="claude", vendor="",
             run_id="", seat=""):
    """Register a dispatch exactly as the dispatcher does: with its worker dir, revision and worker
    kind (round 5: the ledger derives the vendor; `vendor` is only an assertion)."""
    w = wdir_for(root, did)
    w.mkdir(parents=True, exist_ok=True)
    vl.register_dispatch(did, task, task_type, issuer_session=issuer_session,
                         issuer_identity=issuer_identity, revision=revision, wdir=str(w),
                         worker_kind=worker_kind, vendor=vendor, run_id=run_id, seat=seat,
                         root=Path(root))
    return did


def take_secret(root, did) -> str:
    """run.sh's first act: its authenticated START, which issues the completion secret (round 6:
    registration no longer writes one). Held like run.sh holds it; '' if the start is refused."""
    key = (str(Path(root).resolve()), did)
    if key not in _HELD:
        _HELD[key] = ""
        with as_runtime():
            try:
                _rec, _HELD[key] = vl.start(did, wdir=str(wdir_for(root, did)), root=Path(root))
            except vl.VerdictRefused:
                pass
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
    with as_runtime():
        return vl.complete(did, wdir=str(w), exit_code=exit_code, session=did, secret=secret,
                           worker_kind=(rec or {}).get("worker_kind") or "claude", root=Path(root))
