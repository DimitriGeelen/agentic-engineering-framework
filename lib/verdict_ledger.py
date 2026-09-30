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

  * (T-3580 rounds 2-3) the dispatch RUNTIME's signed completion lists it (review-completions.jsonl,
    written by run.sh via `complete` after the worker has exited — `record` never writes one): the
    worker session (the dispatch id; identity `reviewer-<dispatch id>`, fresh, not the issuer or a
    producer, and the identity `reviewer` is attributed to), its exit state, a hash of its result
    stream, the reviewed revision captured at DISPATCH time (the criterion has the digest the worker
    read there, and any cited file the hash it recorded), and per row the digest, evidence hashes
    and a hash over the exact verdict; the commit that introduced the row was made, author AND
    committer, by exactly that worker. A green also needs a worker that exited 0, and no work for
    the task committed after the reviewed revision;
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
import secrets
import time
import uuid
from typing import NoReturn
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib import judge_verdict  # noqa: E402
from lib import review_cost  # noqa: E402
from lib import review_policy  # noqa: E402
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
#: Signed worker completions, written by the dispatch RUNTIME when the worker exits (T-3581
#: attribution requirements 1-6, T-3580 round 3). A verdict row counts only if the one completion
#: of its dispatch lists it with the same contents. `record` never writes here.
COMPLETIONS = Path(".context/reviews/review-completions.jsonl")
DISPATCH_KEY = Path(".context/secrets/review-dispatch.key")
#: Per-dispatch completion secret (T-3580 round 4). `register_dispatch` writes it (mode 0600) into
#: the worker directory and registers only its sha256; run.sh reads it and deletes the file BEFORE
#: the worker starts, never exports it, and hands it to `start` and `complete` on stdin. Holding it
#: is not enough (round 5): `complete` also needs the signed runtime start and must beat the TTL.
#: T-3580 round 5 — the secret must not outlive its purpose. A review dispatch is registered with
#: two signed deadlines: `start_by` (registration + START_WINDOW), by which run.sh must have
#: recorded a signed START (`start`), and `complete_by` (registration + the dispatch TTL), after
#: which no completion is accepted. A dispatch that never ran has no start, so a caller who later
#: reads a leftover secret file cannot complete it; and once the window closes nobody can start it.
START_WINDOW = 300
DEFAULT_TTL = 4500
#: The kind→vendor mapping lives in policy/review-backends.yaml (`worker_kind` + `vendor`).
BACKENDS = Path("policy/review-backends.yaml")
_clock = time.time      # tests move time by patching this
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
    for k in ("revision", "wdir",           # T-3580 round 3: bound at dispatch time
              "worker_kind", "vendor", "completion_secret_sha256",    # round 4
              "start_by", "complete_by",                              # round 5
              "run_id", "seat",                                       # round 6: bound pre-launch
              "worker_bin", "prompt_sha256", "brief_sha256"):         # round 7: what is launched
        if k in row:
            body[k] = row[k]
    return hmac.new(key, json.dumps(body, sort_keys=True, separators=(",", ":")).encode(),
                    hashlib.sha256).hexdigest()


#: Round 7 (Claude F2): the ONLY caller `--env` keys a review dispatch accepts — deny by default.
#: Nothing that chooses the program or the model is on it: PATH, *_BASE_URL, ANTHROPIC_*, OPENAI_*,
#: CLAUDE_*, LD_*, BASH_ENV, model and binary overrides are all refused because they are absent.
#: Mirrored by REVIEW_ENV_ALLOW in agents/termlink/termlink.sh (a test pins the two equal).
REVIEW_ENV_ALLOW = ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL")
#: Keys the dispatcher itself writes into a review worker's env.sh.
_RUNTIME_ENV_KEYS = ("FW_SIDECAR_AGENT_ID", "FW_REVIEW_REVISION", "FW_SESSION_SCOPED_FOCUS",
                     "FW_FOCUS_SESSION_KEY")


def brief_digest(text: str) -> str:
    """sha256 of a review brief, normalised the way the dispatcher stores it (`$(cat file)` drops
    trailing newlines; brief.md gets exactly one back)."""
    return hashlib.sha256(((text or "").rstrip("\n") + "\n").encode()).hexdigest()


def _file_sha(path: Path) -> str:
    try:
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()
    except OSError:
        return ""


def _env_fault(wdir: Path) -> str:
    """'' when the worker's env.sh sets only allowed keys (REVIEW_ENV_ALLOW + the runtime's own)."""
    import shlex

    p = Path(wdir) / "env.sh"
    try:
        text = p.read_text()
    except OSError:
        return ""
    allowed = set(REVIEW_ENV_ALLOW) | set(_RUNTIME_ENV_KEYS)
    for n, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        try:
            toks = shlex.split(line)
        except ValueError:
            return f"env.sh line {n} does not parse"
        if not toks or toks[0] != "export" or len(toks) < 2:
            return f"env.sh line {n} is not an export"
        for t in toks[1:]:
            key = t.split("=", 1)[0]
            if "=" not in t or key not in allowed:
                return (f"env.sh sets {key!r}, which a review worker may not take from its caller "
                        f"(allowed: {', '.join(REVIEW_ENV_ALLOW)}) — it could choose the program or model")
    return ""


def _bin_fault(path: str) -> str:
    wb = (path or "").strip()
    if not wb.startswith("/"):
        return f"the worker binary {wb or '(none)'!r} is not an absolute path resolved at dispatch"
    if not (os.path.isfile(wb) and os.access(wb, os.X_OK)):
        return f"the worker binary {wb!r} is not an executable file"
    return ""


def _launch_fault(drec: dict, wdir: Path) -> str:
    """(start, round 7) '' when what run.sh is about to launch is what was registered: the same
    prompt.md, the same absolute worker binary, and an env.sh with no program- or model-choosing
    key."""
    if _file_sha(Path(wdir) / "prompt.md") != str(drec.get("prompt_sha256") or "-"):
        return "prompt.md is not the brief registered with the dispatch"
    try:
        wb = (Path(wdir) / "worker_bin").read_text().strip()
    except OSError:
        wb = ""
    if wb != str(drec.get("worker_bin") or "") or _bin_fault(wb):
        return (f"the worker binary {wb or '(none)'!r} is not the registered "
                f"{drec.get('worker_bin') or '(none)'!r} — {_bin_fault(wb) or 'changed after dispatch'}")
    return _env_fault(Path(wdir))


