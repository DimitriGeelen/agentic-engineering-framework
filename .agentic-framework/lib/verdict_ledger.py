#!/usr/bin/env python3
"""verdict_ledger.py — an independent reviewer's recorded verdict closes a criterion (T-3579).

T-3557 GO 2026-09-30, slice 2. Operator principle, verbatim: "the reviewer is not a
creator or producer." Before this module, closing a task on an independent verdict took
a hand-moved criterion, `--skip-render-review` and `FW_ALLOW_PARTIAL_COMPLETE_EDIT=1` —
seven logged bypasses in two days for something the operator had ruled is the normal
path. There is no bypass flag anywhere in this path. Closing on a green verdict IS the
path.

── WHO WRITES WHAT ─────────────────────────────────────────────────────────────

A verdict is DATA written by a reviewer who is not the producer. The closing agent never
writes one; `apply` and `check-render` only READ the ledger. `record` is the writer —
slice 3 (`fw reviewer judge`) calls it from inside the reviewer worker, with that worker's
dispatch id.

    .context/reviews/verdicts.jsonl         one line per accepted verdict (committed)
    .context/reviews/refusals-interim.jsonl every non-green verdict AND every refused
                                            record attempt (committed)
    .context/reviews/applied.jsonl          one line per tick / ownership handover

The refusal ledger is INTERIM. T-3555 (the refusal ledger) is captured but not built —
`lib/refusal-ledger.sh` does not exist. Rows use the shape T-3555 specifies
(timestamp, gate, task, class, reason) so a later migration is a copy, not a
translation. When T-3555 lands, `_refuse_row` is the single place to redirect.

── THE RECORD ──────────────────────────────────────────────────────────────────

Built on lib/judge_verdict.py, not beside it: the `judgement` block IS a
`judge_verdict/1` record, so green/amber/red/unknown and "non-green needs guidance"
have exactly one implementation. The task spec's fourth outcome, `escalate`, is not a
fourth colour — it is a ROUTE: the judge could not conclude and the operator must
answer. It is stored as contract state `unknown` (which `may_proceed` already refuses)
with `outcome: escalate`. `outcome` is what callers switch on.

── PROVENANCE, AND WHAT IT DOES NOT PROVE (T-3581) ─────────────────────────────

Two independent reviewers (OpenAI, Z.ai) returned RED on the first cut: the reviewer was a
string the producer typed, and a hand-appended JSONL line was honoured. A row now counts
only when ALL of these hold — one validator (`_fault`) is used by record, apply,
check-render and `fw audit`:

  * it names a review dispatch that the dispatcher registered (HMAC-signed row in
    review-dispatches.jsonl, task-type review, issued for this task);
  * the producer set — every commit referencing the task, minus commits touching only
    .context/reviews/ — is derivable (git answered) and NON-EMPTY, and contains neither the
    reviewer string nor the dispatch's worker identity;
  * the commit that introduced the row exists (uncommitted rows do not count) and none of
    its identities is a producer;
  * the row is a well-formed judge_verdict/1 record whose outcome, verdict and judgement
    agree, whose evidence is non-empty, relative, inside the repo and still exists, and whose
    digest (title + Steps/Expected/If-not, generated annotations excluded) is the current one;
  * the criterion is REVIEWER-JUDGES NOW; the render gate needs a valid green on EVERY criterion that asks about rendering;
  * no torn line in the ledger can concern the task (torn lines fail closed and leave a
    `torn-ledger-line` refusal row);
  * the ledger is append-only as verified against git history (`load_ledger`): modified,
    deleted, duplicated or replaced rows refuse everything; rows are validated before selection.

  * (T-3580 round 2) it carries the worker's own SIGNED COMPLETION (review-completions.jsonl,
    written by `record`): the worker session (`reviewer-<dispatch id>`, fresh, not the issuer or a
    producer, and the identity `reviewer` is attributed to), the reviewed revision (an ancestor of
    the introducing commit at which the criterion has the digest the worker read and any cited
    file still has the hash it recorded), the criterion digest, the evidence hashes and a hash
    over the exact verdict; and the commit that introduced the row was made, author AND
    committer, by exactly that worker;
  * (T-3580 round 2) when the dispatch is bound to a signed review run (review-runs.jsonl):
    every required seat has its own valid completed green and the seats span the run's required
    number of distinct vendors (a single-vendor panel cannot satisfy a three-vendor one); a
    render criterion additionally needs every required page captured, with the screenshot's
    hash cited as evidence. A render criterion or a rung-5 claim with no run never counts.

The LATEST row for (task, criterion, current digest) decides. `apply` runs at every close
attempt and WITHDRAWS reviewer-derived ticks that no longer validate.

What this does not claim: every agent here is the same OS user with write access to the
repo. One that reads .context/secrets/review-dispatch.key can sign a registry row, and one
that sets a different git identity can commit a ledger row. The path is fail-closed,
audited — not forgery-proof, and `fw audit` cannot tell a coherently fabricated same-user provenance chain from a real one. It separates identities, not ROLES, and the
`rung` field records the independence the review claims (IW-3). Accepting that residual gap
is the operator's call (T-3581 Human criterion).

── WHAT A GREEN VERDICT CAN SATISFY ────────────────────────────────────────────

Only a criterion the classifier routes to REVIEWER-JUDGES (lib/delegation.py — the one
place routing is defined; this module does not re-derive it). A criterion that is
tier0-or-bypass, act-in-the-world or a sovereignty field is operator-only, so a record
against it is refused outright — not merely ignored at apply time.

── DIGEST ──────────────────────────────────────────────────────────────────────

sha256[:12] of the canonical criterion body (title + Steps/Expected/If-not; checkbox state and
generated verdict annotations excluded). The reviewer submits the digest it read
(`fw reviewer verdict digest`). Edit the criterion and the verdict no longer applies: fresh
consent. `title_digest` is the T-1985 title-only function, kept for its pin test.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
import uuid
from typing import NoReturn
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib import judge_verdict  # noqa: E402
from lib.delegation import (  # noqa: E402
    REVIEWER_JUDGES,
    classify,
    frontmatter,
    human_criteria,
)

VERDICTS = Path(".context/reviews/verdicts.jsonl")
REFUSALS = Path(".context/reviews/refusals-interim.jsonl")
APPLIED = Path(".context/reviews/applied.jsonl")
#: Review dispatches, written by the dispatcher (`fw termlink dispatch --task-type review`)
#: at spawn time and HMAC-signed. A verdict row counts only if it names one (T-3581).
DISPATCHES = Path(".context/reviews/review-dispatches.jsonl")
#: Journal of every verdict `record` wrote. A row deleted from the working ledger before it is
#: committed leaves no trace in git; the journal is what shows it existed (T-3581 round 4).
RECORDED = Path(".context/reviews/recorded.jsonl")
#: Review runs (T-3580 round 2): one signed row per `judge` run (its required seats, vendors and
#: the pages a render criterion needs with the capture result of each), plus one signed `bind`
#: row per dispatched seat. A row bound to a run counts only when the run's requirements hold.
RUNS = Path(".context/reviews/review-runs.jsonl")
#: Signed worker completions: what the worker itself reports when it records a verdict (T-3581
#: attribution requirements 1-6). A verdict row counts only if a completion agrees with it.
COMPLETIONS = Path(".context/reviews/review-completions.jsonl")
DISPATCH_KEY = Path(".context/secrets/review-dispatch.key")
REVIEW_TASK_TYPE = "review"

GREEN, AMBER, RED, ESCALATE = "green", "amber", "red", "escalate"
OUTCOMES = (GREEN, AMBER, RED, ESCALATE)
#: outcome → judge_verdict contract state. Escalate = "could not conclude".
_STATE = {GREEN: judge_verdict.GREEN, AMBER: judge_verdict.AMBER,
          RED: judge_verdict.RED, ESCALATE: judge_verdict.UNKNOWN}

GATE = "reviewer-verdict"


class VerdictRefused(ValueError):
    """A record attempt was refused. The refusal is already on the ledger."""


# ── plumbing ─────────────────────────────────────────────────────────────────


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _append(rel: Path, row: dict, root: Path) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, separators=(",", ":"), sort_keys=True) + "\n")


def _read(rel: Path, root: Path) -> list[dict]:
    p = root / rel
    if not p.is_file():
        return []
    out = []
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            continue  # a torn line must not take the whole ledger with it
    return out


def _read_strict(rel: Path, root: Path) -> tuple[list[dict], list[str]]:
    """(rows, torn) — torn is every non-blank line that is not a JSON object."""
    p = root / rel
    if not p.is_file():
        return [], []
    rows, torn = [], []
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            torn.append(line)
            continue
        (rows if isinstance(obj, dict) else torn).append(obj if isinstance(obj, dict) else line)
    return rows, torn


def _refuse_row(root: Path, task: str, cls: str, reason: str, **extra) -> None:
    """The ONE place a refusal is written — redirect here when T-3555 lands."""
    row = {"ts": _now(), "gate": GATE, "task": task, "class": cls, "reason": reason}
    row.update(extra)
    _append(REFUSALS, row, root)


def title_digest(title: str) -> str:
    """Same as lib.reviewer.static_scan._compute_ac_text_digest (T-1985); pinned by a test.

    Title only — kept for that pin. Verdicts use `criterion_digest` (title + body)."""
    return hashlib.sha256(title.encode()).hexdigest()[:12]


#: Lines the framework writes UNDER a criterion. Not part of what a reviewer judged.
_GENERATED_RE = re.compile(r"^\s*\*\*Reviewer (verdict|escalation)\b")


def criterion_body(crit) -> str:
    """Canonical substantive text of a criterion: title plus Steps/Expected/If-not.

    Excludes checkbox state (the title is the text after the box), the generated
    verdict/escalation annotations, blank lines and trailing whitespace (T-3581)."""
    lines = [crit.title.strip()]
    lines += [ln.rstrip() for ln in crit.lines[1:]
              if ln.strip() and not _GENERATED_RE.match(ln)]
    return "\n".join(lines)


def criterion_digest(crit) -> str:
    """sha256[:12] of the canonical criterion body — the digest a reviewer must submit."""
    return hashlib.sha256(criterion_body(crit).encode()).hexdigest()[:12]


def _find_task(root: Path, task_id: str) -> tuple[Path | None, str]:
    for sub in ("active", "completed"):
        d = root / ".tasks" / sub
        hits = sorted(d.glob(f"{task_id}-*.md")) + sorted(d.glob(f"{task_id}.md"))
        if hits:
            return hits[0], sub
    return None, ""


def _render_surface(root: Path, task_file: Path) -> bool:
    from lib.delegation_cli import _render_surface as rs  # same predicate as the P-013 gate
    old = os.environ.get("PROJECT_ROOT")
    os.environ["PROJECT_ROOT"] = str(root)
    try:
        return rs(task_file)
    finally:
        if old is None:
            os.environ.pop("PROJECT_ROOT", None)
        else:
            os.environ["PROJECT_ROOT"] = old


# ── review-dispatch provenance (T-3581) ─────────────────────────────────────────
#
# A verdict row is only DATA until it names a review dispatch the framework itself
# registered. The dispatcher writes the registry row when it spawns a worker with
# task-type `review`, signed with a key under .context/secrets/ (untracked). The
# reviewer's identity is then something the dispatch record says, not a string the
# producer types. Same-user honesty: an agent that can read the key can sign a row —
# this makes that a deliberate act with a trail, not a one-line append.


def _dispatch_key(root: Path, create: bool = False) -> bytes | None:
    p = root / DISPATCH_KEY
    if p.is_file():
        return p.read_bytes().strip() or None
    if not create:
        return None
    p.parent.mkdir(parents=True, exist_ok=True)
    key = uuid.uuid4().hex.encode() + uuid.uuid4().hex.encode()
    fd = os.open(str(p), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as fh:
        fh.write(key + b"\n")
    return key


def _sign(key: bytes, row: dict) -> str:
    body = {k: row[k] for k in ("dispatch_id", "task", "task_type", "issuer_session",
                                "issuer_identity", "ts")}
    return hmac.new(key, json.dumps(body, sort_keys=True, separators=(",", ":")).encode(),
                    hashlib.sha256).hexdigest()


def register_dispatch(dispatch_id: str, task_id: str, task_type: str, *,
                      issuer_session: str = "", issuer_identity: str = "",
                      root: Path | None = None) -> dict:
    """Record a dispatch. Called by the dispatcher, for every task-type, at spawn time."""
    root = root or _root()
    if not (dispatch_id or "").strip() or not (task_id or "").strip():
        raise ValueError("dispatch_id and task are required")
    if not _norm(dispatch_id):
        raise ValueError("dispatch_id has no alphanumeric characters")
    if any(r.get("dispatch_id") == dispatch_id.strip() for r in _read(DISPATCHES, root)):
        raise ValueError(f"dispatch {dispatch_id.strip()!r} is already registered — a dispatch "
                         f"id is registered once")
    row = {"dispatch_id": dispatch_id.strip(), "task": task_id.strip(),
           "task_type": (task_type or "").strip().lower(),
           "issuer_session": issuer_session, "issuer_identity": issuer_identity, "ts": _now()}
    row["sig"] = _sign(_dispatch_key(root, create=True), row)
    _append(DISPATCHES, row, root)
    return row


def dispatch_record(root: Path, dispatch_id: str) -> tuple[dict | None, str]:
    """(record, '') for a registered, correctly signed dispatch; else (None, reason)."""
    if not (dispatch_id or "").strip():
        return None, "no dispatch id — a verdict must name the review dispatch that produced it"
    rows = [r for r in _read(DISPATCHES, root) if r.get("dispatch_id") == dispatch_id]
    if not rows:
        return None, f"dispatch {dispatch_id!r} is not in the review-dispatch registry"
    key = _dispatch_key(root)
    if key is None:
        return None, "no dispatch signing key — no dispatch can be verified"
    rec = rows[0]  # first registration wins; a later row cannot re-type an earlier dispatch
    try:
        good = hmac.compare_digest(str(rec.get("sig", "")), _sign(key, rec))
    except KeyError:
        good = False
    if not good:
        return None, f"dispatch {dispatch_id!r} has an invalid signature — the registry row was not written by the dispatcher"
    return rec, ""


# ── signed worker completion + review runs (T-3580 round 2) ─────────────────────
#
# The LEDGER enforces; the judge CLI only asks. Everything below is verified by the shared
# validator (`_row_fault` / `_fault` / `satisfying_verdict`), so `apply`, `check-render` and
# `audit` all see it. Same-user honesty is unchanged: whoever can read the dispatch key can
# sign a coherent completion or run.


def _sign_row(key: bytes, row: dict) -> str:
    body = {k: v for k, v in row.items() if k != "sig"}
    return hmac.new(key, json.dumps(body, sort_keys=True, separators=(",", ":")).encode(),
                    hashlib.sha256).hexdigest()


def _signed_ok(root: Path, row: dict) -> bool:
    key = _dispatch_key(root)
    return bool(key) and hmac.compare_digest(str(row.get("sig", "")), _sign_row(key, row))


def worker_identity(dispatch_id: str) -> str:
    """The identity a review worker records and commits under: derived from its dispatch id,
    which carries a random suffix, so it is fresh per run and never a producer's or issuer's."""
    return f"reviewer-{dispatch_id.strip()}"


def verdict_hash(row: dict) -> str:
    """Hash over the canonical verdict body: outcome, guidance, evidence (+ its content hashes),
    criterion digest and reviewed revision. A row whose bytes differ from it is refused."""
    body = {"outcome": row.get("outcome"), "guidance": row.get("guidance", ""),
            "evidence": row.get("evidence"), "evidence_sha256": row.get("evidence_sha256") or {},
            "ac_digest": row.get("ac_digest"), "revision": row.get("revision", "")}
    return hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _head_sha(root: Path) -> str:
    rc, out = _git_out(root, "rev-parse", "-q", "--verify", "HEAD")
    return out.strip() if rc == 0 else ""


def _criterion_at(root: Path, rev: str, task_id: str, ac: int) -> str | None:
    """Digest of Human criterion `ac` of `task_id` as it stood at `rev`; None if it did not exist."""
    rc, listing = _git_out(root, "ls-tree", "-r", "--name-only", rev, "--", ".tasks/active", ".tasks/completed")
    if rc != 0:
        return None
    name = next((ln for ln in listing.splitlines()
                 if Path(ln).name.startswith(f"{task_id}-") or Path(ln).name == f"{task_id}.md"), None)
    if not name:
        return None
    rc, blob = _git_out(root, "show", f"{rev}:{name}")
    if rc != 0:
        return None
    crit = next((c for c in human_criteria(blob) if c.index == ac), None)
    return criterion_digest(crit) if crit else None


def make_completion(root: Path, row: dict) -> dict:
    """The signed completion the worker posts for `row` (called from `record`, inside the worker)."""
    body = {"kind": "completion", "dispatch_id": row["dispatch_id"], "task": row["task"],
            "ac": row["ac"], "verdict_id": row["id"], "worker": row["worker"],
            "revision": row["revision"], "ac_digest": row["ac_digest"],
            "evidence_sha256": row.get("evidence_sha256") or {},
            "verdict_sha256": verdict_hash(row), "ts": _now()}
    key = _dispatch_key(root)
    if key is None:
        raise VerdictRefused("no dispatch signing key — no completion can be signed")
    body["sig"] = _sign_row(key, body)
    return body


def _completion_for(root: Path, verdict_id: str) -> dict | None:
    return next((c for c in _read(COMPLETIONS, root) if c.get("verdict_id") == verdict_id), None)


def register_run(run_id: str, task_id: str, *, acs: list[int], rung: str, seats: list[dict],
                 required_vendors: int = 1, pages: dict | None = None, captures: list | None = None,
                 inputs: dict | None = None, reason: str = "", degraded: str = "",
                 root: Path | None = None) -> dict:
    """(judge, before dispatching) record a review run: the seats it requires, how many distinct
    vendors it demands, and for render criteria the pages that must have been seen with the
    capture result of each. Signed; a partial capture failure is kept, never discarded."""
    root = root or _root()
    if any(r.get("kind") == "run" and r.get("run_id") == run_id for r in _read(RUNS, root)):
        raise ValueError(f"run {run_id!r} is already registered")
    key = _dispatch_key(root, create=True)
    row = {"kind": "run", "run_id": run_id, "task": task_id, "acs": sorted(acs), "rung": rung,
           "seats": [{"seat": s["seat"], "vendor": s["vendor"]} for s in seats],
           "required_vendors": int(required_vendors),
           "pages": {str(k): list(v) for k, v in (pages or {}).items()},
           "captures": [dict(c) for c in (captures or [])], "inputs": inputs or {},
           "reason": reason, "degraded": degraded, "ts": _now()}
    row["sig"] = _sign_row(key, row)
    _append(RUNS, row, root)
    return row


def _verified_run(root: Path, run_id: str) -> tuple[dict | None, str]:
    rows = [r for r in _read(RUNS, root) if r.get("kind") == "run" and r.get("run_id") == run_id]
    if not rows:
        return None, f"run {run_id!r} is not registered"
    if not _signed_ok(root, rows[0]):
        return None, f"run {run_id!r} has an invalid signature"
    return rows[0], ""


def bind_dispatch(run_id: str, seat: str, dispatch_id: str, vendor: str, *,
                  root: Path | None = None) -> dict:
    """(judge, after dispatching a seat) bind the dispatch to its run and seat. `vendor` is the
    vendor argument the dispatcher was actually invoked with, not the seat's label."""
    root = root or _root()
    run, why = _verified_run(root, run_id)
    if run is None:
        raise ValueError(why)
    if seat not in {s["seat"] for s in run["seats"]}:
        raise ValueError(f"seat {seat!r} is not a seat of run {run_id!r}")
    drec, why = dispatch_record(root, dispatch_id)
    if drec is None or drec.get("task") != run["task"]:
        raise ValueError(why or f"dispatch {dispatch_id!r} was issued for another task")
    if any(r.get("kind") == "bind" and r.get("dispatch_id") == dispatch_id for r in _read(RUNS, root)):
        raise ValueError(f"dispatch {dispatch_id!r} is already bound")
    row = {"kind": "bind", "run_id": run_id, "seat": seat, "dispatch_id": dispatch_id,
           "vendor": vendor, "task": run["task"], "ts": _now()}
    row["sig"] = _sign_row(_dispatch_key(root, create=True), row)
    _append(RUNS, row, root)
    return row


