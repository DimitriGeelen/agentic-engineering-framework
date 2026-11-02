"""T-5014 — is this Claude session the project's MAIN session?

Peer mail is surfaced and handed over only in a project's main (operator-facing)
session, never in a background session of the same identity (ring20 incident,
2026-11-02). TermLink owns the main pin, its lease and its liveness (010 T-3654);
AEF only asks:

    termlink main am-i --session <claude-session-id> [--project P]

    exit 0 → "main"        this session holds the main lease
    exit 1 → "not-main"    stdout names the holder
    exit 2 → "unknown"     fail closed: mail waits
    verb missing           → "unsupported": keep today's delivery

ONLY the exit code decides the answer (plus the error text that tells "the verb
does not exist" apart from exit 2 "unknown"). The one stdout read is the vacancy
flag: 010's build prints, exactly (msgs c84c1c6d, 59d2ec20),

    exit 1  not-main: held by main <session>@<host> pid <pid> (agent <a>) (generation N)
    exit 1  main of <project> is vacant (generation N)

A timeout or any unexpected failure reads "unknown" — never an exception.

Nobody holds main until a session CLAIMS it (`termlink main claim --session
<sid>`: takes a vacant lease or renews one this session holds; lease 15 min,
quiet 5 min, cooldown 10 min). claim() is called by an interactive session's
SessionStart (forced), UserPromptSubmit and Stop hooks; renewals are rate-limited
client-side to one per CLAIM_MIN_INTERVAL_S per session (a claim is a few hub
RPCs). Headless `claude -p` workers, review seats and dispatched workers never
claim (may_claim). release() exists for a SessionEnd hook, which is not wired.
"""

from __future__ import annotations

import os
import re
import subprocess
import time

MAIN = "main"
NOT_MAIN = "not-main"
UNKNOWN = "unknown"
UNSUPPORTED = "unsupported"

UNSUPPORTED_LINE = "main-only delivery not active: termlink lacks main am-i"
VACANT_LINE = ("peer mail waiting: main lease for this project is vacant and could not be "
               "claimed yet (quiet or cooldown window)")

# claim() / release() results
CLAIMED = "claimed"
REFUSED = "refused"        # the hub said no: held by another session, quiet or cooldown
SKIPPED = "skipped"        # rate limit: this session claimed less than a minute ago
INELIGIBLE = "ineligible"  # not an interactive session: never claims
RELEASED = "released"
CLAIM_MIN_INTERVAL_S = 60

_VACANT = re.compile(r"^\s*main of \S.* is vacant \(generation \d+\)", re.MULTILINE)
UNKNOWN_LINE = ("peer mail waiting: main-only delivery could not confirm this session is "
                "main (termlink main am-i: unknown)")

# What a CLI says when the subcommand or flag does not exist (clap: "unrecognized
# subcommand 'main'", "unexpected argument '--session'"; others: "unknown command").
_VERB_MISSING = re.compile(
    r"unrecognized subcommand|unexpected argument|unknown (sub)?command|invalid subcommand|"
    r"no such (sub)?command|unrecognized (command|argument|option)", re.IGNORECASE)
_HOLDER_CAP = 120


def termlink_bin() -> str:
    return os.environ.get("FW_TERMLINK_BIN") or "termlink"


def _one_line(text) -> str:
    s = " ".join(str(text or "").split())
    s = "".join(c for c in s if c.isprintable())
    return s[:_HOLDER_CAP]


def _run(verb: str, session_id, runner, timeout: float, project: str | None):
    """(rc, stdout, stderr) of `termlink main <verb> --session <sid>`, or the
    answer string UNSUPPORTED / UNKNOWN when it could not run at all."""
    argv = [termlink_bin(), "main", verb, "--session", str(session_id)]
    if project:
        argv += ["--project", str(project)]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        return UNSUPPORTED
    except Exception:  # noqa: BLE001 - timeout, permission, anything: fail closed
        return UNKNOWN
    try:
        return int(proc.returncode), str(proc.stdout or ""), str(proc.stderr or "")
    except Exception:  # noqa: BLE001
        return UNKNOWN


def _verb_missing(out: str, err: str) -> bool:
    # Exit 2 is also what clap uses for a usage error, so the error text decides.
    return bool(_VERB_MISSING.search(err) or _VERB_MISSING.search(out))


def ask(session_id, runner=subprocess.run, timeout: float = 5,
        project: str | None = None) -> tuple[str, str, bool]:
    """(answer, holder, vacant). answer ∈ {main, not-main, unknown, unsupported};
    holder is the not-main stdout reduced to one short printable line, else '';
    vacant is True only for a not-main answer that says the lease is vacant."""
    if not session_id:
        return UNKNOWN, "", False
    res = _run("am-i", session_id, runner, timeout, project)
    if isinstance(res, str):
        return res, "", False
    rc, out, err = res
    if rc == 0:
        # The holder text of a main answer names the generation (logged, T-5014).
        return MAIN, _one_line(out), False
    if rc == 1:
        return NOT_MAIN, _one_line(out), bool(_VACANT.search(out))
    if _verb_missing(out, err):
        return UNSUPPORTED, "", False
    return UNKNOWN, "", False