def register_dispatch(dispatch_id: str, task_id: str, task_type: str, *,
                      issuer_session: str = "", issuer_identity: str = "",
                      revision: str = "", wdir: str = "", worker_kind: str = "",
                      vendor: str = "", ttl: int = DEFAULT_TTL, run_id: str = "",
                      seat: str = "", worker_bin: str = "", root: Path | None = None) -> dict:
    """Record a dispatch. Called by the dispatcher, for every task-type, at spawn time.

    `revision` is the commit the reviewer is asked to review, captured BEFORE the worker starts
    (default: HEAD now, which is before the worker exists). `wdir` is the runtime's worker
    directory, where it writes the worker's exit state: only a completion from that directory
    counts (T-3580 round 3).

    `worker_kind` is the kind the dispatcher actually launches. The vendor is DERIVED from it
    through the one mapping in policy/review-backends.yaml (T-3580 round 5), never taken from the
    caller: `vendor`, if given, is only an assertion, and a mismatch is refused. A review dispatch
    whose kind the mapping does not know is refused. A review dispatch with a worker directory
    gets two signed deadlines: `start_by` and `complete_by` (registration + `ttl`). It gets NO
    secret (round 6): registration is caller-accessible, so the completion capability is issued
    by the runtime's authenticated `start`, never here.

    `run_id` + `seat` (round 6) bind the dispatch to the signed review run the judge registered
    BEFORE the worker is launched: the run must exist, be for this task and have that seat, and a
    seat is dispatched once. The binding is part of the signed registration; there is no later
    bind step a caller could skip or redo.

    Round 7 (Claude F2): a review dispatch with a worker directory also signs WHAT is launched —
    `worker_bin` (the absolute worker binary the dispatcher resolved), `prompt_sha256` (the
    prompt.md it wrote) and, for a run seat, `brief_sha256`, which must be the brief the run
    registered for that seat (and prompt.md must end with it). Its env.sh may set only
    REVIEW_ENV_ALLOW keys. `start` re-checks all of it before the worker runs."""
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
           "issuer_session": issuer_session, "issuer_identity": issuer_identity, "ts": _now(),
           "revision": (revision or "").strip() or _head_sha(root),
           "wdir": str(Path(wdir).resolve()) if (wdir or "").strip() else "",
           "worker_kind": (worker_kind or "").strip(), "vendor": ""}
    # Round 6: the mapping as COMMITTED at the reviewed revision, restricted to the kinds the
    # dispatcher can launch — an uncommitted or unlaunchable declaration names no vendor.
    table = verified_kind_vendors(root, row["revision"])
    if row["task_type"] == REVIEW_TASK_TYPE:
        row["worker_kind"] = row["worker_kind"] or "claude"
        if not table.get(row["worker_kind"]):
            raise ValueError(f"worker kind {row['worker_kind']!r} has no vendor in {BACKENDS} as "
                             f"committed at {row['revision'][:9] or 'HEAD'}, or the dispatcher cannot "
                             f"launch it — a review dispatch's vendor comes from that mapping, never "
                             f"free text")
    row["vendor"] = table.get(row["worker_kind"], "")
    if (run_id or "").strip() or (seat or "").strip():
        if row["task_type"] != REVIEW_TASK_TYPE:
            raise ValueError("only a review dispatch is bound to a review run")
        run, why = _verified_run(root, (run_id or "").strip())
        if run is None:
            raise ValueError(why)
        if run.get("task") != row["task"]:
            raise ValueError(f"run {run_id.strip()!r} is for {run.get('task')!r}, not {row['task']}")
        if (seat or "").strip() not in {s["seat"] for s in run.get("seats") or []}:
            raise ValueError(f"seat {(seat or '').strip()!r} is not a seat of run {run_id.strip()!r}")
        if row["revision"] != str(run.get("revision") or ""):
            raise ValueError(f"run {run_id.strip()!r} is pinned to revision "
                             f"{str(run.get('revision') or 'none')[:9]}; a seat dispatched at "
                             f"{row['revision'][:9]} would be judged against another registry — "
                             f"every seat of a run uses the run's one binding")
        if any(r.get("run_id") == run_id.strip() and r.get("seat") == seat.strip()
               for r in _read(DISPATCHES, root)):
            raise ValueError(f"seat {seat.strip()!r} of run {run_id.strip()!r} is already dispatched")
        row["run_id"], row["seat"] = run_id.strip(), seat.strip()
    if row["task_type"] == REVIEW_TASK_TYPE and row["wdir"]:
        w = Path(row["wdir"])
        if not (w / "prompt.md").is_file():
            raise ValueError(f"no prompt.md in {w} — a review dispatch's brief is registered with it")
        bad = _bin_fault(worker_bin) or _env_fault(w)
        if bad:
            raise ValueError(f"review dispatch refused: {bad}")
        row["worker_bin"] = worker_bin.strip()
        row["prompt_sha256"] = _file_sha(w / "prompt.md")
        if row.get("run_id"):
            want = next((str(x.get("brief_sha256") or "") for x in run.get("seats") or []
                         if x.get("seat") == row["seat"]), "")
            try:
                brief = (w / "brief.md").read_text()
                prompt = (w / "prompt.md").read_text()
            except OSError:
                raise ValueError(f"no brief.md in {w} — a run seat's brief must be the one its run registered")
            if not want or brief_digest(brief) != want:
                raise ValueError(f"the brief in {w} is not the one run {row['run_id']!r} registered for "
                                 f"seat {row['seat']!r} — a review worker runs the judge's brief, not "
                                 f"the caller's")
            if not prompt.rstrip("\n").endswith(brief.rstrip("\n")):
                raise ValueError(f"prompt.md in {w} does not carry the registered brief")
            row["brief_sha256"] = want
    if (vendor or "").strip() and vendor.strip() != row["vendor"]:
        raise ValueError(f"vendor {vendor.strip()!r} is not the one {BACKENDS} maps worker kind "
                         f"{row['worker_kind']!r} to ({row['vendor'] or 'none'!r}) — refused")
    if row["task_type"] == REVIEW_TASK_TYPE and row["wdir"]:
        now = int(_clock())
        row["start_by"] = now + START_WINDOW
        row["complete_by"] = now + max(int(ttl), START_WINDOW)
    row["sig"] = _sign(_dispatch_key(root, create=True), row)
    _append(DISPATCHES, row, root)
    return row


TERMLINK_SH = Path("agents/termlink/termlink.sh")


def _committed_blob(root: Path, revision: str, rel: Path) -> tuple[str, str]:
    """(text, where) of framework file `rel` as COMMITTED — never the working tree (T-3580 round
    6 for the registry, round 7 for termlink.sh). The project's own `rel` at `revision` (default
    HEAD) when it is tracked there; else the vendored copy under the project at `revision`; else
    this framework's committed copy at its HEAD, pinned to that commit's sha in `where`. ('', why)
    when none is committed."""
    rev = (revision or "").strip() or "HEAD"
    cands = [(root, rev, str(rel))]
    fw = _HERE.parent.resolve()
    try:
        cands.append((root, rev, str((fw / rel).relative_to(Path(root).resolve()))))
    except ValueError:
        rc, sha = _git_out(fw, "rev-parse", "-q", "--verify", "HEAD")
        cands.append((fw, sha.strip() if rc == 0 else "HEAD", str(rel)))
    for repo, r, rel_s in cands:
        rc, blob = _git_out(repo, "show", f"{r}:{rel_s}")
        if rc == 0 and blob.strip():
            rc2, sha = _git_out(repo, "rev-parse", "-q", "--verify", f"{r}^{{commit}}")
            return blob, f"{repo}@{sha.strip() if rc2 == 0 else r}:{rel_s}"
    return "", f"no committed {rel} at {rev}"