def run_for_dispatch(root: Path, dispatch_id: str) -> tuple[dict | None, dict | None, str]:
    """(run, bind, why). (None, None, '') when the dispatch is simply not part of any run;
    a non-empty `why` means a run/bind row exists but does not verify."""
    binds = [r for r in _read(RUNS, root) if r.get("kind") == "bind" and r.get("dispatch_id") == dispatch_id]
    if not binds:
        return None, None, ""
    bind = binds[0]
    if not _signed_ok(root, bind):
        return None, None, f"the run binding of dispatch {dispatch_id!r} has an invalid signature"
    run, why = _verified_run(root, bind.get("run_id", ""))
    if run is None:
        return None, None, why
    return run, bind, ""


# ── identity / producer ──────────────────────────────────────────────────────


def _norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())


def _identity_keys(identity: str) -> set[str]:
    """Full string plus the model part after `/` or `:` — 'openai/gpt-5' matches 'GPT-5'."""
    keys = {_norm(identity)}
    for sep in ("/", ":"):
        if sep in identity:
            keys.add(_norm(identity.rsplit(sep, 1)[1]))
    keys.discard("")
    return keys


_TRAILER_RE = re.compile(r"^\s*Co-Authored-By:\s*(.+?)\s*$", re.IGNORECASE | re.MULTILINE)
#: A commit touching only these paths is a reviewer's record, not the task's work.
_REVIEW_DIR = ".context/reviews/"


