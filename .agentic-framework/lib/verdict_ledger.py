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
slice 3 (`fw reviewer judge`) calls it, and so may a human-run reviewer.

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

── THE PRODUCER CHECK ──────────────────────────────────────────────────────────

The producer is whoever committed work for the task, derived from git and NOT from
anything the reviewer says: every commit whose message references the task id
contributes its author name/email, committer name/email, and every `Co-Authored-By:`
trailer; a `producer:` / `producers:` frontmatter field adds to the set. Identities are
normalised (case and punctuation folded, so "Claude Sonnet 5.5" == "claude-sonnet-5-5")
and compared on the full string and on the model part after `/` or `:`. The check runs
at `record` time AND again at `apply` time — a reviewer who later commits work for the
same task is no longer independent of it, and their earlier verdict stops applying.

What this does not claim: it separates identities, not ROLES. A reviewer that names
itself differently from the producer while being the same agent passes. The `rung`
field records how independent the review claims to be (IW-3); the ladder is chosen by
the impact model (IW-7), not policed here.

── WHAT A GREEN VERDICT CAN SATISFY ────────────────────────────────────────────

Only a criterion the classifier routes to REVIEWER-JUDGES (lib/delegation.py — the one
place routing is defined; this module does not re-derive it). A criterion that is
tier0-or-bypass, act-in-the-world or a sovereignty field is operator-only, so a record
against it is refused outright — not merely ignored at apply time.

── DIGEST ──────────────────────────────────────────────────────────────────────