def _registry_blob(root: Path, revision: str) -> tuple[str, str]:
    """policy/review-backends.yaml as committed (see `_committed_blob`)."""
    return _committed_blob(root, revision, BACKENDS)


def registry_pin(root: Path, revision: str) -> dict:
    """(round 7) The registry blob a review run is pinned to: where it was read and its sha256."""
    blob, where = _registry_blob(root, revision)
    return {"where": where, "sha256": hashlib.sha256(blob.encode()).hexdigest() if blob else ""}


def kind_vendors(root: Path | None = None, revision: str = "") -> dict[str, str]:
    """{worker kind: vendor} from policy/review-backends.yaml AS COMMITTED at `revision` (default
    HEAD; see `_registry_blob`). An uncommitted edit of the registry declares nothing. {} when no
    committed registry exists or it is invalid: no vendor is then verifiable."""
    import tempfile

    root = root or _root()
    blob, _where = _registry_blob(root, revision)
    if not blob:
        return {}
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fh:
        fh.write(blob)
        tmp = Path(fh.name)
    try:
        return review_cost.worker_vendors(tmp)
    except (review_cost.CostError, OSError, ValueError):
        return {}
    finally:
        tmp.unlink(missing_ok=True)


_KINDS_RE = re.compile(r'^DISPATCH_WORKER_KINDS="([^"]*)"', re.M)


def launchable_kinds(root: Path | None = None, revision: str = "") -> set[str]:
    """The worker kinds the dispatch runtime can actually launch: DISPATCH_WORKER_KINDS in
    agents/termlink/termlink.sh AS COMMITTED at `revision` (round 7; `_committed_blob`) — an
    uncommitted edit of the list launches nothing the ledger counts. A registry entry naming a
    kind the dispatcher cannot run (antigravity, codex and opencode until T-3582) is a
    declaration, not a worker."""
    text, _where = _committed_blob(root or _root(), revision, TERMLINK_SH)
    m = _KINDS_RE.search(text)
    return set(m.group(1).split()) if m else set()


def verified_kind_vendors(root: Path | None = None, revision: str = "") -> dict[str, str]:
    """The kind->vendor pairs a review dispatch may be registered under and a panel may count:
    committed in the registry at `revision` AND launchable by the dispatcher as committed at the
    same revision (rounds 6, 7)."""
    live = launchable_kinds(root, revision)
    return {k: v for k, v in kind_vendors(root, revision).items() if k in live}


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


#: A completion is the dispatch RUNTIME's act, emitted when the worker has exited (T-3580 round 3).
#: The worker's own environment carries this variable naming its dispatch; `complete` refuses to
#: run inside it, and the runtime strips it before calling.
_WORKER_ENV = "FW_SIDECAR_AGENT_ID"


def _result_sha(wdir: Path) -> str:
    for name in ("result.jsonl", "result.md"):
        f = wdir / name
        if f.is_file():
            return hashlib.sha256(f.read_bytes()).hexdigest()
    return ""


def _worker_session(wdir: Path) -> str:
    """The worker's own session id from its stream-json result, '' when the stream carries none
    (the ollama-loop worker, or a stream cut short). Recorded, not required (round 4)."""
    f = wdir / "result.jsonl"
    try:
        for line in f.read_text(errors="replace").splitlines():
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if isinstance(ev, dict) and str(ev.get("session_id") or "").strip():
                return str(ev["session_id"]).strip()
    except OSError:
        pass
    return ""


def _secret_ok(start_rec: dict, secret: str) -> bool:
    """`secret` is the one the runtime's authenticated start issued (its hash is in the signed
    start record — round 6; registrations carry none)."""
    want = str(start_rec.get("secret_sha256") or "")
    got = hashlib.sha256((secret or "").strip().encode()).hexdigest()
    return bool(want) and bool((secret or "").strip()) and hmac.compare_digest(got, want)


def _starts_for(root: Path, dispatch_id: str) -> list[dict]:
    return [c for c in _read(COMPLETIONS, root)
            if c.get("dispatch_id") == dispatch_id and c.get("kind") == "start"]


def start(dispatch_id: str, *, wdir: str, pid: int = 0,
          root: Path | None = None) -> tuple[dict, str]:
    """(run.sh, its first act) record — signed — that the dispatch runtime started for this
    dispatch, and ISSUE the completion capability (T-3580 round 6). Returns (record, secret).

    The secret is born here, in the runtime, and returned only to the caller (run.sh keeps it in
    memory, never on disk); the start record carries its hash. Registration, which any caller can
    reach, issues nothing. The call is AUTHENTICATED in this shared implementation, not only in the
    CLI: `_runtime_fault` refuses unless this process's parent is `bash <registered wdir>/run.sh`
    and that file is byte-for-byte the runtime termlink.sh writes. It also needs the registered
    worker directory and to happen before the registration's `start_by`; a dispatch starts once."""
    root = root or _root()
    did = (dispatch_id or "").strip()
    drec, why = dispatch_record(root, did)
    if drec is None:
        raise VerdictRefused(why)
    if drec.get("task_type") != REVIEW_TASK_TYPE:
        raise VerdictRefused(f"dispatch {did!r} is not a review dispatch")
    if os.environ.get(_WORKER_ENV, "").strip() == did:
        raise VerdictRefused("a start is recorded by the dispatch runtime, never from inside the "
                             "worker's own environment")
    here = str(Path(wdir).resolve()) if (wdir or "").strip() else ""
    if not here or here != str(drec.get("wdir") or ""):
        raise VerdictRefused(f"worker directory {here or '(none)'} is not the one registered for "
                             f"dispatch {did!r}")
    bad = _runtime_fault(here, root, str(drec.get("revision") or "")) or _launch_fault(drec, Path(here))
    if bad:
        raise VerdictRefused(f"dispatch {did!r} cannot be started here: {bad}")
    now = int(_clock())
    if not drec.get("start_by") or now > int(drec["start_by"]):
        raise VerdictRefused(f"dispatch {did!r} was not started within its start window — a "
                             f"dispatch that did not run in time cannot be started later")
    if _starts_for(root, did):
        raise VerdictRefused(f"dispatch {did!r} has already started — a dispatch starts once")
    secret = secrets.token_hex(32)
    body = {"kind": "start", "source": "runtime", "dispatch_id": did, "task": drec["task"],
            "wdir": here, "pid": int(pid or os.getppid()), "epoch": now,
            "secret_sha256": hashlib.sha256(secret.encode()).hexdigest(), "ts": _now()}
    body["sig"] = _sign_row(_dispatch_key(root), body)
    _append(COMPLETIONS, body, root)
    return body, secret


_RUNTIME_OPEN = "cat > \"$wdir/run.sh\" <<'RUNEOF'\n"


