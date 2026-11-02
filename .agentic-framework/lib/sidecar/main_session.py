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

The exact stdout format is not final, so ONLY the exit code is parsed (plus the
error text that tells "the verb does not exist" apart from exit 2 "unknown").
Every call goes through am_i(), so the format can be pinned here later.
A timeout or any unexpected failure reads "unknown" — never an exception.
"""

from __future__ import annotations

import os
import re
import subprocess

MAIN = "main"
NOT_MAIN = "not-main"
UNKNOWN = "unknown"
UNSUPPORTED = "unsupported"

UNSUPPORTED_LINE = "main-only delivery not active: termlink lacks main am-i"
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


def am_i(session_id, runner=subprocess.run, timeout: float = 5,
         project: str | None = None) -> tuple[str, str]:
    """(answer, holder). answer ∈ {main, not-main, unknown, unsupported};
    holder is the not-main stdout reduced to one short printable line, else ''."""
    if not session_id:
        return UNKNOWN, ""
    argv = [termlink_bin(), "main", "am-i", "--session", str(session_id)]
    if project:
        argv += ["--project", str(project)]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        return UNSUPPORTED, ""
    except Exception:  # noqa: BLE001 - timeout, permission, anything: fail closed
        return UNKNOWN, ""
    try:
        rc = int(proc.returncode)
        out, err = str(proc.stdout or ""), str(proc.stderr or "")
    except Exception:  # noqa: BLE001
        return UNKNOWN, ""
    if rc == 0:
        return MAIN, ""
    if rc == 1:
        return NOT_MAIN, _one_line(out)
    # Exit 2 is also what clap uses for a usage error, so the error text decides.
    if _VERB_MISSING.search(err) or _VERB_MISSING.search(out):
        return UNSUPPORTED, ""
    return UNKNOWN, ""


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
        return "main", mains, ""
    if all(a == UNSUPPORTED for _, (a, _) in answers):
        return "legacy", records, ""
    if any(a == UNKNOWN for _, (a, _) in answers):
        return "unknown", [], "termlink main am-i: unknown"
    holders = sorted({h for _, (a, h) in answers if a == NOT_MAIN and h})
    return "not-main", [], "; ".join(holders) or "holder not named"
