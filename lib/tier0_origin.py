"""Derive the provenance of a Tier 0 approval request (T-3078).

A Tier 0 card asks the operator to pre-authorise a destructive command. That is
a judgement about *intent*, and intent is exactly what the card used to omit: it
carried hash, preview, risk, timestamp and status, and Watchtower rendered every
one of them under the literal "Agent blocked — requires your decision".

For the cards T-3077's governance suite filed against the live queue, that
subtitle was false. No agent was blocked; a test was. One of them read
"RECURSIVE DELETE: Targets root filesystem (/)". The operator opened /approvals
on 2026-08-18, saw it, and asked why — and nothing in the system could answer.

── Why this is derived and not declared ─────────────────────────────────────
Nothing here is supplied by the caller. There is no ``--is-a-test`` flag, and
adding one would not have prevented the incident: T-3077's suite did not ignore
a marker, it never considered that it was filing anything at all. A flag records
what the author believed; the process ancestry and the shape of PROJECT_ROOT
record what actually happened. Only the second survives an author who is not
thinking about the problem — which is every author, eventually.

── Why this is a module and not a heredoc ───────────────────────────────────
It began as inline Python inside ``agents/context/check-tier0.sh``. That made
the interesting half — the classification — reachable only by running the hook,
and a hook run from bats is *always* classified ``test``, so the ``agent`` and
``human`` branches could not be exercised at all. Logic you cannot get a failing
test for is logic you cannot trust. Hence :func:`classify`, which is pure:
signals in, kind out, covered directly in ``tests/unit/test_tier0_origin.py``.

Extracting it paid for itself immediately: with the branches finally reachable,
the ``bats`` marker turned out to be matching against ``ps -o comm=``, which
reports ``bash`` for every hop of a bats run. The marker had never fired. See
:func:`classify`.
"""

from __future__ import annotations

import os
import subprocess

#: Process names that mean "a test harness is running this".
TEST_MARKERS = ("bats", "pytest", "py.test")

#: Process names that mean "an agent session is running this".
AGENT_MARKERS = ("claude",)

#: How far up the parent chain to walk. Bounded because this code runs inside a
#: hook that is currently holding a destructive command: a cycle or a pathological
#: chain must degrade to partial provenance, never to a hang.
MAX_ANCESTRY_DEPTH = 12


def classify(signals, sandbox: bool, env=None) -> str:
    """Return one of ``test`` / ``agent`` / ``human``.

    ``signals`` is an iterable of strings scanned for the markers above. Pass
    **full command lines**, not ``ps -o comm=`` names.

    That distinction is not pedantry, it is the whole reliability of the test
    branch. ``comm`` reports the *interpreter*, so every hop of a bats run comes
    back as ``bash``::

        comm: bash  bash  bash  bash  claude  claude-fw
        args: bash /usr/local/libexec/bats-core/bats-exec-file …
              bash /usr/local/libexec/bats-core/bats-exec-suite …
              bash /usr/local/libexec/bats-core/bats …

    Matching ``bats`` against the first row never fires. The first version of
    this code did exactly that, and the marker was dead — ``kind=test`` was
    being carried entirely by the sandbox check, with the ancestry signal
    silently contributing nothing. Caught by a test asserting the recorded
    ancestry actually contains the harness.

    Precedence is deliberate and is the point of the function:

    1. ``test`` — a test harness in the chain, or a throwaway working tree.
       This outranks the agent signal because an agent running a suite still
       produces test artefacts, not agent requests. That combination is not
       hypothetical; it is precisely what happened in T-3077.
    2. ``agent`` — an agent session, by env or by chain.
    3. ``human`` — nobody automated is in the chain, so a person typed it.
    """
    env = os.environ if env is None else env
    low = " ".join(signals or ()).lower()

    if sandbox or any(m in low for m in TEST_MARKERS):
        return "test"
    if env.get("CLAUDECODE") == "1" or any(m in low for m in AGENT_MARKERS):
        return "agent"
    return "human"