def am_i(session_id, runner=subprocess.run, timeout: float = 5,
         project: str | None = None) -> tuple[str, str]:
    """(answer, holder) — ask() without the vacancy flag."""
    answer, holder, _vacant = ask(session_id, runner=runner, timeout=timeout, project=project)
    return answer, holder


def may_claim(me: dict | None) -> bool:
    """Only an interactive Claude session claims main: never a headless
    `claude -p` worker, a review seat (FW_REVIEW_WORKER) or a dispatched worker
    (FW_DISPATCHED_WORKER=1, FW_REVIEWER_IN_DISPATCH)."""
    if not me or not me.get("session_id") or me.get("headless"):
        return False
    if os.environ.get("FW_REVIEW_WORKER") or os.environ.get("FW_REVIEWER_IN_DISPATCH"):
        return False
    if os.environ.get("FW_DISPATCHED_WORKER") == "1":
        return False
    return True


def _stamp(session_id):
    from . import receiver
    safe = "".join(c for c in str(session_id) if c.isalnum() or c in "-_")[:80] or "unknown"
    d = receiver._receiver_dir() / "main-lease"
    d.mkdir(parents=True, exist_ok=True)
    return d / safe


def _recently_claimed(session_id, now: float) -> bool:
    try:
        return now - _stamp(session_id).stat().st_mtime < CLAIM_MIN_INTERVAL_S
    except OSError:
        return False


def claim(session_id, force: bool = False, runner=subprocess.run, timeout: float = 5,
          project: str | None = None, now: float | None = None) -> str:
    """Take the vacant main lease or renew the one this session holds.
    Returns claimed / refused / skipped (rate limit) / unsupported / unknown.
    Never raises. The rate-limit stamp is written only on success."""
    try:
        if not session_id:
            return UNKNOWN
        now = time.time() if now is None else now
        if not force and _recently_claimed(session_id, now):
            return SKIPPED
        res = _run("claim", session_id, runner, timeout, project)
        if isinstance(res, str):
            return res
        rc, out, err = res
        if rc == 0:
            try:
                p = _stamp(session_id)
                p.touch()
                os.utime(p, (now, now))
            except OSError:
                pass
            return CLAIMED
        if _verb_missing(out, err):
            return UNSUPPORTED
        return REFUSED if rc == 1 else UNKNOWN
    except Exception:  # noqa: BLE001 - a claim must never break a hook
        return UNKNOWN


def release(session_id, runner=subprocess.run, timeout: float = 5,
            project: str | None = None) -> str:
    """Give the lease up cleanly (skips the quiet period). Not wired to a hook
    yet: there is no SessionEnd hook in .claude/settings.json."""
    try:
        if not session_id:
            return UNKNOWN
        res = _run("release", session_id, runner, timeout, project)
        if isinstance(res, str):
            return res
        rc, out, err = res
        try:
            _stamp(session_id).unlink()
        except OSError:
            pass
        if rc == 0:
            return RELEASED
        if _verb_missing(out, err):
            return UNSUPPORTED
        return REFUSED if rc == 1 else UNKNOWN
    except Exception:  # noqa: BLE001
        return UNKNOWN


def gate(records: list[dict], runner=subprocess.run) -> tuple[str, list[dict], str]:
    """Apply the main-only rule to a candidate list (newest first, already filtered).

    Returns (mode, kept, detail):
      ("legacy", records, "")        no candidates, or every answer unsupported → today's rule
      ("main", [main records], "")   at least one candidate is main → only those
      ("unknown", [], detail)        none main, at least one unknown → no target
      ("not-main", [], holder)       every candidate not-main → no target
    """
    if not records:
        return "legacy", records, ""
    answers = [(r, am_i(r.get("session_id"), runner=runner)) for r in records]
    mains = [r for r, (a, _) in answers if a == MAIN]
    if mains:
        return "main", mains, "; ".join(sorted({h for _, (a, h) in answers if a == MAIN and h}))
    if all(a == UNSUPPORTED for _, (a, _) in answers):
        return "legacy", records, ""
    if any(a == UNKNOWN for _, (a, _) in answers):
        return "unknown", [], "termlink main am-i: unknown"
    holders = sorted({h for _, (a, h) in answers if a == NOT_MAIN and h})
    return "not-main", [], "; ".join(holders) or "holder not named"


def main(argv=None) -> int:
    """`main_session.py claim <session-id>`: the detached SessionStart claim."""
    import sys
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) == 2 and argv[0] == "claim":
        claim(argv[1], force=True)
    return 0


if __name__ == "__main__":
    import sys as _sys
    if __package__ in (None, ""):
        _sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        from lib.sidecar import main_session as _ms  # noqa: E402
        _sys.exit(_ms.main())
    _sys.exit(main())