Keyed on the criterion's checkbox-line text, sha256[:12], the same function T-1985's
auto-tick uses. Edit the criterion and the verdict no longer applies: fresh consent.
"""

from __future__ import annotations

import argparse
import hashlib
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


def _refuse_row(root: Path, task: str, cls: str, reason: str, **extra) -> None:
    """The ONE place a refusal is written — redirect here when T-3555 lands."""
    row = {"ts": _now(), "gate": GATE, "task": task, "class": cls, "reason": reason}
    row.update(extra)
    _append(REFUSALS, row, root)


def criterion_digest(title: str) -> str:
    """Same as lib.reviewer.static_scan._compute_ac_text_digest (T-1985); pinned by a test."""
    return hashlib.sha256(title.encode()).hexdigest()[:12]


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


def producers(root: Path, task_id: str, task_text: str = "") -> set[str]:
    """Identities that produced the task's work — derived, never self-reported.

    See the module docstring. Returns raw identity strings; compare with `_identity_keys`.
    """
    found: set[str] = set()
    sep_f, sep_r = "\x1f", "\x1e"
    try:
        out = subprocess.run(
            ["git", "log", "--all", f"--grep={task_id}",
             f"--format=%an{sep_f}%ae{sep_f}%cn{sep_f}%ce{sep_f}%B{sep_r}"],
            cwd=str(root), capture_output=True, text=True, timeout=60,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        out = ""
    ref = re.compile(rf"(?<![A-Za-z0-9-]){re.escape(task_id)}(?![0-9])")
    for rec in out.split(sep_r):
        parts = rec.strip("\n").split(sep_f)
        if len(parts) < 5 or not ref.search(parts[4]):
            continue
        found.update(p.strip() for p in parts[:4] if p.strip())
        for t in _TRAILER_RE.findall(parts[4]):
            found.add(t)
            m = re.match(r"(.*?)\s*<([^>]*)>", t)
            if m:
                found.update(x.strip() for x in m.groups() if x.strip())
    fm = frontmatter(task_text) if task_text else {}
    for key in ("producer", "producers"):
        v = fm.get(key)
        if isinstance(v, (list, tuple)):
            found.update(str(x) for x in v if str(x).strip())
        elif v:
            found.update(x.strip() for x in re.split(r"[,\[\]]", str(v)) if x.strip())
    return found


def is_producer(identity: str, produced_by: set[str]) -> str:
    """The producer identity `identity` collides with, or ''."""
    mine = _identity_keys(identity)
    for p in produced_by:
        if mine & _identity_keys(p):
            return p
    return ""


# ── record ───────────────────────────────────────────────────────────────────


def record(task_id: str, ac_index: int, outcome: str, *, reviewer: str, rung: str,
           guidance: str = "", evidence: list[str] | None = None,
           digest: str = "", root: Path | None = None) -> dict:
    """Append a verdict for Human criterion `ac_index` of `task_id`, or raise VerdictRefused.

    Every refusal is written to the refusal ledger before it is raised.
    """
    root = root or _root()
    evidence = [e for e in (evidence or []) if e and e.strip()]
    outcome = (outcome or "").strip().lower()

    def refuse(cls: str, reason: str) -> NoReturn:
        _refuse_row(root, task_id, cls, reason, ac=ac_index, reviewer=reviewer)
        raise VerdictRefused(reason)

    if outcome not in OUTCOMES:
        refuse("bad-outcome", f"outcome {outcome!r} is not one of {', '.join(OUTCOMES)}")
    if not (reviewer or "").strip():
        refuse("no-reviewer", "reviewer identity is required (session/model/vendor)")
    if not (rung or "").strip():
        refuse("no-rung", "rung is required — how independent this review claims to be (IW-3)")

    path, sub = _find_task(root, task_id)
    if path is None:
        refuse("no-task", f"task {task_id} not found")
    if sub != "active":
        refuse("task-closed", f"{task_id} is in .tasks/{sub}; a settled task is not re-judged")
    text = path.read_text(encoding="utf-8", errors="replace")
    fm = frontmatter(text)

    crit = next((c for c in human_criteria(text) if c.index == ac_index), None)
    if crit is None:
        refuse("no-criterion", f"{task_id} has no Human criterion #{ac_index}")
    if crit.ticked:
        refuse("already-ticked", f"{task_id} Human AC#{ac_index} is already ticked")

    dg = criterion_digest(crit.title)
    if digest and digest != dg:
        refuse("digest-mismatch",
               f"the reviewer judged text with digest {digest} but AC#{ac_index} now has "
               f"digest {dg} — the criterion changed after it was read")

    cl = classify(crit, workflow_type=str(fm.get("workflow_type") or ""),
                  render_surface=_render_surface(root, path))
    if cl.delegation_class != REVIEWER_JUDGES:
        refuse("not-reviewer-judged",
               f"AC#{ac_index} is {cl.cls} ({cl.delegation_class}): only the operator may "
               f"answer it, so no reviewer verdict can satisfy or escalate it — {cl.reason}")

    hit = is_producer(reviewer, producers(root, task_id, text))
    if hit:
        refuse("reviewer-is-producer",
               f"reviewer {reviewer!r} matches {hit!r}, who committed work for {task_id}; "
               f"the reviewer is never the producer")

    if outcome == GREEN:
        if not evidence:
            refuse("no-evidence", "a green verdict needs at least one evidence path")
        missing = [e for e in evidence if not (root / e).exists()]
        if missing:
            refuse("evidence-missing", f"evidence path(s) not found under the repo: {missing}")

    try:
        jv = judge_verdict.verdict(_STATE[outcome], guidance,
                                   judged=f"{task_id}#AC{ac_index}", judge=reviewer,
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
        "rung": rung.strip(),
        "evidence": evidence,
        "judgement": jv,
    }
    _append(VERDICTS, rec, root)
    if outcome != GREEN:
        _refuse_row(root, task_id, f"verdict-{outcome}", jv["guidance"],
                    ac=ac_index, reviewer=rec["reviewer"], verdict_id=rec["id"])
    if outcome == ESCALATE:
        _route_to_operator(root, path, text, crit, rec)
    return rec


def _route_to_operator(root: Path, path: Path, text: str, crit, rec: dict) -> None:
    """Escalate: put the reviewer's reason ON the criterion and make the operator the owner.

    /review renders the criterion body, so a line under it is what the operator reads
    there. The line is a continuation, not part of the checkbox text, so it does not
    disturb the digest.
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


def satisfying(task_id: str, crit, produced_by: set[str], root: Path) -> dict | None:
    """The green record that satisfies `crit`, or None.

    The LATEST record for (task, ac, digest) decides — a later red withdraws an earlier
    green. A record for other text (digest mismatch) never counts. A reviewer who has
    since become a producer no longer counts.
    """
    dg = criterion_digest(crit.title)
    mine = [r for r in _read(VERDICTS, root)
            if r.get("task") == task_id and r.get("ac") == crit.index
            and r.get("ac_digest") == dg
            and not is_producer(str(r.get("reviewer", "")), produced_by)]
    if mine and mine[-1].get("outcome") == GREEN:
        return mine[-1]
    return None


def _task_context(root: Path, task_id: str):
    path, sub = _find_task(root, task_id)
    if path is None or sub != "active":
        return None
    text = path.read_text(encoding="utf-8", errors="replace")
    fm = frontmatter(text)
    return path, text, fm