def _canonical_runtime(root: Path | None = None, revision: str = "") -> str | None:
    """The dispatch runtime exactly as agents/termlink/termlink.sh writes it into `<wdir>/run.sh`,
    from termlink.sh AS COMMITTED at `revision` (round 7: never the working tree); None when no
    committed copy can be read."""
    src, _where = _committed_blob(root or _root(), revision, TERMLINK_SH)
    try:
        i = src.index(_RUNTIME_OPEN) + len(_RUNTIME_OPEN)
        return src[i:src.index("\nRUNEOF\n", i)] + "\n"
    except ValueError:
        return None


def _parent_argv() -> list[str]:
    ppid = os.getppid()
    try:
        raw = Path(f"/proc/{ppid}/cmdline").read_bytes()
        return [a.decode(errors="replace") for a in raw.split(b"\0") if a]
    except OSError:
        try:
            return subprocess.run(["ps", "-o", "args=", "-p", str(ppid)], capture_output=True,
                                  text=True, timeout=10).stdout.split()
        except (OSError, subprocess.SubprocessError):
            return []


def _runtime_fault(wdir: str, root: Path | None = None, revision: str = "") -> str:
    """'' when this process was launched by the dispatch runtime of `wdir`: its parent is a shell
    running `<wdir>/run.sh` as its script (argv[1], not a `-c` string that merely mentions it), and
    that file is the canonical runtime. Shared by `start` and `complete` (round 6), so a Python
    caller cannot skip it the way it could skip the round-5 CLI-only check. Same-user limit: a
    caller that writes the canonical runtime into the registered directory and runs it IS running
    the dispatch (it launches the worker); one that patches this function in its own process, or
    fakes its parent, is outside what a check in that process can see (T-3581 residual)."""
    argv = _parent_argv()
    want = Path(wdir) / "run.sh"
    if len(argv) < 2 or Path(argv[0]).name not in ("bash", "sh") or argv[1].startswith("-"):
        return (f"the parent process is not a shell running {want} (argv: "
                f"{' '.join(argv[:3]) or 'unreadable'})")
    try:
        same = Path(argv[1]).resolve() == want.resolve()
    except OSError:
        same = False
    if not same:
        return f"the parent process runs {argv[1]!r}, not the runtime {want}"
    canon = _canonical_runtime(root, revision)
    if canon is None:
        return (f"the canonical dispatch runtime (agents/termlink/termlink.sh as committed at "
                f"{(revision or 'HEAD')[:9]}) cannot be read")
    try:
        body = want.read_text()
    except OSError:
        return f"{want} cannot be read"
    if body != canon:
        return f"{want} is not the dispatch runtime termlink.sh writes"
    return ""


def complete(dispatch_id: str, *, wdir: str, exit_code: int, session: str = "",
             secret: str = "", worker_kind: str = "", root: Path | None = None) -> dict:
    """(the dispatch runtime, after the worker exits) sign what the worker left behind.

    Called by run.sh (agents/termlink/termlink.sh) once `exit_code` is written, never by the
    worker and never by `record`. It binds the worker session, its exit state, a hash of the
    worker's result stream, the reviewed revision registered at dispatch time, and — for every
    verdict row the worker wrote — the row's digest, evidence hashes and exact-contents hash.
    Rows appended after this point are not in it, so they never count. It always appends: a
    second completion for the same dispatch makes BOTH void (see `_completion_fault`), so a
    worker that forges one before exiting only invalidates its own verdicts.

    `secret` is the per-dispatch completion secret (round 4) that only run.sh holds; without it
    the call is refused, so the public command cannot be driven by a caller that merely wrote an
    exit_code file. `worker_kind` is the kind run.sh actually ran; it must be the registered one.

    Round 6: the secret is the one the runtime's authenticated `start` issued (not a registration
    file any caller could read), and this call is authenticated like `start` (`_runtime_fault`)."""
    root = root or _root()
    did = (dispatch_id or "").strip()
    drec, why = dispatch_record(root, did)
    if drec is None:
        raise VerdictRefused(why)
    if drec.get("task_type") != REVIEW_TASK_TYPE:
        raise VerdictRefused(f"dispatch {did!r} is not a review dispatch")
    if os.environ.get(_WORKER_ENV, "").strip() == did:
        raise VerdictRefused("a completion is emitted by the dispatch runtime after the worker "
                             "exits, never from inside the worker's own environment")
    if session and session.strip() != did:
        raise VerdictRefused(f"runtime session {session!r} is not dispatch {did!r}")
    starts = _starts_for(root, did)
    if len(starts) != 1 or not _signed_ok(root, starts[0]) or not starts[0].get("secret_sha256"):
        raise VerdictRefused(f"no runtime start record for dispatch {did!r}: run.sh never started "
                             f"for it, so there is nothing to complete")
    if not _secret_ok(starts[0], secret):
        raise VerdictRefused(f"no valid completion secret for dispatch {did!r}: a completion is "
                             f"signed only by the runtime that started the worker")
    now = int(_clock())
    if not drec.get("complete_by") or now > int(drec["complete_by"]):
        raise VerdictRefused(f"dispatch {did!r} is past its TTL — its secret has expired")
    kind = (worker_kind or "").strip() or "claude"
    if kind != (drec.get("worker_kind") or "claude"):
        raise VerdictRefused(f"the runtime ran worker kind {kind!r}, not the registered "
                             f"{drec.get('worker_kind') or 'claude'!r}")
    reg = str(drec.get("wdir") or "")
    here = str(Path(wdir).resolve()) if (wdir or "").strip() else ""
    if not reg or here != reg:
        raise VerdictRefused(f"worker directory {here or '(none)'} is not the one registered for "
                             f"dispatch {did!r} ({reg or 'none registered'})")
    bad = _runtime_fault(here, root, str(drec.get("revision") or ""))
    if bad:
        raise VerdictRefused(f"dispatch {did!r} cannot be completed here: {bad}")
    ec_file = Path(here) / "exit_code"
    try:
        written = int(ec_file.read_text().strip())
    except (OSError, ValueError):
        raise VerdictRefused(f"the worker has not exited: {ec_file} holds no exit state")
    if written != int(exit_code):
        raise VerdictRefused(f"exit code {exit_code} is not the one the runtime wrote ({written})")
    verdicts = [{"verdict_id": r.get("id"), "ac": r.get("ac"), "ac_digest": r.get("ac_digest"),
                 "outcome": r.get("outcome"), "evidence_sha256": r.get("evidence_sha256") or {},
                 "verdict_sha256": verdict_hash(r)}
                for r in _read(VERDICTS, root) if r.get("dispatch_id") == did]
    body = {"kind": "completion", "source": "runtime", "dispatch_id": did, "task": drec["task"],
            "session": did, "worker": worker_identity(did), "wdir": reg, "exit_code": written,
            "worker_kind": kind, "worker_session": _worker_session(Path(here)),
            "result_sha256": _result_sha(Path(here)), "revision": drec.get("revision", ""),
            "verdicts": verdicts, "epoch": now, "ts": _now()}
    body["sig"] = _sign_row(_dispatch_key(root), body)
    _append(COMPLETIONS, body, root)
    return body


def _completions_for(root: Path, dispatch_id: str) -> list[dict]:
    return [c for c in _read(COMPLETIONS, root)
            if c.get("dispatch_id") == dispatch_id and c.get("kind", "completion") == "completion"]


