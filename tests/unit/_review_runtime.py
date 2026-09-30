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


#: Round 7: every run seat binds the brief it is dispatched with; fixtures use this one.
BRIEF = "fixture review brief\n"
BRIEF_SHA = vl.brief_digest(BRIEF)
#: Round 7: a review worker is launched by an absolute, executable path resolved at dispatch.
WORKER_BIN = "/bin/true"


def register_run(*args, **kw):
    """vl.register_run with the fixture brief bound to every seat (round 7)."""
    kw.setdefault("brief_sha256", BRIEF_SHA)
    return vl.register_run(*args, **kw)


def write_launch(w: Path, brief: str = BRIEF, worker_bin: str = WORKER_BIN) -> None:
    """What cmd_dispatch writes before it registers: prompt.md (consult stanza + brief), brief.md
    (the caller's brief verbatim) and worker_bin (round 7)."""
    w.mkdir(parents=True, exist_ok=True)
    (w / "prompt.md").write_text("[PEER CONSULTS]\n\n" + brief.rstrip("\n") + "\n")
    (w / "brief.md").write_text(brief.rstrip("\n") + "\n")
    (w / "worker_bin").write_text(worker_bin + "\n")


def dispatch(root, did, task, *, task_type="review", issuer_session="S-test",
             issuer_identity="dispatcher", revision="", worker_kind="claude", vendor="",
             run_id="", seat="", brief=BRIEF, worker_bin=WORKER_BIN):
    """Register a dispatch exactly as the dispatcher does: with its worker dir, revision and worker
    kind (round 5: the ledger derives the vendor; `vendor` is only an assertion), and (round 7) the
    brief and absolute worker binary it launches."""
    w = wdir_for(root, did)
    write_launch(w, brief, worker_bin)
    vl.register_dispatch(did, task, task_type, issuer_session=issuer_session,
                         issuer_identity=issuer_identity, revision=revision, wdir=str(w),
                         worker_kind=worker_kind, vendor=vendor, run_id=run_id, seat=seat,
                         worker_bin=worker_bin, root=Path(root))
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


def commit_registry(root, text: str) -> None:
    """Write a fixture policy/review-backends.yaml AND commit it (round 6: the ledger reads the
    registry as committed, never the working tree). Committed by a non-producer identity, with
    no task id, so it is neither the task's work nor a producer commit."""
    import subprocess
    p = Path(root) / "policy" / "review-backends.yaml"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    env = {**os.environ, "GIT_AUTHOR_NAME": "Operator", "GIT_AUTHOR_EMAIL": "op@x.y",
           "GIT_COMMITTER_NAME": "Operator", "GIT_COMMITTER_EMAIL": "op@x.y"}
    for args in (["add", "policy/review-backends.yaml"], ["commit", "-q", "-m", "fixture: backend registry"]):
        subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=root, check=True,
                       capture_output=True, env=env)


def launchable(monkeypatch, kinds) -> None:
    """Pretend the dispatcher can launch `kinds` (as if T-3582 had built codex/opencode workers).
    The ledger's own check reads DISPATCH_WORKER_KINDS; this replaces only that answer."""
    real = vl.launchable_kinds
    monkeypatch.setattr(vl, "launchable_kinds", lambda: set(kinds) | real())
