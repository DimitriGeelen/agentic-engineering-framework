#!/usr/bin/env python3
"""
keylock — Python sibling of ``lib/keylock.sh``: sidecar advisory file locks.

T-3042. The shell primitive (T-587) serialises framework operations on a key
using ``flock`` over ``.context/locks/<key>.lock``. Python callers had no
equivalent — ``web/embeddings.py`` inlines its own non-blocking lock, and
``lib/spawn.py`` had none at all, which is the bug this module exists to fix.
Same lock directory, so a shell and a Python holder of the same key contend.

WHY A SIDECAR AND NOT THE FILE ITSELF
------------------------------------
``flock`` binds to an *open file description*, i.e. to an inode — not to a
path. The rewriter this module guards finishes with ``os.replace(tmp, log)``,
which swaps a new inode in under the same path. Had the lock been taken on the
guarded file, the appender would open the path, lock whatever inode it found,
and after the swap be holding an exclusive lock on an orphaned inode that no
future writer will ever open. Both sides would hold "the lock" and neither
would contend. The lock therefore lives on a stable sidecar path that nothing
ever replaces.

BOUNDED, AND LOUD ON EXPIRY
---------------------------
``fcntl.flock`` offers blocking or non-blocking, never a timeout, so this
polls ``LOCK_NB`` until a deadline. On expiry it raises ``LockTimeout`` after
writing to stderr. It never returns "lock not acquired" as an ordinary value:
a caller that mistook that for "carry on" would reintroduce exactly the silent
data loss the lock prevents.
"""

from __future__ import annotations

import errno
import fcntl
import os
import sys
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator, Optional, Union

# Same directory as lib/keylock.sh:24 (KEYLOCK_DIR) so shell and Python
# holders of one key serialise against each other rather than past each other.
LOCKS_DIRNAME = "locks"

# Generous by design: this only fires on pathology (a killed holder, an NFS
# stall), never on ordinary contention between the framework's ≤5 concurrent
# workers, whose critical sections are single-digit milliseconds.
DEFAULT_TIMEOUT_S = 30.0
TIMEOUT_ENV = "FW_LEDGER_LOCK_TIMEOUT"

_POLL_INTERVAL_S = 0.01

# World-writable: the lock is a rendezvous point, not a secret, and T-3041 is
# de-rooting the dispatch path. A lock file created 0644 by a root cron run
# would lock every later non-root principal out of the ledger entirely.
_LOCK_FILE_MODE = 0o666
_LOCK_DIR_MODE = 0o777


class LockTimeout(TimeoutError):
    """Raised when an exclusive lock could not be acquired before the deadline."""


def resolve_timeout(timeout: Optional[float] = None) -> float:
    """Explicit argument > ``FW_LEDGER_LOCK_TIMEOUT`` > ``DEFAULT_TIMEOUT_S``.

    Read per call, not frozen into a default argument at import time, so the
    env var still applies to a module imported before it was set.
    """
    if timeout is not None:
        return float(timeout)
    raw = os.environ.get(TIMEOUT_ENV)
    if raw:
        try:
            return float(raw)
        except ValueError:
            print(
                f"keylock: {TIMEOUT_ENV}={raw!r} is not a number; "
                f"using {DEFAULT_TIMEOUT_S:g}s",
                file=sys.stderr,
            )
    return DEFAULT_TIMEOUT_S


def lock_path_for(target: Union[str, Path]) -> Path:
    """Sidecar lock path for a guarded file.

    ``.context/dispatches.jsonl`` → ``.context/locks/dispatches.lock``

    Derived from the target path rather than from a module-level constant so
    that a caller which repoints its ledger (tests, an alternate PROJECT_ROOT)
    repoints the lock with it. A lock keyed to the wrong file is no lock.
    """
    target = Path(target)
    return target.parent / LOCKS_DIRNAME / (target.stem + ".lock")


def _open_lock_fd(lock_path: Path) -> int:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    _relax_mode(lock_path.parent, _LOCK_DIR_MODE)
    existed = lock_path.exists()
    fd = os.open(str(lock_path), os.O_CREAT | os.O_RDWR | os.O_CLOEXEC, _LOCK_FILE_MODE)
    if not existed:
        # O_CREAT's mode is masked by umask (022 → 0644), which would bar a
        # different principal from opening it O_RDWR later. chmod is not.
        _relax_mode(lock_path, _LOCK_FILE_MODE)
    return fd


def _relax_mode(path: Path, mode: int) -> None:
    """Best-effort widen permissions; silent when we do not own the path."""
    try:
        if (path.stat().st_mode & 0o777) != mode:
            os.chmod(str(path), mode)
    except OSError:
        pass


@contextmanager
def exclusive(
    lock_path: Union[str, Path],
    timeout: Optional[float] = None,
    label: str = "",
) -> Iterator[int]:
    """Hold an exclusive advisory lock on ``lock_path`` for the block's duration.

    Raises ``LockTimeout`` (after a stderr banner) if the lock is not acquired
    within ``timeout`` seconds. The lock is released — and the descriptor
    closed — on every exit path, including exceptions.
    """
    lock_path = Path(lock_path)
    timeout = resolve_timeout(timeout)
    what = label or lock_path.stem
    fd = _open_lock_fd(lock_path)
    deadline = time.monotonic() + timeout
    acquired = False
    try:
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                acquired = True
                break
            except OSError as exc:
                if exc.errno not in (errno.EACCES, errno.EAGAIN):
                    raise
                if time.monotonic() >= deadline:
                    msg = (
                        f"keylock: TIMEOUT after {timeout:g}s waiting for "
                        f"exclusive lock on {lock_path} ({what}). Another "
                        f"process is holding it; the guarded write was NOT "
                        f"performed. Inspect with: fuser -v {lock_path}"
                    )
                    print(f"\n*** {msg}\n", file=sys.stderr, flush=True)
                    raise LockTimeout(msg) from exc
                time.sleep(_POLL_INTERVAL_S)
        yield fd
    finally:
        if acquired:
            try:
                fcntl.flock(fd, fcntl.LOCK_UN)
            except OSError:
                pass
        os.close(fd)


@contextmanager
def guarding(
    target: Union[str, Path],
    timeout: Optional[float] = None,
) -> Iterator[int]:
    """``exclusive()`` on the sidecar lock belonging to ``target``."""
    with exclusive(lock_path_for(target), timeout=timeout, label=Path(target).name) as fd:
        yield fd