def history_fault(root: Path, rel: Path) -> str:
    """'' when `rel` is append-only against git history: every commit that touched it keeps the
    previous committed lines as an exact prefix, and the working file keeps the last committed
    lines as its prefix. Uncommitted lines beyond that are allowed (T-3580 round 5 — the same
    walk `load_ledger` makes for verdicts.jsonl, applied to the completions file)."""
    rc, _ = _git_out(root, "rev-parse", "-q", "--verify", "HEAD")
    if rc == 128:
        return "git cannot answer (not a repository) — history is unverifiable"
    history = ""
    if rc == 0:
        rc, history = _git_out(root, "log", "--reverse", "--format=%H", "HEAD", "--", str(rel))
        if rc != 0:
            return f"git log failed (rc={rc}) — history is unverifiable"
    prev: list[str] = []
    for sha in history.split():
        rc, blob = _git_out(root, "show", f"{sha}:{rel}")
        lines = _nonblank(blob) if rc == 0 else []
        if lines[:len(prev)] != prev:
            return (f"commit {sha[:9]} modified, deleted or replaced committed {rel.name} rows — "
                    f"it is append-only")
        prev = lines
    cur = _nonblank((root / rel).read_text(encoding="utf-8", errors="replace")) \
        if (root / rel).is_file() else []
    if cur[:len(prev)] != prev:
        return f"the working {rel.name} does not contain its committed rows unchanged"
    return ""


def _tracked(root: Path, rel: Path) -> bool:
    return _git_out(root, "ls-files", "--error-unmatch", str(rel))[0] == 0


