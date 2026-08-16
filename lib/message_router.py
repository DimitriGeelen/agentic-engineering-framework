"""T-3046 — static ``msg_type`` router for recovered hub messages (slice 1 of T-3044).

The defect this closes is not a missing classifier. It is a missing wire: 47,879
messages sit in ``.context/message-archive/raw/``, the machinery to act on the
actionable ones already exists (``fw pickup process``, ``fw note triage``,
``fw bus``), and nothing routes between them. A bug report sat unread for three
months as a direct result.

Three properties are load-bearing, and each exists because its absence has already
cost something:

**No silent drops.** Every message gets exactly one recorded disposition. ``dropped``
is a *decision*, written down with a reason and queryable afterwards — not an absence
of one. A message that no rule matches raises rather than defaulting, so a new
producer surfaces as a failure instead of being swallowed.

**Coverage is measured, not declared.** :func:`assert_table_complete` replays the
live archive's actual type list. It does not compare against a hand-maintained list
of expected types, because that is exactly the check that failed: the T-3044 census
recorded 16 types and 35,125 messages where the archive holds 79 and 47,879. A
coverage assertion you can satisfy by editing a constant asserts nothing.

**Identity is content, not position.** The archive has no id field of any kind —
no ``id``, ``msg_id``, ``message_id`` or ``uuid``. ``(topic, offset)`` collides 3,593
times because offsets restart per hub and the same topic is recovered from several.
The content hash is unique 47,879/47,879 and, unlike ``(source_file, topic, offset)``,
survives the same message being re-recovered into tomorrow's dated archive file.

Slice 1 *computes and records* dispositions. It does not execute handlers: the
``handler`` field names where a message should go, and wiring the execution is
slice 2, behind the operator's approval of this table. Recording is additive and
reversible; executing is neither.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import keylock  # noqa: E402

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT") or Path(__file__).resolve().parent.parent)
ARCHIVE_DIR = PROJECT_ROOT / ".context" / "message-archive" / "raw"
LEDGER = PROJECT_ROOT / ".context" / "triage-dispositions.jsonl"

# ── Dispositions ────────────────────────────────────────────────────────────
#
# ROUTED    — a handler exists and should act on this. Slice 1 records; slice 2 runs.
# SURFACED  — needs a human. Goes to /approvals. Never auto-filed as a task.
# DEFERRED  — genuinely actionable, but its handler is out of slice 1's scope.
#             Distinct from DROPPED on purpose: calling 537 peer reflections
#             "dropped" would be a lie, and surfacing them would bury the 95
#             other actionable messages under them.
# DROPPED   — a decision not to act, with a reason. Recorded, never deleted.
ROUTED, SURFACED, DEFERRED, DROPPED = "routed", "surfaced", "deferred", "dropped"

#: Dispositions that must carry a non-empty reason (A3).
REASON_REQUIRED = frozenset({DEFERRED, DROPPED})


class UnknownMessageType(Exception):
    """No rule matched. Deliberately fatal — see module docstring."""


@dataclass(frozen=True)
class Disposition:
    kind: str
    handler: str = ""
    reason: str = ""


def _d(kind: str, handler: str = "", reason: str = "") -> Disposition:
    return Disposition(kind=kind, handler=handler, reason=reason)


# ── Exact-match overrides (consulted FIRST) ─────────────────────────────────
#
# Order matters against the families below: `pickup-bug-report` starts with
# "pickup" but is a bug report, not a pickup. Exact wins.

_PICKUP = _d(ROUTED, handler="fw pickup process")
_APPROVE = _d(SURFACED, handler="/approvals")
_TELEM = lambda why: _d(DROPPED, reason=why)  # noqa: E731

EXACT: dict[str, Disposition] = {
    # -- pickup family: four spellings of one thing (T-3044 named only one) --
    "pickup": _PICKUP,
    "framework:pickup": _PICKUP,
    "framework-pickup": _PICKUP,
    "upstream-pickup": _PICKUP,

    # -- bug + gap reports: the origin case. Surfaced, never dropped. --
    "pickup-bug-report": _APPROVE,
    "pickup-bug-report-followup": _APPROVE,
    "pickup-bug-fixed": _APPROVE,
    "bug-report": _APPROVE,
    "gap-report": _APPROVE,
    "gap-cross-reference": _APPROVE,

    # -- decisions and asks that belong to the operator --
    "handoff": _APPROVE,
    "request": _APPROVE,
    "question": _APPROVE,
    "urgent": _APPROVE,
    "prod-deploy-approval": _APPROVE,
    "prod-deploy-withdraw": _APPROVE,
    "deploy-key-request": _APPROVE,
    "design-proposal": _APPROVE,

    # -- actionable, handler out of slice-1 scope --
    "reflection.envelope.v1": _d(
        DEFERRED, handler="fw context add-learning",
        reason="537 msgs — machine peer-reflection traffic (T-1271 cron); surfacing "
               "would bury the 95 other actionable messages. Handler is slice 2.",
    ),
    "note": _d(DEFERRED, handler="fw note triage",
               reason="unstructured — T-3044 IW-4, explicitly out of slice 1 scope"),
    "chat": _d(DEFERRED, handler="fw note triage",
               reason="unstructured — T-3044 IW-4, explicitly out of slice 1 scope"),
    "artifact": _d(DEFERRED, handler="fw bus",
                   reason="artifact pointer; ingestion handler is slice 2"),
    "aef-upgrade-report": _d(DEFERRED, handler="fw bus",
                             reason="consumer upgrade report; handler is slice 2"),
    "cross-arc-suggestion": _d(DEFERRED, handler="fw bus",
                               reason="cross-arc signal; handler is slice 2"),
    "cross-arc-finding": _d(DEFERRED, handler="fw bus",
                            reason="cross-arc signal; handler is slice 2"),

    # -- telemetry: high-volume machine chatter, never reaches a human --
    "heartbeat": _TELEM("liveness telemetry"),
    "fed-probe": _TELEM("federation probe telemetry"),
    "probe": _TELEM("probe telemetry"),
    "probe-shipped": _TELEM("probe telemetry"),
    "receipt": _TELEM("delivery receipt"),
    "topic_metadata": _TELEM("transport metadata"),
    "turn": _TELEM("transport turn marker"),
    "event.broadcast": _TELEM("transport broadcast envelope"),
    "test.deployment": _TELEM("deployment self-test traffic"),
    "framework:lint-test-from-122": _TELEM("lint self-test traffic"),
    "info.gc.dkim.test-sent": _TELEM("mail self-test traffic"),
    "redaction": _TELEM("moderation control message"),
    "star": _TELEM("UI reaction"),

    # -- transient fleet coordination: superseded by the state it announced --
    "milestone": _TELEM("transient coordination chatter"),
    "status": _TELEM("transient coordination chatter"),
    "debug": _TELEM("transient coordination chatter"),
    "reply": _TELEM("transient coordination chatter"),
    "deploy-spec": _TELEM("transient deploy coordination"),
    "deploy-ready-announce": _TELEM("transient deploy coordination"),
    "musl-build-ready": _TELEM("transient deploy coordination"),
    "cut-confirmed-live": _TELEM("transient deploy coordination"),
    "swap-complete": _TELEM("transient deploy coordination"),
    "blockers-ack-rebuild-inflight": _TELEM("transient deploy coordination"),
    "ack-and-followup": _TELEM("transient coordination ack"),
    "ack-fleet-observability-ship": _TELEM("transient coordination ack"),
}

# ── Prefix families (consulted SECOND, in order) ────────────────────────────
#
# 43 of the 79 measured types are singletons, so a literal table would be stale
# on the next new producer — and staleness here is invisible. Families let
# `learning-PL-099` classify itself while a genuinely new family still fails.
FAMILIES: Tuple[Tuple[str, Disposition], ...] = (
    ("dashboard.", _TELEM("dashboard telemetry")),
    ("file.", _TELEM("file-transfer chunking protocol")),
    ("fileshare-", _TELEM("file-transfer coordination")),
    ("learning-", _d(DEFERRED, handler="fw context add-learning",
                     reason="peer learning; auto-filing needs the slice-2 handler "
                            "and a review path — 15 types, 22 msgs")),
    ("penelope.", _d(DEFERRED, handler="fw bus",
                     reason="peer coordination contract traffic; handler is slice 2")),
    ("pen.", _d(DEFERRED, handler="fw bus",
                reason="peer coordination traffic; handler is slice 2")),
)


def classify(msg_type: Optional[str]) -> Disposition:
    """Map a ``msg_type`` to its disposition, or raise.

    Raising is the feature. A default branch here would turn every unrecognised
    producer into a silent drop, which is the failure this module exists to remove.
    """
    if not msg_type:
        raise UnknownMessageType("<missing msg_type>")
    if msg_type in EXACT:
        return EXACT[msg_type]
    for prefix, disp in FAMILIES:
        if msg_type.startswith(prefix):
            return disp
    raise UnknownMessageType(msg_type)


# ── Archive reading ─────────────────────────────────────────────────────────

def iter_messages(archive_dir: Optional[Path] = None) -> Iterator[Tuple[str, dict]]:
    """Yield ``(source_file, message)`` for every message in the raw archive."""
    d = Path(archive_dir or ARCHIVE_DIR)
    if not d.is_dir():
        return
    for path in sorted(d.glob("*.json")):
        try:
            blob = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            # A corrupt archive file is loud, not skipped: skipping it silently
            # is the same class of bug as a silent drop.
            raise RuntimeError(f"unreadable archive file {path.name}: {exc}") from exc
        msgs = blob if isinstance(blob, list) else (
            blob.get("messages") or blob.get("data") or [])
        if not isinstance(msgs, list):
            continue
        for m in msgs:
            if isinstance(m, dict):
                yield path.name, m


def content_key(msg: dict) -> str:
    """Stable identity: sha256 of the canonicalised message.

    Measured unique 47,879/47,879. Unlike ``(source_file, topic, offset)`` it
    survives the same message being re-recovered into a new dated archive file.
    """
    return hashlib.sha256(
        json.dumps(msg, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def locator(source_file: str, msg: dict) -> dict:
    """Human-readable pointer. Not the dedupe key — see module docstring."""
    return {"source_file": source_file, "topic": msg.get("topic"),
            "offset": msg.get("offset")}


def assert_table_complete(archive_dir: Optional[Path] = None) -> int:
    """Every type present in the LIVE archive must classify. Returns type count.

    Deliberately reads the archive rather than a declared list of types: the
    check that failed in T-3044 was one you could satisfy by editing a constant.
    """
    seen: set[str] = {m.get("msg_type") for _, m in iter_messages(archive_dir)}
    unknown = sorted(t for t in seen if not _classifies(t))
    if unknown:
        raise UnknownMessageType(
            f"{len(unknown)} msg_type(s) match no rule: {', '.join(unknown)}\n"
            f"Add an EXACT entry or a FAMILIES prefix in lib/message_router.py."
        )
    return len(seen)


def _classifies(t: Optional[str]) -> bool:
    try:
        classify(t)
        return True
    except UnknownMessageType:
        return False


# ── Ledger ──────────────────────────────────────────────────────────────────

def _existing_keys() -> set[str]:
    if not LEDGER.exists():
        return set()
    keys = set()
    with LEDGER.open() as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                keys.add(json.loads(line)["key"])
            except (json.JSONDecodeError, KeyError):
                continue
    return keys


def route(dry_run: bool = True, archive_dir: Optional[Path] = None) -> dict:
    """Classify every archived message and record one disposition row for each.

    Idempotent on ``content_key``: a second run appends zero rows. Writes are
    serialised under the T-3042 keylock rather than a second lock implementation.
    """
    assert_table_complete(archive_dir)

    seen = _existing_keys()
    rows, counts, by_type = [], {}, {}
    read = 0
    for source_file, msg in iter_messages(archive_dir):
        read += 1
        t = msg.get("msg_type")
        disp = classify(t)
        counts[disp.kind] = counts.get(disp.kind, 0) + 1
        by_type.setdefault(t, {"count": 0, "disposition": disp.kind,
                               "handler": disp.handler})["count"] += 1
        key = content_key(msg)
        if key in seen:
            continue
        seen.add(key)
        # Field is spelled `disposition`, not the dataclass's `kind`: the ledger is
        # read by an operator deciding what may act without them, and `kind` tells
        # them nothing about what it is the kind of.
        if disp.kind in REASON_REQUIRED and not disp.reason:
            raise ValueError(f"{disp.kind} disposition for {t!r} has no reason")
        row = {"key": key, "locator": locator(source_file, msg), "msg_type": t,
               "disposition": disp.kind, "handler": disp.handler,
               "reason": disp.reason,
               "ts": datetime.now(timezone.utc).isoformat()}
        rows.append(row)

    if not dry_run and rows:
        LEDGER.parent.mkdir(parents=True, exist_ok=True)
        with keylock.guarding(LEDGER):
            with LEDGER.open("a") as fh:
                for row in rows:
                    fh.write(json.dumps(row, sort_keys=True) + "\n")

    return {"dry_run": dry_run, "read": read, "new_rows": len(rows),
            "already_recorded": read - len(rows), "counts": counts,
            "by_type": by_type}


def _main(argv: list) -> int:
    dry_run = "--dry-run" in argv
    as_json = "--json" in argv
    try:
        result = route(dry_run=dry_run)
    except (UnknownMessageType, RuntimeError, ValueError) as exc:
        print(f"triage route: {exc}", file=sys.stderr)
        return 1

    if as_json:
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0

    mode = "DRY-RUN (nothing written)" if dry_run else "recorded"
    print(f"triage route — {mode}")
    print(f"  messages read      : {result['read']}")
    print(f"  new disposition rows: {result['new_rows']}")
    print(f"  already recorded   : {result['already_recorded']}")
    print("\n  by disposition:")
    for kind in (ROUTED, SURFACED, DEFERRED, DROPPED):
        if kind in result["counts"]:
            print(f"    {kind:10s} {result['counts'][kind]:6d}")
    print("\n  by type (routed / surfaced first — these are the ones that act):")
    ordered = sorted(result["by_type"].items(),
                     key=lambda kv: ({ROUTED: 0, SURFACED: 1, DEFERRED: 2,
                                      DROPPED: 3}[kv[1]["disposition"]], -kv[1]["count"]))
    for t, info in ordered:
        handler = f" → {info['handler']}" if info["handler"] else ""
        print(f"    {info['count']:6d}  {info['disposition']:10s} {t}{handler}")
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