def render_verdicts(task_id: str, root: Path | None = None) -> list[dict]:
    """Green verdicts that satisfy a Human criterion of this task (open OR already ticked).

    Ticked ones count: `apply` ticks the criterion, and the gate runs after it.
    """
    root = root or _root()
    ctx = _task_context(root, task_id)
    if ctx is None:
        return []
    path, text, fm = ctx
    prod = producers(root, task_id, text)
    out = []
    for c in human_criteria(text):
        r = satisfying(task_id, c, prod, root)
        if r:
            out.append(r)
    return out


def apply(task_id: str, root: Path | None = None) -> dict:
    """Tick every Human criterion a valid green verdict satisfies; hand ownership over
    to the agent when nothing is left for the operator to answer.

    Reads the ledger, writes only the task file and the applied ledger. Idempotent.
    """
    root = root or _root()
    result = {"task": task_id, "ticked": [], "owner_before": "", "owner_after": "",
              "skipped": ""}
    ctx = _task_context(root, task_id)
    if ctx is None:
        result["skipped"] = "task not active"
        return result
    path, text, fm = ctx
    workflow = str(fm.get("workflow_type") or "").strip().lower()
    owner = str(fm.get("owner") or "")
    result["owner_before"] = result["owner_after"] = owner
    if workflow == "inception":
        # The go/no-go gates (T-1259 / decision line) are rewired by their own slice;
        # a verdict must not tick around them.
        result["skipped"] = "inception: decision gates are outside this slice (T-3580)"
        return result

    prod = producers(root, task_id, text)
    rs = _render_surface(root, path)
    lines = text.split("\n")
    hits = []
    for c in human_criteria(text):
        if c.ticked:
            continue
        cl = classify(c, workflow_type=workflow, render_surface=rs)
        if cl.delegation_class != REVIEWER_JUDGES:
            continue
        r = satisfying(task_id, c, prod, root)
        if r:
            hits.append((c, r))
    if not hits:
        return result

    # Bottom-up so earlier line numbers stay valid while lines are inserted.
    for c, r in sorted(hits, key=lambda h: -h[0].start):
        lines[c.start] = re.sub(r"\[ \]", "[x]", lines[c.start], count=1)
        cite = (f"  **Reviewer verdict:** green {r['id']} — {r['reviewer']} (rung {r['rung']}), "
                f"digest {r['ac_digest']}; evidence: {', '.join(r['evidence'])}; "
                f"ledger {VERDICTS}")
        lines.insert(c.end, cite)
        result["ticked"].append({"ac": c.index, "verdict_id": r["id"], "reviewer": r["reviewer"]})
    result["ticked"].sort(key=lambda t: t["ac"])
    new_text = "\n".join(lines)

    still_open = [c for c in human_criteria(new_text) if not c.ticked]
    if owner == "human" and not still_open:
        new_text = re.sub(r"(?m)^owner:.*$", "owner: agent", new_text, count=1)
        result["owner_after"] = "agent"
    path.write_text(new_text, encoding="utf-8")
    _append(APPLIED, {"ts": _now(), "task": task_id, "kind": "verdict-apply",
                      "ticked": result["ticked"], "owner_before": owner,
                      "owner_after": result["owner_after"],
                      "open_human_remaining": len(still_open)}, root)
    return result


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
    r.add_argument("--digest", default="", help="digest of the criterion text the reviewer read")

    a = sub.add_parser("apply", help="tick green-judged criteria; hand ownership over if none left")
    a.add_argument("task_id")

    c = sub.add_parser("check-render", help="exit 0 when a green verdict satisfies the render gate")
    c.add_argument("task_id")

    ls = sub.add_parser("list", help="verdicts recorded for a task")
    ls.add_argument("task_id")

    args = ap.parse_args(argv)
    if args.cmd == "record":
        try:
            rec = record(args.task_id, args.ac, args.outcome, reviewer=args.reviewer,
                         rung=args.rung, guidance=args.guidance, evidence=args.evidence,
                         digest=args.digest)
        except VerdictRefused as e:
            print(f"REFUSED: {e}", file=sys.stderr)
            return 1
        print(json.dumps({k: rec[k] for k in ("id", "task", "ac", "ac_digest", "outcome")}))
        return 0
    if args.cmd == "apply":
        res = apply(args.task_id)
        print(json.dumps(res))
        return 0
    if args.cmd == "check-render":
        vs = render_verdicts(args.task_id)
        if not vs:
            return 1
        v = vs[0]
        print(f"green verdict {v['id']} by {v['reviewer']} (rung {v['rung']}) on "
              f"AC#{v['ac']} of {args.task_id}")
        return 0
    if args.cmd == "list":
        for row in _read(VERDICTS, _root()):
            if row.get("task") == args.task_id:
                print(json.dumps(row, sort_keys=True))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(_cli())