def register_run(run_id: str, task_id: str, *, acs: list[int], rung: str, seats: list[dict],
                 required_vendors: int = 1, pages: dict | None = None, captures: list | None = None,
                 inputs: dict | None = None, reason: str = "", degraded: str = "",
                 rung_due: int | None = None, brief_sha256: str = "", revision: str = "",
                 root: Path | None = None) -> dict:
    """(judge, before dispatching) record a review run: the seats it requires, how many distinct
    vendors it demands, and for render criteria the pages that must have been seen with the
    capture result of each. Signed; a partial capture failure is kept, never discarded.

    `rung_due` (round 7) is the rung IW-7 requires. The ledger itself computes the ceiling
    decision HERE, as of this run's registration time, from the committed cost ledger
    (lib/review_policy.ceiling_decision), and refuses a run whose `rung` is not the rung that
    decision grants. A caller never supplies a decision, so no run can carry an old one.

    Every seat carries the `brief_sha256` of the brief the judge wrote for it (round 7); a dispatch
    for the seat is registered only with that brief (`register_dispatch`).

    The run also pins ONE reviewed `revision` (default HEAD now) and the registry blob committed at
    it (`registry`: where + sha256). Every seat's dispatch must be registered at that revision, and
    the panel's vendors are derived once, from that blob (round 7, codex MEDIUM-4 / Claude F3)."""
    root = root or _root()
    if any(r.get("kind") == "run" and r.get("run_id") == run_id for r in _read(RUNS, root)):
        raise ValueError(f"run {run_id!r} is already registered")
    for x in seats:
        if not re.fullmatch(r"[0-9a-f]{64}", str(x.get("brief_sha256") or brief_sha256 or "")):
            raise ValueError(f"seat {x.get('seat')!r} of run {run_id!r} has no brief_sha256 — a run "
                             f"binds the brief each seat is dispatched with")
    key = _dispatch_key(root, create=True)
    row = {"kind": "run", "run_id": run_id, "task": task_id, "acs": sorted(acs), "rung": rung,
           "seats": [{"seat": s["seat"], "vendor": s["vendor"],
                      "brief_sha256": str(s.get("brief_sha256") or brief_sha256 or "")} for s in seats],
           "required_vendors": int(required_vendors),
           "pages": {str(k): list(v) for k, v in (pages or {}).items()},
           "captures": [dict(c) for c in (captures or [])], "inputs": inputs or {},
           "reason": reason, "degraded": degraded, "ts": _now()}
    row["revision"] = (revision or "").strip() or _head_sha(root)
    row["registry"] = registry_pin(root, row["revision"])
    if rung_due is not None:
        now = datetime.strptime(row["ts"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        dec = review_policy.ceiling_decision(root, int(rung_due), reason, now)
        if review_policy.rung_number(rung) != dec["granted"]:
            raise ValueError(f"run {run_id!r} asks for {rung!r}; with rung {dec['due']} due the "
                             f"ceiling decision at registration grants rung {dec['granted']} "
                             f"({dec['why'] or 'no step-down'})")
        row["ceiling_decision"] = dec
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


def run_for_dispatch(root: Path, dispatch_id: str) -> tuple[dict | None, dict | None, str]:
    """(run, bind, why). The run and seat come from the dispatch's SIGNED REGISTRATION (round 6:
    bound before launch); `bind` is {'run_id', 'seat', 'dispatch_id'}. (None, None, '') when the
    dispatch was registered with no run; a non-empty `why` means it names a run that does not
    verify. Post-hoc `bind` rows (round 2-5) are not read: a binding made after launch proves
    nothing about what was authorised."""
    drec, why = dispatch_record(root, dispatch_id)
    if drec is None or not str(drec.get("run_id") or ""):
        return None, None, ""
    run, why = _verified_run(root, str(drec["run_id"]))
    if run is None:
        return None, None, why
    if str(drec.get("seat") or "") not in {s["seat"] for s in run.get("seats") or []}:
        return None, None, f"dispatch {dispatch_id!r} names seat {drec.get('seat')!r}, not a seat of its run"
    return run, {"run_id": run["run_id"], "seat": drec["seat"], "dispatch_id": dispatch_id}, ""


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


def _worker_fault(base: _Base, row: dict, intro: dict | None) -> tuple[str, str] | None:
    """What the row itself must say about its worker and the revision it reviewed (T-3581
    requirements 1, 2 and 6). Checked at `record` and again at every read."""
    root = base.root
    worker = str(row.get("worker") or "")
    if not worker:
        return "no-worker", "the row names no worker session"
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
    # 2. the reviewed revision is the one captured at dispatch time, before the review ran
    rev = str(row.get("revision") or "")
    reg = str((drec or {}).get("revision") or "")
    if not reg:
        return "revision", (f"dispatch {row['dispatch_id']!r} was registered without a reviewed "
                            f"revision — nothing binds the review to what it saw")
    if rev != reg:
        return "revision", (f"the row names revision {rev[:9] or '(none)'} but the dispatch was "
                            f"issued to review {reg[:9]}")
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


def _completion_fault(base: _Base, row: dict) -> tuple[str, str] | None:
    """The dispatch RUNTIME's signed completion must list this row with the same contents
    (T-3581 requirements 3, 4, 5 and the completion half of 6). `record` cannot produce it: it is
    written by run.sh after the worker has exited (`complete`)."""
    root = base.root
    did = str(row.get("dispatch_id"))
    comps = _completions_for(root, did)
    if not comps:
        return "no-completion", (f"row {row.get('id')} has no completion from the dispatch runtime "
                                 f"— a registration is not a completion")
    if len(comps) > 1:
        return "completion-duplicate", (f"dispatch {did!r} has {len(comps)} completions; the "
                                        f"runtime writes exactly one, so none is trusted")
    hist = history_fault(root, COMPLETIONS)
    if hist:
        return "completion-history", hist
    comp = comps[0]
    if not _signed_ok(root, comp):
        return "bad-completion", "the runtime completion has an invalid signature"
    drec, _ = dispatch_record(root, did)
    starts = _starts_for(root, did)
    if len(starts) != 1 or not _signed_ok(root, starts[0]) \
            or starts[0].get("wdir") != (drec or {}).get("wdir") \
            or not starts[0].get("secret_sha256"):
        return "no-start", (f"dispatch {did!r} has no single valid runtime start record — run.sh "
                            f"never started for it, so its completion does not count")
    st = starts[0]
    try:
        in_time = (int(st.get("epoch")) <= int((drec or {}).get("start_by"))
                   and int(st.get("epoch")) <= int(comp.get("epoch"))
                   <= int((drec or {}).get("complete_by")))
    except (TypeError, ValueError):
        in_time = False
    if not in_time:
        return "expired", (f"dispatch {did!r} started or completed outside its signed window "
                           f"(start_by / complete_by) — its secret had expired")
    if comp.get("source") != "runtime" or comp.get("session") != did \
            or not comp.get("wdir") or comp.get("wdir") != (drec or {}).get("wdir"):
        return "bad-completion", ("the completion was not emitted by the runtime of this dispatch "
                                  "(session or worker directory differs from the registration)")
    if comp.get("worker_kind") != ((drec or {}).get("worker_kind") or "claude"):
        return "bad-completion", ("the completion's worker kind is not the one registered for the "
                                  "dispatch")
    for k, want in (("task", row.get("task")), ("worker", row.get("worker")),
                    ("revision", row.get("revision"))):
        if comp.get(k) != want:
            return "completion-mismatch", (f"the runtime completion's {k} ({comp.get(k)!r}) is not "
                                           f"the row's ({want!r})")
    entry = next((v for v in comp.get("verdicts") or [] if v.get("verdict_id") == row.get("id")), None)
    if entry is None:
        return "not-in-completion", (f"row {row.get('id')} is not among the verdicts its worker had "
                                     f"written when it exited")
    for k in ("ac", "ac_digest"):
        if entry.get(k) != row.get(k):
            return "completion-mismatch", (f"the runtime completion's {k} ({entry.get(k)!r}) is not "
                                           f"the row's ({row.get(k)!r})")
    if (entry.get("evidence_sha256") or {}) != (row.get("evidence_sha256") or {}):
        return "completion-mismatch", "the runtime completion's evidence hashes are not the row's"
    if entry.get("verdict_sha256") != verdict_hash(row):
        return "verdict-tampered", ("the row's bytes differ from the verdict the worker left when it "
                                    "exited (verdict hash mismatch)")
    if row.get("outcome") == GREEN and comp.get("exit_code") != 0:
        return "worker-failed", (f"the worker exited {comp.get('exit_code')} — a green from a "
                                 f"failed or killed review does not count")
    if not comp.get("result_sha256"):
        return "bad-completion", "the runtime recorded no result stream for the worker"
    return None


def _row_fault(base: _Base, row: dict, intro: dict | None, *, need_commit: bool = True,
               recording: bool = False) -> tuple[str, str] | None:
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
    f = _worker_fault(base, row, intro) or (None if recording else _completion_fault(base, row))
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
           recording: bool = False) -> tuple[str, str] | None:
    """(class, reason) when `row` may NOT satisfy `crit` right now: historical integrity
    (`_row_fault`) PLUS current eligibility — the row names this criterion, the criterion text
    is unchanged, and the criterion is still reviewer-judged."""
    if not _structural_fault(row):
        if row["ac"] != crit.index:
            return "schema", "row does not name this criterion"
        if row["ac_digest"] != criterion_digest(crit):
            return "digest-mismatch", "the criterion changed after the reviewer read it"
    f = _row_fault(ctx, row, intro, need_commit=need_commit, recording=recording)
    if f:
        return f
    if row["outcome"] == GREEN:
        cl = ctx.classify(crit)
        if cl.delegation_class != REVIEWER_JUDGES:
            return "not-reviewer-judged", (
                f"AC#{crit.index} is {cl.cls} ({cl.delegation_class}): only the operator may "
                f"answer it, so no reviewer verdict can satisfy or escalate it — {cl.reason}")
        return (_strength_fault(ctx, row, crit) or _run_fault(ctx, row, crit, recording=recording)
                or _stale_fault(ctx, row))
    return None


def _task_text_at(root: Path, rev: str, task_id: str) -> str:
    """The task file as committed at `rev`; '' when it was not there."""
    rc, listing = _git_out(root, "ls-tree", "-r", "--name-only", rev, "--", ".tasks/active", ".tasks/completed")
    if rc != 0:
        return ""
    name = next((ln for ln in listing.splitlines()
                 if Path(ln).name.startswith(f"{task_id}-") or Path(ln).name == f"{task_id}.md"), None)
    if not name:
        return ""
    rc, blob = _git_out(root, "show", f"{rev}:{name}")
    return blob if rc == 0 else ""


def required_strength(ctx: "_Ctx", crit, revision: str = "") -> tuple[int, str]:
    """(rung, reason) IW-7 requires for `crit`, from lib/review_policy.py — the function `judge`
    uses to choose its rung. Scored on the task as it is NOW and as it stood at the reviewed
    revision; the higher wins, so lowering the task's risk fields after the review, or before it
    in an uncommitted edit, does not lower what the verdict must have been."""
    body = [criterion_body(crit)]
    rung, why = review_policy.required_rung(frontmatter(ctx.text), body)
    then = _task_text_at(ctx.root, revision, ctx.task_id) if revision else ""
    if then:
        r2, w2 = review_policy.required_rung(frontmatter(then), body)
        if r2 > rung:
            rung, why = r2, f"{w2} (at reviewed revision {revision[:9]})"
    return rung, why


def _strength_fault(ctx: "_Ctx", row: dict, crit) -> tuple[str, str] | None:
    """A green counts only at the review strength IW-7 requires for this criterion (round 6).

    rung 1 (low impact): any registered independent review dispatch. Rung 3 or 5: the dispatch
    must be bound, at registration and so before launch, to a signed review run whose rung is at
    least the required one — or one step lower only with a ceiling decision the ledger re-derives
    (lib/review_policy.verify_ceiling_decision). A panel rung needs a run demanding PANEL_SIZE seats
    and vendors (`_panel_fault` then checks each seat). The row's `--rung` must be the run's rung:
    the label is what the run authorised, never what the worker typed."""
    root = ctx.root
    need, why = required_strength(ctx, crit, str(row.get("revision") or ""))
    claimed = review_policy.rung_number(row.get("rung"))
    run, _bind, rwhy = run_for_dispatch(root, str(row["dispatch_id"]))
    if rwhy:
        return "run", rwhy
    if run is None:
        if need <= 1:
            return None     # rung 1: any registered independent review dispatch; the label is prose
        return "under-strength", (
            f"{ctx.task_id} AC#{crit.index} requires rung {need} ({why}); dispatch "
            f"{row['dispatch_id']!r} is not bound to an authorised review run, so its claimed "
            f"{row.get('rung')!r} is unverified and cannot satisfy it")
    if claimed is None:
        return "rung", f"rung {row.get('rung')!r} names no rung number (rung-N-...)"
    granted = review_policy.rung_number(run.get("rung"))
    if granted is None:
        return "run", f"run {run.get('run_id')!r} names no rung"
    if claimed != granted:
        return "rung-mismatch", (f"the row claims rung {claimed}; its run {run['run_id']!r} "
                                 f"authorised rung {granted}")
    if granted < need:
        dec = run.get("ceiling_decision")
        if not review_policy.is_step_down(dec) or int(dec["granted"]) != granted \
                or int(dec["due"]) < need:
            return "under-strength", (
                f"{ctx.task_id} AC#{crit.index} requires rung {need} ({why}); run "
                f"{run['run_id']!r} is rung {granted} with no ceiling decision that steps down "
                f"from rung {need}")
        bad = review_policy.verify_ceiling_decision(root, dec, str(run.get("ts") or ""))
        if bad:
            return "ceiling-unverified", (f"run {run['run_id']!r} steps rung {dec.get('due')} down to "
                                          f"{granted}, but {bad}")
    if granted >= 5 and (int(run.get("required_vendors") or 0) < review_policy.PANEL_SIZE
                         or len(run.get("seats") or []) < review_policy.PANEL_SIZE):
        return "under-strength", (f"run {run['run_id']!r} claims a rung-{granted} panel but requires "
                                  f"{run.get('required_vendors')} vendor(s) over "
                                  f"{len(run.get('seats') or [])} seat(s); a panel is "
                                  f"{review_policy.PANEL_SIZE}")
    return None


#: Paths a later commit may touch without changing what was reviewed: the reviewer's own records,
#: framework state, and the task file (the criterion itself is pinned by its digest).
_NOT_WORK = (".context/", ".tasks/")


def _stale_fault(ctx: _Ctx, row: dict) -> tuple[str, str] | None:
    """A green reviewed revision R. If work for the task landed after R, the green is about code
    that is no longer what ships: refuse it (T-3580 round 3, reviewed-revision negative control)."""
    rev = str(row.get("revision") or "")
    rc, out = _git_out(ctx.root, "log", f"{rev}..HEAD", f"--grep={ctx.task_id}", "--name-only",
                       "--format=%x1e%H%x1f%B%x1d")
    if rc != 0:
        return "stale-review", f"git cannot say what changed since reviewed revision {rev[:9]} — refusing"
    ref = re.compile(rf"(?<![A-Za-z0-9-]){re.escape(ctx.task_id)}(?![0-9])")
    for rec in out.split("\x1e"):
        if "\x1d" not in rec:
            continue
        head, files = rec.split("\x1d", 1)
        sha, _, msg = head.partition("\x1f")
        if not ref.search(msg):
            continue
        work = [f for f in files.splitlines() if f.strip() and not f.startswith(_NOT_WORK)]
        if work:
            return "stale-review", (f"{ctx.task_id} work changed after reviewed revision {rev[:9]} "
                                    f"(commit {sha[:9]} touches {work[0]}) — the verdict is about "
                                    f"code that no longer ships; review again")
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
    # Validate BEFORE reading the outcome (T-3580 round 3): an invalid latest row is `unknown`,
    # whatever colour it claims, for every consumer (apply, check-render, judge, audit).
    f = _fault(ctx, last, crit, led.intro(last["id"]))
    if f:
        return None, f"unknown: the latest verdict {last.get('id')} is invalid — {f[0]}: {f[1]}"
    if last.get("outcome") != GREEN:
        return None, f"latest verdict is {last.get('outcome')!r}"
    why = _panel_fault(ctx, crit, last, mine)
    if why:
        return None, why
    return last, ""


def _panel_fault(ctx: _Ctx, crit, last: dict, mine: list[dict]) -> str:
    """'' unless `last` belongs to a run whose requirements are not all met: every required seat
    needs its own valid, completed green for this criterion, and the seats must span the run's
    required number of distinct vendors (a single-vendor panel cannot satisfy a three-vendor one).
    A vendor is derived from each seat's registered worker KIND through the one mapping in
    policy/review-backends.yaml (round 5) AS COMMITTED at the dispatch's reviewed revision, for a
    kind the dispatcher can launch (round 6); a registered vendor that disagrees with it makes the
    seat unverified. Three registry aliases, or three vendor strings, for one kind are one vendor."""
    root, led = ctx.root, ctx.ledger
    run, _bind, _why = run_for_dispatch(root, str(last["dispatch_id"]))
    if run is None:
        return ""
    # Round 7: ONE binding for the whole run — its pinned revision and registry blob. The table
    # is derived once; a seat at another revision, or a registry that no longer hashes to the
    # pinned blob (an external framework checkout that moved), is refused.
    run_rev = str(run.get("revision") or "")
    pin = run.get("registry") or {}
    if not run_rev or not pin.get("sha256"):
        return f"panel-unverified-vendor: run {run['run_id']} pins no revision or registry blob"
    if registry_pin(root, run_rev).get("sha256") != pin.get("sha256"):
        return (f"panel-unverified-vendor: the registry at run {run['run_id']}'s revision "
                f"{run_rev[:9]} no longer hashes to the blob the run pinned ({pin.get('where')})")
    table = verified_kind_vendors(root, run_rev)
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
        f = _fault(ctx, r, crit, led.intro(r["id"]))
        if f:
            return (f"panel-incomplete: seat {s['seat']!r} of run {run['run_id']} is unknown (its "
                    f"latest verdict is invalid) — {f[0]}: {f[1]}")
        if r.get("outcome") != GREEN:
            return f"panel-incomplete: seat {s['seat']!r} of run {run['run_id']} is {r.get('outcome')!r}"
        drec, _ = dispatch_record(root, str(r["dispatch_id"]))
        kind = str((drec or {}).get("worker_kind") or "claude")
        if str((drec or {}).get("revision") or "") != run_rev:
            return (f"panel-unverified-vendor: seat {s['seat']!r} of run {run['run_id']} was "
                    f"dispatched at revision {str((drec or {}).get('revision') or 'none')[:9]}, not the "
                    f"run's pinned {run_rev[:9]} — every seat uses the run's one binding")
        # Round 6/7: derived from the registry COMMITTED at the run's ONE pinned revision and the
        # kinds the dispatcher can launch as committed there — never the working tree.
        v = table.get(kind, "")
        if not v or str((drec or {}).get("vendor") or "") != v:
            return (f"panel-unverified-vendor: seat {s['seat']!r} of run {run['run_id']} registered "
                    f"vendor {(drec or {}).get('vendor')!r} for worker kind {kind!r}, but "
                    f"{BACKENDS} as committed (for a launchable kind) maps it to {v or 'nothing'!r} "
                    f"— a vendor is derived from the worker kind, never taken from free text")
        vendors.add(v)
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

    # The worker session that runs this record: its identity derives from the dispatch id.
    worker = worker_identity(dispatch_id)
    if _norm(worker) not in _norm(reviewer):
        refuse("reviewer-worker-mismatch",
               f"reviewer {reviewer.strip()!r} is not attributed to worker {worker!r} — the "
               f"reviewer identity must contain the worker session of dispatch {dispatch_id!r}")
    # The reviewed revision is the one the DISPATCH was issued for (captured before the worker
    # started), never HEAD now: work that lands during the review must not be credited to it.
    revision = str(drec.get("revision") or "")
    if not revision:
        refuse("no-revision", f"dispatch {dispatch_id!r} names no reviewed revision — the "
                              f"repository had no commit when it was issued")
    if _criterion_at(root, revision, task_id, ac_index) != dg:
        refuse("revision-mismatch",
               f"at reviewed revision {revision[:9]} AC#{ac_index} is not the text digest {dg} — "
               f"commit the task before dispatching the review, so it is bound to a revision")

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
    # Not committed yet, and no completion yet: the runtime signs one when the worker exits.
    f = _fault(ctx, rec, crit, None, need_commit=False, recording=True)
    if f:
        refuse(*f)
    if ctx.ledger.faults:
        refuse("ledger-integrity", f"{ctx.ledger.faults[0]} — no row is appended to a ledger "
                                   f"whose history does not verify")
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


def _step_down_of(root: Path, r: dict) -> str:
    """'rung R granted, rung D due, reason' when the row's run stepped down (round 7); else ''."""
    run, _bind, _why = run_for_dispatch(root, str(r.get("dispatch_id") or ""))
    return review_policy.disclosure((run or {}).get("ceiling_decision"))


def _cite(r: dict, root: Path | None = None) -> str:
    down = _step_down_of(root, r) if root is not None else ""
    return (f"  **Reviewer verdict:** green {r['id']} — {r['reviewer']} (rung {r['rung']}), "
            f"digest {r['ac_digest']}; dispatch {r['dispatch_id']}; "
            + (f"STEP-DOWN: {down}; " if down else "")
            + f"evidence: {', '.join(r['evidence'])}; ledger {VERDICTS}")


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
                lines[ann[0]] = _cite(r, root)
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
        lines.insert(c.end, _cite(r, root))
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
    comps_exist = (root / COMPLETIONS).is_file()
    # Round 7: every step-down is reported as a WARN, whether or not a verdict has used it yet.
    downs = [f"WARN step-down: run {run.get('run_id')} ({run.get('task')}): "
             f"{review_policy.disclosure(run['ceiling_decision'])}"
             for run in _read(RUNS, root)
             if run.get("kind") == "run" and review_policy.is_step_down(run.get("ceiling_decision"))]
    if not n and not led.torn and not led.faults and not led.missing \
            and not _read(APPLIED, root) and not comps_exist:
        return 0, downs + ["verdict ledger: empty or absent (path is off until a review dispatch writes rows)"]
    out, bad = [], 0
    if comps_exist:
        # T-3580 round 5: the completions file is under the same append-only history check as the
        # ledger. It is written by run.sh AFTER the worker's last commit, so its newest rows are
        # normally uncommitted; that is named here as a WARN rather than left silent.
        hist = history_fault(root, COMPLETIONS)
        if hist:
            bad += 1
            out.append(f"FAIL completions integrity: {hist}")
        elif not _tracked(root, COMPLETIONS):
            out.append(f"WARN completions file untracked: {COMPLETIONS} has no git history — its "
                       f"rows are append-only-checked only once committed")
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
    out += downs
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
    g.add_argument("--revision", default="", help="commit the reviewer is asked to review (default HEAD)")
    g.add_argument("--wdir", default="", help="the runtime's worker directory")
    g.add_argument("--worker-kind", default="", help="the worker kind the dispatcher launches; "
                   "its vendor is derived from policy/review-backends.yaml, never passed in")
    g.add_argument("--ttl", type=int, default=DEFAULT_TTL,
                   help="seconds after registration past which no completion is accepted")
    g.add_argument("--run-id", default="", help="the signed review run this dispatch is authorised "
                   "under (bound here, before launch)")
    g.add_argument("--seat", default="", help="the run seat this dispatch fills")
    g.add_argument("--worker-bin", default="", help="(review) the absolute worker binary the "
                   "dispatcher resolved; run.sh launches exactly this")

    st = sub.add_parser("start", help="(dispatch runtime, first act of run.sh) record that the "
                        "runtime started for this dispatch")
    st.add_argument("--dispatch-id", required=True)
    st.add_argument("--wdir", required=True)

    sub.add_parser("kind-vendors", help="print `<worker kind> <vendor>` from the one mapping "
                   "(policy/review-backends.yaml)")

    cp = sub.add_parser("complete", help="(dispatch runtime, after the worker exits) sign what the "
                        "review worker left behind")
    cp.add_argument("--dispatch-id", required=True)
    cp.add_argument("--wdir", required=True)
    cp.add_argument("--exit-code", type=int, required=True)
    cp.add_argument("--session", default="")
    cp.add_argument("--worker-kind", default="", help="the worker kind the runtime actually ran")
    cp.add_argument("--secret-stdin", action="store_true",
                    help="read the per-dispatch completion secret from stdin (never argv or env)")

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
                                issuer_identity=args.issuer_identity,
                                revision=args.revision, wdir=args.wdir,
                                worker_kind=args.worker_kind, ttl=args.ttl,
                                run_id=args.run_id, seat=args.seat, worker_bin=args.worker_bin)
        print(json.dumps({k: row[k] for k in ("dispatch_id", "task", "task_type", "revision",
                                              "worker_kind", "vendor")}))
        return 0
    if args.cmd == "kind-vendors":
        for k, v in sorted(kind_vendors().items()):
            print(f"{k} {v}")
        return 0
    if args.cmd == "start":
        try:
            _b, secret = start(args.dispatch_id, wdir=args.wdir, pid=os.getppid())
        except VerdictRefused as e:
            print(f"REFUSED: {e}", file=sys.stderr)
            return 1
        print(secret)      # to run.sh's command substitution only; it keeps it in memory
        return 0
    if args.cmd == "complete":
        try:
            c = complete(args.dispatch_id, wdir=args.wdir, exit_code=args.exit_code,
                         session=args.session, worker_kind=args.worker_kind,
                         secret=sys.stdin.read() if args.secret_stdin else "")
        except VerdictRefused as e:
            print(f"REFUSED: {e}", file=sys.stderr)
            return 1
        print(json.dumps({"dispatch_id": c["dispatch_id"], "exit_code": c["exit_code"],
                          "verdicts": len(c["verdicts"]), "sig": c["sig"]}))
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