def _identities(parts: list[str], message: str) -> set[str]:
    found = {p.strip() for p in parts if p.strip()}
    for t in _TRAILER_RE.findall(message):
        found.add(t)
        m = re.match(r"(.*?)\s*<([^>]*)>", t)
        if m:
            found.update(x.strip() for x in m.groups() if x.strip())
    return found


def producers_checked(root: Path, task_id: str, task_text: str = "") -> tuple[set[str], str]:
    """(identities, error). Derived from git, never self-reported.

    Every commit whose message references the task id contributes its author and
    committer name/email and every Co-Authored-By trailer; a `producer:` /
    `producers:` frontmatter field adds to the set. A commit whose every changed path
    is under .context/reviews/ is a reviewer's record, not work, and is skipped.

    `error` is non-empty when git could not answer — callers treat that as REFUSE, never
    as "no producers" (T-3581: an empty set is not evidence of independence)."""
    found: set[str] = set()
    try:
        cp = subprocess.run(
            ["git", "log", "--all", f"--grep={task_id}", "--name-only",
             "--format=%x1e%an%x1f%ae%x1f%cn%x1f%ce%x1f%B%x1d"],
            cwd=str(root), capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        return set(), f"git failed: {e}"
    if cp.returncode != 0:
        return set(), f"git log failed (rc={cp.returncode}): {cp.stderr.strip()[:120]}"
    ref = re.compile(rf"(?<![A-Za-z0-9-]){re.escape(task_id)}(?![0-9])")
    for rec in cp.stdout.split("\x1e"):
        if "\x1d" not in rec:
            continue
        head, files = rec.split("\x1d", 1)
        parts = head.split("\x1f")
        if len(parts) < 5 or not ref.search(parts[4]):
            continue
        paths = [f for f in files.splitlines() if f.strip()]
        if paths and all(f.startswith(_REVIEW_DIR) for f in paths):
            continue
        found |= _identities(parts[:4], parts[4])
    fm = frontmatter(task_text) if task_text else {}
    for key in ("producer", "producers"):
        v = fm.get(key)
        if isinstance(v, (list, tuple)):
            found.update(str(x) for x in v if str(x).strip())
        elif v:
            found.update(x.strip() for x in re.split(r"[,\[\]]", str(v)) if x.strip())
    return found, ""


def producers(root: Path, task_id: str, task_text: str = "") -> set[str]:
    """Identities that produced the task's work (see `producers_checked`)."""
    return producers_checked(root, task_id, task_text)[0]


def is_producer(identity: str, produced_by: set[str]) -> str:
    """The producer identity `identity` collides with, or ''."""
    mine = _identity_keys(identity)
    for p in produced_by:
        if mine & _identity_keys(p):
            return p
    return ""


def _dispatch_is_producer(dispatch_id: str, produced_by: set[str]) -> str:
    """A worker commits as `dispatch+<id>@…`; if that identity produced work, it is no reviewer."""
    d = _norm(dispatch_id)
    if not d:
        return ""
    return next((p for p in produced_by if d in _norm(p)), "")


_ROW_ID_RE = re.compile(r"^T-\d+$")


class Ledger:
    """verdicts.jsonl as VERIFIED against the accepted history (T-3581 round 3).

    The file is append-only, and git is what proves it. For every commit on HEAD that touched
    the file, the previous content must be an exact line-prefix of the new content: a row that
    was modified, deleted (a withdrawal included) or replaced breaks the chain and the whole
    ledger refuses. The working file must have the committed content as its exact prefix; the
    lines beyond it are UNCOMMITTED and never count. A row's introducing commit is the commit
    whose diff first contains its bytes — established by the walk, not by a text search.

      committed  [(row, intro)]  intro = {"sha", "ids"}; in ledger order
      pending    [row]           in the working file, not in HEAD
      torn       [line]          committed or pending, not a JSON object
      faults     [str]           integrity failures — non-empty means nothing is trustworthy
      missing    [(id, task)]    journalled by `record` but absent from the ledger: deleted
                                 before it was committed. Blocks that task's criteria.
    """

    def __init__(self) -> None:
        self.committed: list[tuple[dict, dict]] = []
        self.pending: list[dict] = []
        self.torn: list[str] = []
        self.faults: list[str] = []
        self.missing: list[tuple[str, str]] = []   # (verdict id, task) recorded but gone

    def entries(self):
        for row, intro in self.committed:
            yield row, intro
        for row in self.pending:
            yield row, None

    def intro(self, row_id: str) -> dict | None:
        return next((i for r, i in self.committed if r.get("id") == row_id), None)


def _git_out(root: Path, *args: str) -> tuple[int, str]:
    cp = subprocess.run(["git", *args], cwd=str(root), capture_output=True, text=True, timeout=60)
    return cp.returncode, cp.stdout


def _nonblank(text: str) -> list[str]:
    return [ln for ln in text.split("\n") if ln.strip()]


def load_ledger(root: Path) -> Ledger:
    led = Ledger()
    cur = _nonblank((root / VERDICTS).read_text(encoding="utf-8", errors="replace")) \
        if (root / VERDICTS).is_file() else []
    try:
        rc, _ = _git_out(root, "rev-parse", "-q", "--verify", "HEAD")
        if rc == 128:
            led.faults.append("git cannot answer (not a repository) — ledger history is unverifiable")
            return led
        history = ""
        if rc == 0:
            rc, history = _git_out(
                root, "log", "--reverse", "--format=%x1e%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%B%x1d",
                "HEAD", "--", str(VERDICTS))
            if rc != 0:
                led.faults.append(f"git log failed (rc={rc}) — ledger history is unverifiable")
                return led
        prev: list[str] = []
        seen: set[str] = set()
        for rec in history.split("\x1e"):
            if "\x1d" not in rec:
                continue
            parts = rec.split("\x1d", 1)[0].split("\x1f")
            if len(parts) < 6:
                continue
            sha = parts[0].strip()
            rc, blob = _git_out(root, "show", f"{sha}:{VERDICTS}")
            lines = _nonblank(blob) if rc == 0 else []
            if lines[:len(prev)] != prev:
                led.faults.append(
                    f"commit {sha[:9]} modified, deleted or replaced committed ledger rows — "
                    f"the ledger is append-only")
                return led
            intro = {"sha": sha, "ids": _identities(parts[1:5], parts[5]),
                     "names": {parts[1].strip(), parts[3].strip()}}
            for ln in lines[len(prev):]:
                obj = _parse(ln)
                if obj is None:
                    led.torn.append(ln)
                    continue
                rid = obj.get("id")
                if isinstance(rid, str) and rid in seen:
                    led.faults.append(f"duplicate row id {rid!r} (again in {sha[:9]})")
                    return led
                if isinstance(rid, str):
                    seen.add(rid)
                led.committed.append((obj, intro))
            prev = lines
    except (OSError, subprocess.SubprocessError) as e:
        led.faults.append(f"git failed: {e} — ledger history is unverifiable")
        return led
    if cur[:len(prev)] != prev:
        led.faults.append("the working ledger does not contain the committed rows unchanged — a "
                          "committed row was modified, deleted or replaced")
        return led
    for ln in cur[len(prev):]:
        obj = _parse(ln)
        if obj is None:
            led.torn.append(ln)
            continue
        rid = obj.get("id")
        if isinstance(rid, str) and any(r.get("id") == rid for r, _ in led.entries()):
            led.faults.append(f"duplicate row id {rid!r} in the uncommitted rows")
            return led
        led.pending.append(obj)
    have = {r.get("id") for r, _ in led.entries()}
    for j in _read(RECORDED, root):
        if j.get("verdict_id") not in have:
            led.missing.append((str(j.get("verdict_id")), str(j.get("task"))))
    return led


def _parse(line: str) -> dict | None:
    try:
        obj = json.loads(line)
    except ValueError:
        return None
    return obj if isinstance(obj, dict) else None


# ── eligibility — ONE validator for record, apply, check-render and audit ────


class _Base:
    """What a row is judged against that does not depend on the CURRENT criterion text."""

    def __init__(self, root: Path, task_id: str, text: str):
        self.root, self.task_id, self.text = root, task_id, text
        self._prod: tuple[set[str], str] | None = None

    @property
    def prod(self) -> tuple[set[str], str]:
        if self._prod is None:
            self._prod = producers_checked(self.root, self.task_id, self.text)
        return self._prod


class _Ctx(_Base):
    """Everything a verdict is judged against for one task, computed once per call."""

    def __init__(self, root: Path, task_id: str, path: Path, text: str):
        super().__init__(root, task_id, text)
        self.path = path
        fm = frontmatter(text)
        self.workflow = str(fm.get("workflow_type") or "").strip().lower()
        self.owner = str(fm.get("owner") or "")
        self.render = _render_surface(root, path)
        self._ledger: Ledger | None = None

    @property
    def ledger(self) -> Ledger:
        if self._ledger is None:
            self._ledger = load_ledger(self.root)
        return self._ledger

    def classify(self, crit):
        return classify(crit, workflow_type=self.workflow, render_surface=self.render)


def _evidence_fault(root: Path, e: str) -> str:
    if os.path.isabs(e) or e.startswith(("~", "\\")):
        return f"evidence path {e!r} is absolute — must be relative to the repo"
    try:
        rp = root.resolve()
        target = (root / e).resolve()
        inside = target == rp or rp in target.parents
    except (OSError, RuntimeError):
        return f"evidence path {e!r} cannot be resolved"
    if not inside:
        return f"evidence path {e!r} resolves outside the repo"
    if not target.exists():
        return f"evidence path {e!r} does not exist under the repo"
    return ""


def _hash_path(target: Path) -> str:
    """sha256 of a file, or of a directory's sorted (relative path, content hash) listing."""
    h = hashlib.sha256()
    if target.is_dir():
        for f in sorted(x for x in target.rglob("*") if x.is_file() and ".git" not in x.parts):
            h.update(str(f.relative_to(target)).encode() + b"\0")
            h.update(hashlib.sha256(f.read_bytes()).digest())
    elif target.is_file():
        h.update(target.read_bytes())
    else:
        return ""
    return h.hexdigest()


_REQUIRED = ("id", "task", "ac", "ac_digest", "outcome", "verdict", "reviewer", "rung",
             "dispatch_id", "evidence", "judgement")


def _structural_fault(row: dict) -> str:
    """'' when `row` is a well-formed verdict record; else why not. Independent of any task."""
    miss = [k for k in _REQUIRED if k not in row]
    if miss:
        return f"row is missing {', '.join(miss)}"
    for k in ("id", "task", "ac_digest", "reviewer", "rung", "dispatch_id", "verdict"):
        if not isinstance(row[k], str) or not row[k].strip():
            return f"row field {k} is not a non-empty string"
    if not _ROW_ID_RE.match(row["task"]):
        return f"row task {row['task']!r} is not a task id"
    if isinstance(row["ac"], bool) or not isinstance(row["ac"], int):
        return "row ac is not an integer"
    if row["outcome"] not in OUTCOMES:
        return f"row has an unknown outcome {row['outcome']!r}"
    if not isinstance(row["evidence"], list):
        return "row has a non-list evidence field"
    jv = row["judgement"]
    if (not isinstance(jv, dict) or jv.get("contract") != "judge_verdict/1"
            or jv.get("judge") != row["reviewer"]
            or jv.get("state") != _STATE.get(row["outcome"])):
        return "judgement block is not a judge_verdict/1 record agreeing with the row"
    if jv.get("judged") != f"{row['task']}#AC{row['ac']}":
        return "judgement block judges a different criterion than the row names"
    if row["verdict"] != jv.get("state"):
        return "row verdict disagrees with its judgement"
    return ""


def _completion_fault(base: _Base, row: dict, intro: dict | None, need_commit: bool,
                      completion: dict | None) -> tuple[str, str] | None:
    """The six worker-attribution requirements (T-3581 round 3, T-3580 round 2). A row counts only
    if the worker's own signed completion agrees with it on every binding, and the commit that
    introduced the row was made by exactly that worker."""
    root = base.root
    comp = completion or _completion_for(root, str(row.get("id")))
    if comp is None:
        return "no-completion", (f"row {row.get('id')} has no signed worker completion — a "
                                 f"registration is not a completion")
    if completion is None and not _signed_ok(root, comp):
        return "bad-completion", "the worker completion has an invalid signature"
    worker = str(row.get("worker") or "")
    if not worker:
        return "no-worker", "the row names no worker session"
    for k, want in (("dispatch_id", row.get("dispatch_id")), ("task", row.get("task")),
                    ("ac", row.get("ac")), ("verdict_id", row.get("id")), ("worker", worker),
                    ("revision", row.get("revision")), ("ac_digest", row.get("ac_digest"))):
        if comp.get(k) != want:
            return "completion-mismatch", (f"the worker completion's {k} ({comp.get(k)!r}) is not "
                                           f"the row's ({want!r})")
    if (comp.get("evidence_sha256") or {}) != (row.get("evidence_sha256") or {}):
        return "completion-mismatch", "the worker completion's evidence hashes are not the row's"
    if comp.get("verdict_sha256") != verdict_hash(row):
        return "verdict-tampered", ("the row's bytes differ from the verdict the worker reported "
                                    "(verdict hash mismatch)")
    # 1. fresh session: derived from the dispatch, not the issuer's, not a producer's
    if _norm(worker) != _norm(worker_identity(str(row["dispatch_id"]))):
        return "worker-not-fresh", f"worker {worker!r} is not the identity of dispatch {row['dispatch_id']!r}"
    if _norm(worker) not in _norm(str(row.get("reviewer"))):
        return "reviewer-worker-mismatch", (f"reviewer {row.get('reviewer')!r} is not attributed to "
                                            f"worker {worker!r}")
    drec, _ = dispatch_record(root, str(row["dispatch_id"]))
    if drec and _norm(worker) in {_norm(drec.get("issuer_session", "")), _norm(drec.get("issuer_identity", ""))} - {""}:
        return "worker-not-fresh", f"worker {worker!r} is the dispatch issuer"
    prod, _err = base.prod
    hit = is_producer(worker, prod) if prod else ""
    if hit:
        return "reviewer-is-producer", f"worker {worker!r} matches producer {hit!r}"
    # 2/3/4. the reviewed revision holds the criterion the worker read and the evidence it cites
    rev = str(row.get("revision") or "")
    rc, _ = _git_out(root, "cat-file", "-e", f"{rev}^{{commit}}") if rev else (1, "")
    if rc != 0:
        return "revision", f"reviewed revision {rev!r} is not a commit of this repository"
    if _criterion_at(root, rev, str(row["task"]), int(row["ac"])) != row["ac_digest"]:
        return "revision", (f"at reviewed revision {rev[:9]} the criterion is not the text the "
                            f"worker digested ({row['ac_digest']})")
    for e, h in (row.get("evidence_sha256") or {}).items():
        shown = subprocess.run(["git", "show", f"{rev}:{e}"], cwd=str(root), capture_output=True)
        if shown.returncode == 0 and hashlib.sha256(shown.stdout).hexdigest() != h:
            return "revision", f"evidence {e!r} at reviewed revision {rev[:9]} is not what the worker hashed"
    if intro is not None:
        rc, _ = _git_out(root, "merge-base", "--is-ancestor", rev, intro["sha"])
        if rc != 0:
            return "revision", f"reviewed revision {rev[:9]} is not an ancestor of the commit that added the row"
        # 6. attributed to exactly that worker
        if intro.get("names") != {worker}:
            return "introduced-by-other", (
                f"the commit that added this row ({intro['sha'][:9]}) was made by "
                f"{sorted(intro.get('names') or [])}, not by its worker {worker!r}")
    return None


def _row_fault(base: _Base, row: dict, intro: dict | None, *, need_commit: bool = True,
               completion: dict | None = None) -> tuple[str, str] | None:
    """(class, reason) when `row` is not a valid, attributable record for base.task_id.

    HISTORICAL integrity — nothing here depends on the criterion's CURRENT text, so a
    verdict that was later superseded by an edit still passes. Used by apply AND audit
    (one validator, T-3581). A green must clear every check; a non-green only needs to be
    attributable, because all a non-green can do is keep a criterion open."""
    why = _structural_fault(row)
    if why:
        return "schema", why
    if row["task"] != base.task_id:
        return "schema", "row does not name this task"
    why = _provenance_fault(base.root, base.task_id, row)
    if why:
        return "no-provenance", why
    f = _completion_fault(base, row, intro, need_commit, completion)
    if f:
        return f
    if row["outcome"] != GREEN:
        g = row.get("guidance")
        if not isinstance(g, str) or not g.strip():
            return "no-guidance", "a non-green verdict needs guidance"
        if need_commit and intro is None:
            return "uncommitted", f"row {row['id']} was never committed (no commit introduces it)"
        return None
    if not row["evidence"] or not all(isinstance(e, str) and e.strip() for e in row["evidence"]):
        return "no-evidence", "a green verdict needs at least one evidence path"
    for e in row["evidence"]:
        why = _evidence_fault(base.root, e)
        if why:
            return "evidence", why
    hashes = row.get("evidence_sha256")
    if not isinstance(hashes, dict):
        return "evidence-hash", "a green verdict must record a content hash per evidence file"
    for e in row["evidence"]:
        if hashes.get(e) != _hash_path((base.root / e).resolve()):
            return "evidence-hash", (f"evidence {e!r} changed since the reviewer recorded it "
                                     f"(content hash mismatch)")
    prod, err = base.prod
    if err:
        return "no-producer-provenance", f"{err} — producer provenance unavailable, refusing"
    if not prod:
        return "no-producer-provenance", (
            f"no commit references {base.task_id}, so who produced it is unknown — a verdict "
            f"cannot prove independence from an unknown producer")
    hit = is_producer(str(row["reviewer"]), prod)
    if hit:
        return "reviewer-is-producer", (
            f"reviewer {row['reviewer']!r} matches {hit!r}, who committed work for "
            f"{base.task_id}; the reviewer is never the producer")
    hit = _dispatch_is_producer(str(row["dispatch_id"]), prod)
    if hit:
        return "reviewer-is-producer", (
            f"dispatch {row['dispatch_id']!r} worker identity {hit!r} committed work for "
            f"{base.task_id}; the reviewer is never the producer")
    if need_commit:
        if intro is None:
            return "uncommitted", f"row {row['id']} was never committed (no commit introduces it)"
        hit = next((p for i in intro["ids"] if (p := is_producer(i, prod))), "")
        if hit:
            return "introduced-by-producer", (
                f"the commit that added this row ({intro['sha'][:9]}) was authored by "
                f"{hit!r}, a producer of {base.task_id}")
    return None


def _is_render_review(ctx: "_Ctx", crit) -> bool:
    return (ctx.classify(crit).cls == "render-surface"
            and bool(_RENDER_REVIEW_RE.search(criterion_body(crit))))


def _run_fault(ctx: "_Ctx", row: dict, crit, recording: bool) -> tuple[str, str] | None:
    """A green's run requirements (T-3580 round 2): a panel-rung claim and a render criterion
    both need a signed run; a render green needs every required page seen (verified screenshot
    evidence cited)."""
    root = ctx.root
    render = _is_render_review(ctx, crit)
    claimed = str(row.get("run_id") or "")
    if recording:
        run, why = _verified_run(root, claimed) if claimed else (None, "")
    else:
        run, _bind, why = run_for_dispatch(root, str(row["dispatch_id"]))
    if why:
        return "run", why
    if run is None:
        if claimed:
            return "run-unbound", f"the row claims run {claimed!r} but its dispatch is not bound to it"
        if str(row["rung"]).startswith("rung-5"):
            return "panel-needs-run", "a rung-5 panel verdict must belong to a registered review run"
        if render:
            return "render-needs-run", ("a render criterion needs a review run that recorded the "
                                        "pages required and their capture results")
        return None
    if run.get("task") != ctx.task_id or row["ac"] not in (run.get("acs") or []):
        return "run", f"run {run.get('run_id')!r} does not cover {ctx.task_id} AC#{row['ac']}"
    if claimed != run["run_id"]:
        return "run-unbound", f"the row names run {claimed!r}, its dispatch is bound to {run['run_id']!r}"
    if render:
        pages = (run.get("pages") or {}).get(str(row["ac"])) or []
        if not pages:
            return "unseen-page", "no required page was recorded for this render criterion"
        caps = {c.get("page"): c for c in run.get("captures") or []}
        cited = set((row.get("evidence_sha256") or {}).values())
        for p in pages:
            c = caps.get(p)
            if not c or not c.get("ok") or not c.get("sha256"):
                why = (c or {}).get("error") or "no capture result"
                return "unseen-page", f"required page {p!r} has no verified screenshot ({why})"
            if c["sha256"] not in cited:
                return "unseen-page", f"the screenshot of {p!r} is not cited as evidence"
    return None


def _fault(ctx: _Ctx, row: dict, crit, intro: dict | None, *, need_commit: bool = True,
           completion: dict | None = None) -> tuple[str, str] | None:
    """(class, reason) when `row` may NOT satisfy `crit` right now: historical integrity
    (`_row_fault`) PLUS current eligibility — the row names this criterion, the criterion text
    is unchanged, and the criterion is still reviewer-judged."""
    if not _structural_fault(row):
        if row["ac"] != crit.index:
            return "schema", "row does not name this criterion"
        if row["ac_digest"] != criterion_digest(crit):
            return "digest-mismatch", "the criterion changed after the reviewer read it"
    f = _row_fault(ctx, row, intro, need_commit=need_commit, completion=completion)
    if f:
        return f
    if row["outcome"] == GREEN:
        cl = ctx.classify(crit)
        if cl.delegation_class != REVIEWER_JUDGES:
            return "not-reviewer-judged", (
                f"AC#{crit.index} is {cl.cls} ({cl.delegation_class}): only the operator may "
                f"answer it, so no reviewer verdict can satisfy or escalate it — {cl.reason}")
        return _run_fault(ctx, row, crit, recording=completion is not None)
    return None


def _provenance_fault(root: Path, task_id: str, row: dict) -> str:
    """'' when the row names a registered review dispatch for this task, else why not."""
    drec, why = dispatch_record(root, str(row.get("dispatch_id") or ""))
    if drec is None:
        return why
    if drec.get("task_type") != REVIEW_TASK_TYPE:
        return f"dispatch task-type is {drec.get('task_type')!r}, not {REVIEW_TASK_TYPE!r}"
    if drec.get("task") != task_id:
        return f"dispatch was issued for {drec.get('task')!r}"
    return ""


def _torn_for(root: Path, task_id: str, torn: list[str]) -> list[str]:
    """Torn lines that could concern `task_id`: it is named in them, or no task is legible."""
    hits = []
    for line in torn:
        m = re.search(r'"task"\s*:\s*"(T-\d+)"', line)
        if m is None or m.group(1) == task_id:
            hits.append(line)
    return hits


def _note_torn(root: Path, task_id: str, lines: list[str]) -> None:
    """Diagnostic refusal row per distinct torn line (deduplicated on its sha)."""
    seen = {r.get("line_sha") for r in _read(REFUSALS, root) if r.get("class") == "torn-ledger-line"}
    for ln in lines:
        sha = hashlib.sha256(ln.encode()).hexdigest()[:12]
        if sha not in seen:
            _refuse_row(root, task_id, "torn-ledger-line",
                        "unparseable line in verdicts.jsonl — verdicts for the affected task "
                        "are refused until it is repaired", line_sha=sha, line=ln[:200])
            seen.add(sha)


def satisfying_verdict(ctx: _Ctx, crit) -> tuple[dict | None, str]:
    """(green row, '') that satisfies `crit`, else (None, why).

    Order matters (T-3581 round 3): the ledger's integrity first; then every row that could
    concern this criterion is VALIDATED before anything is selected by digest, so a malformed
    row cannot be filtered out and thereby resurrect an older green. The LATEST committed row
    for (task, criterion, current digest) decides: a later red withdraws an earlier green and
    an invalid latest green is not replaced by an older valid one. A row for other criterion
    text never counts. Torn lines, uncommitted rows for this criterion and rows that name no
    legible task all fail closed."""
    led = ctx.ledger
    if led.faults:
        return None, f"ledger-integrity: {led.faults[0]}"
    gone = [v for v, t in led.missing if t == ctx.task_id]
    if gone:
        return None, (f"deleted-verdict: {gone[0]} was recorded for this task but is not in the "
                      f"ledger — a verdict was removed before it was committed; refusing")
    bad = _torn_for(ctx.root, ctx.task_id, led.torn)
    if bad:
        _note_torn(ctx.root, ctx.task_id, bad)
        return None, "the verdict ledger has an unparseable line — refusing until repaired"
    dg = criterion_digest(crit)
    mine: list[dict] = []
    for row, intro in led.entries():
        t = row.get("task")
        if not isinstance(t, str) or not _ROW_ID_RE.match(t):
            return None, (f"schema: row {row.get('id', '?')!r} names no legible task — "
                          f"refusing until the ledger is repaired")
        if t != ctx.task_id:
            continue
        a = row.get("ac")
        if isinstance(a, int) and not isinstance(a, bool) and a != crit.index:
            continue                                  # names another criterion of this task
        why = _structural_fault(row)
        if why:
            return None, f"schema: malformed row {row.get('id', '?')!r} names this criterion — {why}"
        if row["ac_digest"] != dg:
            continue
        if intro is None:
            return None, f"uncommitted: row {row['id']} for this criterion is not in the accepted history"
        mine.append(row)
    if not mine:
        return None, "no verdict for the current criterion text"
    last = mine[-1]
    if last.get("outcome") != GREEN:
        return None, f"latest verdict is {last.get('outcome')!r}"
    f = _fault(ctx, last, crit, led.intro(last["id"]))
    if f:
        return None, f"{f[0]}: {f[1]}"
    why = _panel_fault(ctx, crit, last, mine)
    if why:
        return None, why
    return last, ""


def _panel_fault(ctx: _Ctx, crit, last: dict, mine: list[dict]) -> str:
    """'' unless `last` belongs to a run whose requirements are not all met: every required seat
    needs its own valid, completed green for this criterion, and the seats must span the run's
    required number of distinct vendors (a single-vendor panel cannot satisfy a three-vendor one)."""
    root, led = ctx.root, ctx.ledger
    run, _bind, _why = run_for_dispatch(root, str(last["dispatch_id"]))
    if run is None:
        return ""
    vendors: set[str] = set()
    for s in run["seats"]:
        seat_rows = []
        for r in mine:
            rr, bb, _ = run_for_dispatch(root, str(r["dispatch_id"]))
            if rr is not None and rr["run_id"] == run["run_id"] and bb["seat"] == s["seat"]:
                seat_rows.append((r, bb))
        if not seat_rows:
            return f"panel-incomplete: required seat {s['seat']!r} of run {run['run_id']} has no verdict"
        r, bb = seat_rows[-1]
        if r.get("outcome") != GREEN:
            return f"panel-incomplete: seat {s['seat']!r} of run {run['run_id']} is {r.get('outcome')!r}"
        f = _fault(ctx, r, crit, led.intro(r["id"]))
        if f:
            return f"panel-incomplete: seat {s['seat']!r} has no valid green — {f[0]}: {f[1]}"
        vendors.add(str(bb.get("vendor")))
    if len(vendors) < int(run.get("required_vendors") or 1):
        return (f"degraded: run {run['run_id']} demands {run.get('required_vendors')} vendor(s), "
                f"its seats span {len(vendors)} ({', '.join(sorted(vendors))}) — a single-vendor "
                f"panel cannot satisfy a multi-vendor requirement")
    return ""


def _task_ctx(root: Path, task_id: str) -> _Ctx | None:
    path, sub = _find_task(root, task_id)
    if path is None or sub != "active":
        return None
    return _Ctx(root, task_id, path, path.read_text(encoding="utf-8", errors="replace"))


# ── record ───────────────────────────────────────────────────────────────────


def record(task_id: str, ac_index: int, outcome: str, *, reviewer: str, rung: str,
           guidance: str = "", evidence: list[str] | None = None,
           digest: str = "", dispatch_id: str = "", run_id: str = "",
           root: Path | None = None) -> dict:
    """Append a verdict for Human criterion `ac_index` of `task_id`, or raise VerdictRefused.

    Every refusal is written to the refusal ledger before it is raised. `digest` is what the
    reviewer read (`fw reviewer verdict digest`); it is required.
    """
    root = root or _root()
    evidence = [e for e in (evidence or []) if e and e.strip()]
    outcome = (outcome or "").strip().lower()

    def refuse(cls: str, reason: str) -> NoReturn:
        _refuse_row(root, task_id, cls, reason, ac=ac_index, reviewer=reviewer,
                    dispatch_id=dispatch_id)
        raise VerdictRefused(reason)

    if outcome not in OUTCOMES:
        refuse("bad-outcome", f"outcome {outcome!r} is not one of {', '.join(OUTCOMES)}")
    if not (reviewer or "").strip():
        refuse("no-reviewer", "reviewer identity is required (session/model/vendor)")
    if not (rung or "").strip():
        refuse("no-rung", "rung is required — how independent this review claims to be (IW-3)")

    drec, why = dispatch_record(root, dispatch_id)
    if drec is None:
        refuse("no-dispatch", why)
    if drec.get("task_type") != REVIEW_TASK_TYPE:
        refuse("not-review-dispatch",
               f"dispatch {dispatch_id!r} has task-type {drec.get('task_type')!r}, not "
               f"{REVIEW_TASK_TYPE!r} — only a review dispatch may write a verdict")
    if drec.get("task") != task_id:
        refuse("dispatch-task-mismatch",
               f"dispatch {dispatch_id!r} was issued for {drec.get('task')!r}, not {task_id}")

    path, sub = _find_task(root, task_id)
    if path is None:
        refuse("no-task", f"task {task_id} not found")
    if sub != "active":
        refuse("task-closed", f"{task_id} is in .tasks/{sub}; a settled task is not re-judged")
    ctx = _Ctx(root, task_id, path, path.read_text(encoding="utf-8", errors="replace"))
    text = ctx.text

    crit = next((c for c in human_criteria(text) if c.index == ac_index), None)
    if crit is None:
        refuse("no-criterion", f"{task_id} has no Human criterion #{ac_index}")
    if crit.ticked and outcome == GREEN:
        # A non-green stays recordable on a ticked criterion: it is how a tick is withdrawn.
        refuse("already-ticked", f"{task_id} Human AC#{ac_index} is already ticked")

    dg = criterion_digest(crit)
    if not digest:
        refuse("no-digest", "the digest of the criterion the reviewer read is required "
                            "(fw reviewer verdict digest TASK --ac N)")
    if digest != dg:
        refuse("digest-mismatch",
               f"the reviewer judged text with digest {digest} but AC#{ac_index} now has "
               f"digest {dg} — the criterion changed after it was read")

    cl = ctx.classify(crit)
    if cl.delegation_class != REVIEWER_JUDGES:
        refuse("not-reviewer-judged",
               f"AC#{ac_index} is {cl.cls} ({cl.delegation_class}): only the operator may "
               f"answer it, so no reviewer verdict can satisfy or escalate it — {cl.reason}")

    # The worker session that runs this record is the one the completion is signed for.
    worker = worker_identity(dispatch_id)
    if _norm(worker) not in _norm(reviewer):
        refuse("reviewer-worker-mismatch",
               f"reviewer {reviewer.strip()!r} is not attributed to worker {worker!r} — the "
               f"reviewer identity must contain the worker session of dispatch {dispatch_id!r}")
    revision = _head_sha(root)
    if not revision:
        refuse("no-revision", "the repository has no commit to bind the review to")
    if _criterion_at(root, revision, task_id, ac_index) != dg:
        refuse("revision-mismatch",
               f"at HEAD {revision[:9]} AC#{ac_index} is not the text digest {dg} — commit the "
               f"task before reviewing, so the review is bound to a revision")

    try:
        jv = judge_verdict.verdict(_STATE[outcome], guidance,
                                   judged=f"{task_id}#AC{ac_index}", judge=reviewer.strip(),
                                   evidence=evidence)
    except judge_verdict.VerdictError as e:
        refuse("no-guidance", str(e))

    rec = {
        "id": f"V-{datetime.now(timezone.utc):%Y%m%d}-{uuid.uuid4().hex[:8]}",
        "ts": jv["ts"],
        "task": task_id,
        "ac": ac_index,
        "ac_digest": dg,
        "ac_text": crit.title.strip()[:160],
        "delegation_class": cl.delegation_class,
        "criterion_class": cl.cls,
        "outcome": outcome,
        "verdict": jv["state"],
        "guidance": jv["guidance"],
        "reviewer": reviewer.strip(),
        "dispatch_id": dispatch_id.strip(),
        "rung": rung.strip(),
        "evidence": evidence,
        "evidence_sha256": {e: _hash_path((root / e).resolve()) for e in evidence
                            if not _evidence_fault(root, e)},
        "judgement": jv,
        "worker": worker,
        "revision": revision,
    }
    if run_id.strip():
        rec["run_id"] = run_id.strip()
    comp = make_completion(root, rec)
    f = _fault(ctx, rec, crit, None, need_commit=False, completion=comp)  # not committed yet
    if f:
        refuse(*f)
    if ctx.ledger.faults:
        refuse("ledger-integrity", f"{ctx.ledger.faults[0]} — no row is appended to a ledger "
                                   f"whose history does not verify")
    _append(COMPLETIONS, comp, root)
    _append(VERDICTS, rec, root)
    _append(RECORDED, {"ts": _now(), "verdict_id": rec["id"], "task": task_id, "ac": ac_index,
                       "outcome": outcome}, root)
    if outcome != GREEN:
        _refuse_row(root, task_id, f"verdict-{outcome}", jv["guidance"],
                    ac=ac_index, reviewer=rec["reviewer"], verdict_id=rec["id"])
    if outcome == ESCALATE:
        _route_to_operator(root, path, text, crit, rec)
    return rec


def _route_to_operator(root: Path, path: Path, text: str, crit, rec: dict) -> None:
    """Escalate: put the reviewer's reason ON the criterion and make the operator the owner.

    /review renders the criterion body, so a line under it is what the operator reads
    there. The line is generated (see `_GENERATED_RE`), so it does not disturb the digest.
    """
    lines = text.split("\n")
    note = (f"  **Reviewer escalation ({rec['id']}, {rec['reviewer']}, rung {rec['rung']}):** "
            f"{rec['guidance']}")
    lines.insert(crit.end, note)
    out = "\n".join(lines)
    owner = str(frontmatter(text).get("owner") or "")
    if owner != "human":
        out = re.sub(r"(?m)^owner:.*$", "owner: human", out, count=1)
    path.write_text(out, encoding="utf-8")
    _append(APPLIED, {"ts": _now(), "task": rec["task"], "kind": "escalate",
                      "ac": rec["ac"], "verdict_id": rec["id"], "owner_before": owner,
                      "owner_after": "human"}, root)


# ── read side (the closer only ever calls these) ─────────────────────────────


#: Vocabulary of a criterion that asks about what RENDERS. On a render-surface task the
#: classifier calls every non-risk criterion render-surface (lib/delegation.py — task-level,
#: T-1766); the P-013 question is narrower: did a reviewer look at the rendered output?
_RENDER_REVIEW_RE = re.compile(
    r"\b(render(?:s|ed|ing)?|page|layout|watchtower|screen(?:shot)?|visual(?:ly)?|ui|css|"
    r"template|browser|display(?:s|ed)?|typography|spacing|looks?)\b", re.IGNORECASE)


def render_review_criteria(ctx: _Ctx) -> list:
    """The Human criteria that ARE the render review: render-surface class AND about rendering."""
    return [c for c in human_criteria(ctx.text)
            if ctx.classify(c).cls == "render-surface"
            and _RENDER_REVIEW_RE.search(criterion_body(c))]


def render_verdicts(task_id: str, root: Path | None = None) -> list[dict]:
    """Valid green verdicts, one per render-review criterion — ALL of them, or nothing.

    The P-013 gate asks whether a human looked at what renders. A green on an unrelated
    criterion does not answer that, and neither does a green on one render criterion while
    another is amber: every criterion that is about rendering needs its own valid approval,
    and a task with no such criterion cannot be satisfied by a verdict (T-3581 round 3).
    Same validator as `apply`."""
    root = root or _root()
    ctx = _task_ctx(root, task_id)
    if ctx is None:
        return []
    crits = render_review_criteria(ctx)
    out = []
    for c in crits:
        r, _ = satisfying_verdict(ctx, c)
        if not r:
            return []
        out.append(r)
    return out


_ANNOT_RE = re.compile(r"^\s*\*\*Reviewer verdict:\*\* green (V-[\w-]+)", re.IGNORECASE)


def applied_ticks(root: Path, task_id: str) -> dict[int, str]:
    """{ac: verdict id} for every criterion the applied log says a reviewer verdict ticked and
    that nothing has since withdrawn or an operator released. Durable provenance: it does not
    depend on the Markdown annotation, which anyone can edit (T-3581 round 4)."""
    state: dict[int, str] = {}
    for r in _read(APPLIED, root):
        if r.get("task") != task_id:
            continue
        for w in r.get("withdrawn") or []:
            if isinstance(w, dict):
                state.pop(w.get("ac"), None)
        if r.get("kind") == "operator-release":
            state.pop(r.get("ac"), None)
        for t in (r.get("ticked") or []) + (r.get("recited") or []):
            if isinstance(t, dict) and isinstance(t.get("ac"), int):
                state[t["ac"]] = str(t.get("verdict_id"))
    return state


def provenance_mismatches(root: Path, task_id: str, text: str) -> list[dict]:
    """Ticked criteria the applied log says a reviewer ticked, whose annotation is missing or
    names a different verdict. Cross-checks the two records (close and audit)."""
    prov = applied_ticks(root, task_id)
    if not prov:
        return []
    lines = text.split("\n")
    out = []
    for c in human_criteria(text):
        vid = prov.get(c.index)
        if vid is None or not c.ticked:
            continue
        ann = _annotation(lines, c)
        if ann is None:
            out.append({"ac": c.index, "verdict_id": vid, "why": "the reviewer-verdict annotation is missing"})
        elif ann[1] != vid:
            out.append({"ac": c.index, "verdict_id": vid,
                        "why": f"the annotation names {ann[1]}, the applied log says {vid}"})
    return out


def release(task_id: str, ac: int, reason: str, root: Path | None = None) -> dict:
    """Operator action: convert a reviewer-derived tick into a manual approval. Removes the
    annotation and records the release in the applied log. The CLI refuses agents."""
    root = root or _root()
    ctx = _task_ctx(root, task_id)
    if ctx is None:
        raise VerdictRefused(f"{task_id} is not an active task")
    if not (reason or "").strip():
        raise VerdictRefused("a reason is required")
    lines = ctx.text.split("\n")
    crit = next((c for c in human_criteria(ctx.text) if c.index == ac), None)
    if crit is None:
        raise VerdictRefused(f"{task_id} has no Human criterion #{ac}")
    ann = _annotation(lines, crit)
    vid = applied_ticks(root, task_id).get(ac) or (ann[1] if ann else "")
    if not vid:
        raise VerdictRefused(f"AC#{ac} of {task_id} is not reviewer-derived — nothing to release")
    if ann:
        del lines[ann[0]]
        ctx.path.write_text("\n".join(lines), encoding="utf-8")
    _append(APPLIED, {"ts": _now(), "task": task_id, "kind": "operator-release", "ac": ac,
                      "verdict_id": vid, "reason": reason.strip()}, root)
    return {"task": task_id, "ac": ac, "verdict_id": vid, "released": True}


def _annotation(lines: list[str], crit) -> tuple[int, str] | None:
    """(line index, verdict id) of the reviewer-verdict annotation under `crit`, if any."""
    for i in range(crit.start + 1, min(crit.end + 1, len(lines))):
        m = _ANNOT_RE.match(lines[i])
        if m:
            return i, m.group(1)
    return None


def _cite(r: dict) -> str:
    return (f"  **Reviewer verdict:** green {r['id']} — {r['reviewer']} (rung {r['rung']}), "
            f"digest {r['ac_digest']}; dispatch {r['dispatch_id']}; "
            f"evidence: {', '.join(r['evidence'])}; ledger {VERDICTS}")


def apply(task_id: str, root: Path | None = None) -> dict:
    """Revalidate every reviewer-derived tick, then tick what a valid green satisfies.

    Runs at EVERY close attempt, before the completion gates. A tick this module wrote is
    withdrawn — box unticked, annotation removed, ownership restored to the operator — when
    its verdict no longer validates: a later red, an edited criterion, a producer collision,
    missing evidence, a torn ledger. Ticks are never permanent (T-3581). Hand-ticked
    criteria carry no annotation and are not touched.

    Reads the ledger, writes only the task file and the applied ledger. Idempotent.
    """
    root = root or _root()
    result = {"task": task_id, "ticked": [], "withdrawn": [], "refused": [], "recited": [], "owner_before": "",
              "owner_after": "", "skipped": ""}
    ctx = _task_ctx(root, task_id)
    if ctx is None:
        result["skipped"] = "task not active"
        return result
    path, text = ctx.path, ctx.text
    owner = ctx.owner
    result["owner_before"] = result["owner_after"] = owner
    mism = provenance_mismatches(root, task_id, text)
    if mism:
        result["refused"] = mism
        return result
    if ctx.workflow == "inception":
        # The go/no-go gates (T-1259 / decision line) are rewired by their own slice;
        # a verdict must not tick around them.
        result["skipped"] = "inception: decision gates are outside this slice (T-3580)"
        return result

    lines = text.split("\n")
    # 1. withdraw stale reviewer-derived ticks (bottom-up: indices stay valid)
    for c in sorted(human_criteria(text), key=lambda c: -c.start):
        ann = _annotation(lines, c)
        if ann is None or not c.ticked:
            continue
        r, why = satisfying_verdict(ctx, c)
        if r is not None:
            if r["id"] != ann[1]:
                lines[ann[0]] = _cite(r)
                result["recited"].append({"ac": c.index, "verdict_id": r["id"]})
            continue
        del lines[ann[0]]
        lines[c.start] = re.sub(r"\[[xX]\]", "[ ]", lines[c.start], count=1)
        result["withdrawn"].append({"ac": c.index, "verdict_id": ann[1], "why": why})
    new_text = "\n".join(lines)

    # 2. tick what a valid green now satisfies
    lines = new_text.split("\n")
    hits = []
    for c in human_criteria(new_text):
        if c.ticked or ctx.classify(c).delegation_class != REVIEWER_JUDGES:
            continue
        r, _ = satisfying_verdict(ctx, c)
        if r:
            hits.append((c, r))
    for c, r in sorted(hits, key=lambda h: -h[0].start):
        lines[c.start] = re.sub(r"\[ \]", "[x]", lines[c.start], count=1)
        lines.insert(c.end, _cite(r))
        result["ticked"].append({"ac": c.index, "verdict_id": r["id"], "reviewer": r["reviewer"]})
    result["ticked"].sort(key=lambda t: t["ac"])
    result["withdrawn"].sort(key=lambda t: t["ac"])
    if not hits and not result["withdrawn"] and not result["recited"]:
        return result
    new_text = "\n".join(lines)

    still_open = [c for c in human_criteria(new_text) if not c.ticked]
    if result["withdrawn"] and owner != "human":
        new_text = re.sub(r"(?m)^owner:.*$", "owner: human", new_text, count=1)
        result["owner_after"] = "human"
    elif owner == "human" and not still_open:
        new_text = re.sub(r"(?m)^owner:.*$", "owner: agent", new_text, count=1)
        result["owner_after"] = "agent"
    path.write_text(new_text, encoding="utf-8")
    kind = "verdict-apply" if hits else ("verdict-withdraw" if result["withdrawn"] else "verdict-recite")
    _append(APPLIED, {"ts": _now(), "task": task_id, "kind": kind,
                      "ticked": result["ticked"], "withdrawn": result["withdrawn"],
                      "recited": result["recited"], "owner_before": owner, "owner_after": result["owner_after"],
                      "open_human_remaining": len(still_open)}, root)
    return result


# ── audit (fw audit) ─────────────────────────────────────────────────────────


def audit(root: Path | None = None) -> tuple[int, list[str]]:
    """Cross-check the ledger's history AND every row. (exit code, lines): 0 clean, 2 on failure.

    History: the file must be append-only against the accepted history (no modified, deleted,
    duplicated or replaced row). Rows: EVERY row — green or not — goes through the same
    `_row_fault` validator `apply` uses: structure, signed review dispatch for its task and,
    for greens, evidence, non-empty producer set excluding the reviewer, and an introducing
    commit that is not a producer's. Historical integrity only: a verdict superseded by a later
    criterion edit stays auditable and does not fail here. Uncommitted rows and torn lines fail."""
    root = root or _root()
    led = load_ledger(root)
    n = len(led.committed) + len(led.pending)
    if not n and not led.torn and not led.faults and not led.missing \
            and not _read(APPLIED, root):
        return 0, ["verdict ledger: empty or absent (path is off until a review dispatch writes rows)"]
    out, bad = [], 0
    for f in led.faults:
        bad += 1
        out.append(f"FAIL ledger integrity: {f}")
    for ln in led.torn:
        bad += 1
        out.append(f"FAIL torn/non-object line in verdicts.jsonl: {ln[:80]!r}")
    for vid, task in led.missing:
        bad += 1
        out.append(f"FAIL {vid} ({task}): deleted verdict — recorded but absent from the ledger")
    for task in sorted({str(r.get("task")) for r in _read(APPLIED, root) if r.get("task")}):
        tp, sub = _find_task(root, task)
        if tp is None or sub != "active":
            continue
        for m in provenance_mismatches(root, task, tp.read_text(encoding="utf-8", errors="replace")):
            bad += 1
            out.append(f"FAIL {m['verdict_id']} ({task}): annotation mismatch on AC#{m['ac']} — {m['why']}")
    bases: dict[str, _Base] = {}
    for r, intro in led.entries():
        rid, task = str(r.get("id", "?")), str(r.get("task", "?"))
        why = _structural_fault(r)
        if why:
            bad += 1
            out.append(f"FAIL {rid} ({task}): schema — {why}")
            continue
        if task not in bases:
            tp, _sub = _find_task(root, task)
            bases[task] = _Base(root, task, tp.read_text(encoding="utf-8", errors="replace") if tp else "")
        f = _row_fault(bases[task], r, intro)
        if f:
            bad += 1
            out.append(f"FAIL {rid} ({task}): {f[0].replace('-', ' ')} — {f[1]}")
    out.append(f"verdict ledger: {n} row(s), {bad} failure(s)")
    return (2 if bad else 0), out


# ── CLI ──────────────────────────────────────────────────────────────────────


def _cli(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw reviewer verdict")
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("record", help="record an independent reviewer's verdict on a Human criterion")
    r.add_argument("task_id")
    r.add_argument("--ac", type=int, required=True, help="Human criterion number")
    r.add_argument("--outcome", required=True, choices=OUTCOMES)
    r.add_argument("--reviewer", required=True, help="identity: session/model/vendor")
    r.add_argument("--rung", required=True, help="independence rung, e.g. cross-vendor")
    r.add_argument("--guidance", default="", help="mandatory unless green")
    r.add_argument("--evidence", action="append", default=[], help="repo path; repeatable")
    r.add_argument("--digest", default="", required=True,
                   help="digest of the criterion the reviewer read (`verdict digest`)")
    r.add_argument("--dispatch-id", default="", help="id of the review dispatch that produced this "
                   "verdict — must be in the dispatch registry with task-type review")
    r.add_argument("--run-id", default="", help="id of the review run this verdict belongs to "
                   "(named in the brief); the dispatcher binds the dispatch to it")

    g = sub.add_parser("register-dispatch", help="(dispatcher) register a dispatch for later provenance checks")
    g.add_argument("--dispatch-id", required=True)
    g.add_argument("--task", required=True)
    g.add_argument("--task-type", default="")
    g.add_argument("--issuer-session", default="")
    g.add_argument("--issuer-identity", default="")

    a = sub.add_parser("apply", help="tick green-judged criteria; hand ownership over if none left")
    a.add_argument("task_id")

    c = sub.add_parser("check-render", help="exit 0 when a green verdict satisfies the render gate")
    c.add_argument("task_id")

    d = sub.add_parser("digest", help="print the digest of a Human criterion's current text "
                       "(the reviewer submits it with `record --digest`)")
    d.add_argument("task_id")
    d.add_argument("--ac", type=int, required=True)

    rl = sub.add_parser("release", help="(operator) convert a reviewer-derived tick into a manual approval")
    rl.add_argument("task_id")
    rl.add_argument("--ac", type=int, required=True)
    rl.add_argument("--reason", required=True)
    rl.add_argument("--i-am-human", action="store_true")

    sub.add_parser("audit", help="cross-check every ledger row; exit 2 on any failure")

    ls = sub.add_parser("list", help="verdicts recorded for a task")
    ls.add_argument("task_id")

    args = ap.parse_args(argv)
    if args.cmd == "record":
        try:
            rec = record(args.task_id, args.ac, args.outcome, reviewer=args.reviewer,
                         rung=args.rung, guidance=args.guidance, evidence=args.evidence,
                         digest=args.digest, dispatch_id=args.dispatch_id,
                         run_id=args.run_id)
        except VerdictRefused as e:
            print(f"REFUSED: {e}", file=sys.stderr)
            return 1
        print(json.dumps({k: rec[k] for k in ("id", "task", "ac", "ac_digest", "outcome")}))
        return 0
    if args.cmd == "register-dispatch":
        row = register_dispatch(args.dispatch_id, args.task, args.task_type,
                                issuer_session=args.issuer_session,
                                issuer_identity=args.issuer_identity)
        print(json.dumps({k: row[k] for k in ("dispatch_id", "task", "task_type")}))
        return 0
    if args.cmd == "apply":
        res = apply(args.task_id)
        print(json.dumps(res))
        if res.get("refused"):
            print("REFUSED: reviewer-derived tick(s) no longer match the applied log — restore the "
                  "annotation, or an operator runs `fw reviewer verdict release`", file=sys.stderr)
            return 1
        return 0
    if args.cmd == "release":
        if os.environ.get("CLAUDECODE") == "1" and not args.i_am_human:
            print("REFUSED: converting a reviewer verdict into a manual approval is an operator "
                  "action (--i-am-human)", file=sys.stderr)
            return 1
        try:
            print(json.dumps(release(args.task_id, args.ac, args.reason)))
        except VerdictRefused as e:
            print(f"REFUSED: {e}", file=sys.stderr)
            return 1
        return 0
    if args.cmd == "check-render":
        vs = render_verdicts(args.task_id)
        if not vs:
            return 1
        v = vs[0]
        print(f"green verdict {v['id']} by {v['reviewer']} (rung {v['rung']}) on "
              f"AC#{v['ac']} of {args.task_id}")
        return 0
    if args.cmd == "digest":
        ctx = _task_ctx(_root(), args.task_id)
        crit = next((c for c in human_criteria(ctx.text) if c.index == args.ac), None) if ctx else None
        if crit is None:
            print(f"no active Human criterion #{args.ac} on {args.task_id}", file=sys.stderr)
            return 1
        print(criterion_digest(crit))
        return 0
    if args.cmd == "audit":
        code, lines = audit()
        print("\n".join(lines))
        return code
    if args.cmd == "list":
        for row in _read(VERDICTS, _root()):
            if row.get("task") == args.task_id:
                print(json.dumps(row, sort_keys=True))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(_cli())