def is_sandbox(project_root: str, env=None) -> bool:
    """True when ``project_root`` is a throwaway tree rather than a real project.

    Two facts about the directory, neither of them self-reported:

    * it has no ``.git`` — every real project the framework governs is a repo;
    * or it lives under a temp directory.

    The second is not redundant with the first: a test fixture that runs
    ``git init`` on its sandbox would otherwise read as a genuine project.
    """
    env = os.environ if env is None else env
    if not project_root:
        return False
    if not os.path.isdir(os.path.join(project_root, ".git")):
        return True
    tmpdir = env.get("TMPDIR")
    prefixes = ["/tmp/", "/var/tmp/"]
    if tmpdir:
        prefixes.append(tmpdir.rstrip("/") + "/")
    return project_root.startswith(tuple(prefixes))


def process_ancestry(pid=None, depth: int = MAX_ANCESTRY_DEPTH):
    """Walk the parent chain, innermost-first.

    Returns a list of ``(comm, args)`` pairs. Both are needed and they are used
    for different things:

    * ``comm`` is what gets STORED on the card and shown to the operator. It is
      short and contains no arguments.
    * ``args`` is the full command line, used ONLY for marker matching and
      deliberately not stored — command lines can carry tokens, paths and
      secrets, and a card is a surface an operator reads. See :func:`classify`
      for why matching on ``comm`` alone does not work.

    Uses ``ps`` rather than ``/proc`` so this works on macOS as well as Linux
    (Portability, directive 4). Any failure truncates the chain rather than
    raising — partial provenance beats none.
    """
    chain, seen = [], set()
    pid = os.getppid() if pid is None else pid
    for _ in range(depth):
        if pid is None or pid <= 1 or pid in seen:
            break
        seen.add(pid)
        try:
            out = subprocess.run(
                ["ps", "-o", "ppid=,comm=,args=", "-p", str(pid)],
                capture_output=True, text=True, timeout=2,
            ).stdout.strip()
        except Exception:
            break
        if not out:
            break
        parts = out.split(None, 2)
        if len(parts) < 2:
            break
        chain.append((parts[1].strip(), parts[2].strip() if len(parts) > 2 else ""))
        try:
            pid = int(parts[0])
        except ValueError:
            break
    return chain


def derive(project_root: str, env=None, pid=None) -> dict:
    """Assemble the ``origin:`` block for a pending Tier 0 card.

    Never raises. Provenance is an *addition* to the card, and the card is what
    blocks the destructive command — so a failure to explain the request must
    never prevent the request from being recorded. On total failure the caller
    still gets ``{'kind': 'unknown'}``, which the UI renders as an explicit
    "no provenance recorded" warning rather than as an agent request.
    """
    env = os.environ if env is None else env
    origin = {"kind": "unknown"}
    try:
        origin["project_root"] = project_root
        origin["pid"] = os.getpid()
        try:
            origin["cwd"] = os.getcwd()
        except Exception:
            origin["cwd"] = ""

        chain = process_ancestry(pid)
        # Store the short names; classify on the full command lines. The card is
        # operator-facing, and full argv can carry tokens and secrets.
        origin["ancestry"] = [comm for comm, _args in chain]
        signals = [args or comm for comm, args in chain]

        sandbox = is_sandbox(project_root, env)
        origin["sandbox"] = sandbox

        task = session = None
        try:
            import yaml
            focus_path = os.path.join(project_root, ".context/working/focus.yaml")
            with open(focus_path) as fh:
                focus = yaml.safe_load(fh) or {}
            task = focus.get("current_task") or None
            session = focus.get("focus_session") or None
        except Exception:
            pass
        origin["task"] = task
        origin["session"] = session

        origin["kind"] = classify(signals, sandbox, env)
    except Exception:
        pass
    return origin
