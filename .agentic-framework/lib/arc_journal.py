#!/usr/bin/env python3
"""Arc journal: one append-only journal per arc, plus a resumability check (T-5250).

T-5224 GO, IW-2 (docs/reports/T-5224-arc-orchestrator.md): a fresh agent found the
right next step 7/10 times from the records as they were and 10/10 once every
decision, including ones taken outside the arc, was written at the unit. This module
is that record.

Journal: ``.context/arcs/<slug>.journal.jsonl`` beside the arc YAML, one JSON object
per line. Rows are only ever appended (O_APPEND, under an exclusive flock on the
journal itself); nothing here rewrites or deletes a row.

Entry kinds and their fields (every row also carries ``ts`` UTC ISO, ``kind``, ``by``):

  tried    text, result
  decided  text, reason, consequential (bool, default false), category (optional:
           skip-step | accept-failed-check | defer | change-scope | other; any of
           the first four implies consequential: true — T-5253)
  next     step, owner, deadline (YYYY-MM-DD, optional)
  outside  text, reason, where
  event    task, from, to
  approved ref, route (operator | reviewer); operator: words; reviewer:
           dispatch_id, outcome (T-5253). Written only by approve(), never by
           append(): the CLI ``append`` refuses this kind.

Optional on any kind: ``task``.

Entry ids (T-5253): every row appended from T-5253 on carries ``id: J-<n>``, n one
more than the highest id in the journal, assigned under the append lock. Rows
written before that have no id and are addressed by position, ``J@<line>``
(append-only, so a line number never moves). ``entry_ref`` gives either.

Approval of consequential decisions (T-5253, T-5224 IW-4): a ``decided`` row with
``consequential: true`` holds the arc until an ``approved`` row references it:
  route operator  ``fw arc approve`` (operator-only; refused under agent control)
                  with the operator's words. Always counts: the operator is sovereign.
  route reviewer  counts only when the arc's ``owner.decision_review`` is reviewer
                  or either, the dispatch id is a correctly signed REVIEW dispatch in
                  the review-dispatch registry (lib/verdict_ledger.dispatch_record),
                  and the outcome is green. Refused at write time otherwise; a row
                  that no longer verifies is ignored at check time (INVALID_APPROVAL).

Resumability check findings:
  NO_NEXT                  no next entry at all                       (blocks)
  STALE_NEXT               a decided/outside/event row is later than
                           the latest next                            (blocks)
  ISSUES_WITHOUT_DECISION  an event into ``issues`` with no decided
                           row after it                               (blocks)
  DEADLINE_PASSED          the latest next's deadline is in the past  (informational)
  MALFORMED_ROW            a line that is not a valid entry           (blocks)
  CONSEQUENTIAL_UNAPPROVED a consequential decision with no valid
                           approval (finding carries ``ref``)         (blocks)
  INVALID_APPROVAL         an approved row that does not count        (informational)

CLI (the ``fw arc`` verbs are T-5251):
  python3 lib/arc_journal.py append <arc> <kind> --by X [--text ..] [--result ..]
        [--reason ..] [--step ..] [--owner ..] [--deadline YYYY-MM-DD] [--task T-..]
        [--consequential] [--where ..] [--from ..] [--to ..]
  python3 lib/arc_journal.py show <arc> [--json]
  python3 lib/arc_journal.py check <arc> [--json]
  python3 lib/arc_journal.py pending <arc> [--json]     unapproved consequential decisions
  python3 lib/arc_journal.py approve <arc> <ref> --by X (--words ".." |
        --dispatch-id D --outcome green) [--i-am-human]
Exit codes: append/show 0 ok, 2 usage/unknown arc; check 0 resumable, 1 not, 2 usage.
Also: ``task-event <task-file> <from> <to>`` used by update-task.sh (exit 0 always
unless the journal write failed; never called in a way that can block a status change).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import fcntl
import json
import os
import re
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib.arc_membership import arc_identities, parse_arc_id_value, read_frontmatter  # noqa: E402

KINDS: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = {
    # kind: (required fields, optional fields)
    "tried": (("text", "result"), ("task",)),
    "decided": (("text", "reason"), ("consequential", "category", "task")),
    "next": (("step", "owner"), ("deadline", "task")),
    "outside": (("text", "reason", "where"), ("task",)),
    "event": (("task", "from", "to"), ()),
    "approved": (("ref", "route"), ("words", "dispatch_id", "outcome", "task")),
}
# T-5253: decided categories; the first four are consequential by definition.
CATEGORIES = ("skip-step", "accept-failed-check", "defer", "change-scope", "other")
CONSEQUENTIAL_CATEGORIES = CATEGORIES[:4]
ROUTES = ("operator", "reviewer")
DECISION_REVIEW = ("operator", "reviewer", "either")
DEFAULT_DECISION_REVIEW = "operator"
_ID_RE = re.compile(r"^J-(\d+)$")
_POS_RE = re.compile(r"^J@(\d+)$")
# Kinds after which an older ``next`` is stale.
_STALE_AFTER = ("decided", "outside", "event")
_DEADLINE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class JournalError(Exception):
    """Unknown arc, unknown kind, or a missing/invalid field."""


def _project_root(project_root=None) -> Path:
    return Path(project_root or os.environ.get("PROJECT_ROOT") or Path.cwd())


def _now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def resolve_arc(arc: str, project_root=None) -> tuple[str, str | None, Path]:
    """(slug, arc-NNN or None, yaml path) for an arc named by slug or arc-NNN."""
    root = _project_root(project_root)
    slug, numeric = arc_identities(root, arc)
    arcs_dir = root / ".context" / "arcs"
    for cand in (arcs_dir / f"{slug}.yaml", *( [arcs_dir / f"{numeric}.yaml"] if numeric else [])):
        if cand.is_file():
            return slug, numeric, cand
    # arc_identities matched by content but the file stem differs from slug and id
    if numeric is not None:
        for p in sorted(arcs_dir.glob("*.yaml")):
            head = p.read_text(encoding="utf-8", errors="replace")[:8192]
            if re.search(rf"(?m)^slug:\s*['\"]?{re.escape(slug)}['\"]?\s*$", head):
                return slug, numeric, p
    raise JournalError(f"unknown arc '{arc}': no .context/arcs/*.yaml has that slug or id")


def journal_path(arc: str, project_root=None) -> Path:
    slug, _numeric, yaml_path = resolve_arc(arc, project_root)
    return yaml_path.parent / f"{slug}.journal.jsonl"


def journal_enabled(arc: str, project_root=None) -> bool:
    """True when the arc YAML has a top-level ``journal: true``."""
    _slug, _n, yaml_path = resolve_arc(arc, project_root)
    text = yaml_path.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"(?m)^journal:\s*(\S+)\s*(#.*)?$", text)
    return bool(m) and m.group(1).strip("'\"").lower() in ("true", "yes", "on")


def _validate(kind: str, by: str, fields: dict) -> dict:
    if kind not in KINDS:
        raise JournalError(f"unknown kind '{kind}' (allowed: {', '.join(KINDS)})")
    if not by or not str(by).strip():
        raise JournalError("every entry needs 'by' (who wrote it)")
    required, optional = KINDS[kind]
    row: dict = {}
    for f in required:
        v = fields.get(f)
        if v is None or (isinstance(v, str) and not v.strip()):
            raise JournalError(f"'{kind}' entry needs '{f}'")
        row[f] = v
    unknown = [k for k, v in fields.items() if v is not None and k not in required + optional]
    if unknown:
        raise JournalError(f"'{kind}' entry does not take: {', '.join(sorted(unknown))}")
    for f in optional:
        if fields.get(f) is not None:
            row[f] = fields[f]
    if kind == "decided":
        cat = fields.get("category")
        if cat is not None and cat not in CATEGORIES:
            raise JournalError(f"category must be one of {', '.join(CATEGORIES)}, got '{cat}'")
        row["consequential"] = bool(fields.get("consequential") or False) or cat in CONSEQUENTIAL_CATEGORIES
    if kind == "approved" and row["route"] not in ROUTES:
        raise JournalError(f"route must be one of {', '.join(ROUTES)}, got '{row['route']}'")
    if row.get("deadline") and not _DEADLINE_RE.match(str(row["deadline"])):
        raise JournalError(f"deadline must be YYYY-MM-DD, got '{row['deadline']}'")
    return row


def _max_id(path: Path) -> int:
    """Highest J-<n> already in the journal (0 when none). Torn/old rows are skipped."""
    hi = 0
    if not path.is_file():
        return hi
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            try:
                row = json.loads(raw)
            except json.JSONDecodeError:
                continue
            m = _ID_RE.match(str(row.get("id", ""))) if isinstance(row, dict) else None
            if m:
                hi = max(hi, int(m.group(1)))
    return hi


def append(arc: str, kind: str, by: str, project_root=None, **fields) -> dict:
    """Append one entry; returns the row written. Raises JournalError on bad input.

    ``approved`` rows go through approve(), which checks the approval first."""
    if kind == "approved":
        raise JournalError("'approved' entries are written by approve() (fw arc approve), "
                           "which checks the approval first")
    return _append(arc, kind, by, project_root, None, dict(fields))


def _append(arc, kind, by, project_root, guard, fields: dict) -> dict:
    """Append under the journal lock. ``guard(entries)`` runs inside the lock and may
    raise JournalError (or add to ``fields``), so a check-then-write cannot race a
    concurrent append."""
    _validate(kind, by, fields)
    path = journal_path(arc, project_root)
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            if guard is not None:
                guard(read(arc, project_root)[0])
            body = _validate(kind, by, fields)
            # T-5253: a stable id, assigned under the lock so two writers never share one.
            row = {"id": f"J-{_max_id(path) + 1}", "ts": _now(), "kind": kind, "by": str(by), **body}
            line = (json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n").encode("utf-8")
            # A torn last line (crash mid-write) must not glue onto this row.
            size = os.fstat(fd).st_size
            if size:
                with open(path, "rb") as rfh:
                    rfh.seek(size - 1)
                    if rfh.read(1) != b"\n":
                        line = b"\n" + line
            os.write(fd, line)
            os.fsync(fd)
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)
    return row


def read(arc: str, project_root=None) -> tuple[list[dict], list[dict]]:
    """(entries, malformed). Each malformed item is {line, reason, raw}; never dropped silently."""
    path = journal_path(arc, project_root)
    entries: list[dict] = []
    bad: list[dict] = []
    if not path.is_file():
        return entries, bad
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, raw in enumerate(fh, 1):
            if not raw.strip():
                continue
            try:
                row = json.loads(raw)
            except json.JSONDecodeError as e:
                bad.append({"line": n, "reason": f"not JSON ({e.msg})", "raw": raw.rstrip("\n")[:200]})
                continue
            if not isinstance(row, dict) or row.get("kind") not in KINDS or not row.get("ts") or not row.get("by") \
                    or ("id" in row and not _ID_RE.match(str(row["id"]))):
                bad.append({"line": n, "reason": "missing ts/by, unknown kind or bad id", "raw": raw.rstrip("\n")[:200]})
                continue
            missing = [f for f in KINDS[row["kind"]][0] if row.get(f) in (None, "")]
            if missing:
                bad.append({"line": n, "reason": f"'{row['kind']}' row lacks {', '.join(missing)}",
                            "raw": raw.rstrip("\n")[:200]})
                continue
            row["_line"] = n
            entries.append(row)
    return entries, bad


# ---------------------------------------------------------------- approvals (T-5253)

def is_consequential(e: dict) -> bool:
    """A decided row is consequential when flagged so or when its category says so."""
    return e.get("kind") == "decided" and (e.get("consequential") is True
                                           or e.get("category") in CONSEQUENTIAL_CATEGORIES)


def entry_ref(e: dict) -> str:
    """The address of an entry: its id, or J@<line> for a row written before ids."""
    return str(e.get("id") or f"J@{e.get('_line')}")


def find_entry(entries: list[dict], ref: str) -> dict | None:
    ref = str(ref or "").strip()
    if _POS_RE.match(ref):
        n = int(ref[2:])
        return next((e for e in entries if e.get("_line") == n and not e.get("id")), None)
    return next((e for e in entries if e.get("id") == ref), None)


def decision_review(arc: str, project_root=None) -> str:
    """The arc's ``owner.decision_review`` (operator | reviewer | either), default operator."""
    from lib import arc_owner  # lazy: arc_owner imports this module
    v = ((arc_owner.state(arc, project_root).get("owner") or {}).get("decision_review") or "").strip()
    return v if v in DECISION_REVIEW else DEFAULT_DECISION_REVIEW


def _review_dispatch_fault(dispatch_id: str, root: Path, target: dict | None = None,
                           anchor: str | None = None) -> str:
    """'' when ``dispatch_id`` is a correctly signed REVIEW dispatch that reviewed THIS
    decision and has a green verdict in the verdict ledger.

    T-5253 (agent review of the worker's result): existence alone let an agent approve its
    own consequential decision by citing any review dispatch and claiming 'green'. So the
    dispatch must be bound to the decision (its task, or the arc's anchor task when the
    decision names none), must start after the decision, and the green must come from the
    verdict ledger, not from the approval row."""
    from lib import verdict_ledger as vl  # the one registry reader; no second parser
    did = str(dispatch_id or "").strip()
    rec, why = vl.dispatch_record(root, did)
    if rec is None:
        return why
    if str(rec.get("task_type") or "") != vl.REVIEW_TASK_TYPE:
        return f"dispatch {dispatch_id!r} is a {rec.get('task_type') or 'untyped'} dispatch, not a review dispatch"
    if target is not None:
        want = target.get("task") or anchor
        if not want:
            return ("the decision names no task and the arc has no anchor_task, so no review "
                    "dispatch can be bound to it; use the operator route")
        if str(rec.get("task") or "") != str(want):
            return (f"dispatch {did!r} reviewed {rec.get('task') or 'no task'}, not {want} "
                    f"(the decision's task, or the arc's anchor task)")
        if str(rec.get("ts") or "") < str(target.get("ts") or ""):
            return f"dispatch {did!r} started before the decision was recorded, so it did not review it"
    greens = [r for r in vl._read(vl.VERDICTS, root)
              if r.get("dispatch_id") == did and str(r.get("outcome") or "").lower() == "green"]
    if not greens:
        return f"the verdict ledger has no green verdict from dispatch {did!r}"
    # T-5294: a verdict/1 green that fails its own check counts neither green nor red.
    if not any(not vl.not_checkable_reasons(r) for r in greens):
        return (f"dispatch {did!r}'s green vote is not checkable and does not count — "
                + "; ".join(vl.not_checkable_reasons(greens[-1])))
    return ""


def anchor_task(arc: str, root: Path) -> str | None:
    """The arc's anchor_task from its YAML, or None."""
    try:
        _slug, _num, y = resolve_arc(arc, root)
        m = re.search(r"(?m)^anchor_task:\s*['\"]?(T-\d+)", y.read_text(encoding="utf-8")[:8192])
        return m.group(1) if m else None
    except (JournalError, OSError):
        return None


def approval_fault(a: dict, setting: str, root: Path, entries: list[dict] | None = None,
                   anchor: str | None = None) -> str:
    """'' when the approved row ``a`` counts; else why not."""
    route = a.get("route")
    if route == "operator":
        return "" if str(a.get("words") or "").strip() else "operator approval without the operator's words"
    if route != "reviewer":
        return f"unknown route {route!r}"
    if setting not in ("reviewer", "either"):
        return (f"this arc takes decision approval from the {setting} (owner.decision_review), "
                f"not from a reviewer")
    if str(a.get("outcome") or "").strip().lower() != "green":
        return f"reviewer outcome is {a.get('outcome') or 'missing'}, not green"
    target = find_entry(entries or [], a.get("ref"))
    why = _review_dispatch_fault(a.get("dispatch_id"), root, target, anchor)
    if why:
        return why
    # One review dispatch approves one decision.
    for o in entries or []:
        if o is not a and o["kind"] == "approved" and o.get("route") == "reviewer" \
                and o.get("dispatch_id") == a.get("dispatch_id") and o.get("ref") != a.get("ref") \
                and o.get("_line", 0) < a.get("_line", 1 << 30):
            return f"dispatch {a.get('dispatch_id')!r} already approved {o.get('ref')}"
    return ""


def approval_state(arc: str, project_root=None, entries: list[dict] | None = None) -> dict:
    """{'unapproved': [decided rows], 'invalid': [(approved row, reason)], 'approved': {ref: row}}."""
    root = _project_root(project_root)
    if entries is None:
        entries, _bad = read(arc, root)
    setting = decision_review(arc, root)
    valid: dict[str, dict] = {}
    invalid: list[tuple[dict, str]] = []
    for a in (e for e in entries if e["kind"] == "approved"):
        target = find_entry(entries, a.get("ref"))
        if target is None or target["kind"] != "decided":
            invalid.append((a, f"references {a.get('ref')}, which is not a decided entry in this journal"))
            continue
        why = approval_fault(a, setting, root, entries, anchor_task(arc, root))
        if why:
            invalid.append((a, why))
        else:
            valid.setdefault(entry_ref(target), a)
    unapproved = [e for e in entries
                  if e["kind"] == "decided" and is_consequential(e) and entry_ref(e) not in valid]
    return {"unapproved": unapproved, "invalid": invalid, "approved": valid, "setting": setting}


def approve_command(arc: str, e: dict) -> str:
    return f'fw arc approve {arc} {entry_ref(e)} --words "<your words>"'


def unapproved(arc: str, project_root=None) -> list[dict]:
    """Consequential decisions without a valid approval, each with ``ref`` and the approve command."""
    out = []
    for e in approval_state(arc, project_root)["unapproved"]:
        out.append({"ref": entry_ref(e), "ts": e["ts"], "by": e["by"], "text": e.get("text"),
                    "reason": e.get("reason"), "category": e.get("category"),
                    "command": approve_command(arc, e)})
    return out


def approve(arc: str, ref: str, by: str, *, words: str | None = None, dispatch_id: str | None = None,
            outcome: str | None = None, project_root=None) -> dict:
    """Append an ``approved`` row after checking it would count. Raises JournalError otherwise.

    Who may call the operator route is the CLI's job (it refuses agents, T-5253);
    this function checks what the row says."""
    root = _project_root(project_root)
    if words is not None and (dispatch_id is not None or outcome is not None):
        raise JournalError("an approval is either the operator's (--words) or a reviewer's "
                           "(--dispatch-id/--outcome), not both")
    route = "operator" if words is not None else "reviewer"
    fields = {"ref": str(ref or "").strip(), "route": route}
    if route == "operator":
        fields["words"] = words
    else:
        fields["dispatch_id"] = dispatch_id
        fields["outcome"] = outcome
    setting = decision_review(arc, root)

    def guard(entries):
        target = find_entry(entries, fields["ref"])
        if target is None:
            raise JournalError(f"no entry {fields['ref']} in the journal of {arc}")
        if target["kind"] != "decided":
            raise JournalError(f"{fields['ref']} is a '{target['kind']}' entry; only decisions are approved")
        if not is_consequential(target):
            raise JournalError(f"{fields['ref']} is a routine decision; it needs no approval")
        st = approval_state(arc, root, entries)
        if entry_ref(target) in st["approved"]:
            prev = st["approved"][entry_ref(target)]
            raise JournalError(f"{fields['ref']} is already approved ({prev.get('id') or 'J@' + str(prev.get('_line'))}, "
                               f"{prev['route']} route, by {prev['by']})")
        probe = dict(fields, kind="approved", by=by, _line=1 << 30)
        why = approval_fault(probe, setting, root, entries, anchor_task(arc, root))
        if why:
            raise JournalError(f"approval refused: {why}")
        if target.get("task") and "task" not in fields:
            fields["task"] = target["task"]

    if route == "operator" and not str(words or "").strip():
        raise JournalError("an operator approval needs the operator's words (--words)")
    if route == "reviewer" and (not str(dispatch_id or "").strip() or not str(outcome or "").strip()):
        raise JournalError("a reviewer approval needs --dispatch-id and --outcome")
    return _append(arc, "approved", by, root, guard, fields)


def check(arc: str, project_root=None, today: _dt.date | None = None) -> tuple[list[dict], bool]:
    """(findings, resumable). Each finding: {code, reason, blocking}."""
    entries, bad = read(arc, project_root)
    findings: list[dict] = []

    def add(code, reason, blocking=True):
        findings.append({"code": code, "reason": reason, "blocking": blocking})

    for b in bad:
        add("MALFORMED_ROW", f"journal line {b['line']} cannot be read: {b['reason']}")

    # Rows are in append order; ts ties are broken by that order.
    nexts = [i for i, e in enumerate(entries) if e["kind"] == "next"]
    if not nexts:
        add("NO_NEXT", "the journal has no 'next' entry, so nobody has written down what to do next")
    else:
        last = nexts[-1]
        nxt = entries[last]
        later = [e for e in entries[last + 1:] if e["kind"] in _STALE_AFTER]
        if later:
            e = later[-1]
            what = e.get("text") or (f"{e.get('task')} {e.get('from')} → {e.get('to')}" if e["kind"] == "event" else "")
            add("STALE_NEXT",
                f"the latest next step ('{nxt['step']}', {nxt['ts']}) was written before "
                f"{len(later)} later {'entry' if len(later) == 1 else 'entries'} "
                f"(latest: {e['kind']} at {e['ts']}: {what}); write a new 'next' that accounts for them")
        dl = nxt.get("deadline")
        if dl:
            try:
                d = _dt.date.fromisoformat(str(dl))
                if d < (today or _dt.datetime.now(_dt.timezone.utc).date()):
                    add("DEADLINE_PASSED",
                        f"the latest next step ('{nxt['step']}', owner {nxt['owner']}) was due {dl}",
                        blocking=False)
            except ValueError:
                add("MALFORMED_ROW", f"journal line {nxt['_line']}: deadline '{dl}' is not YYYY-MM-DD")

    for i, e in enumerate(entries):
        if e["kind"] == "event" and str(e.get("to")) == "issues":
            if not any(x["kind"] == "decided" for x in entries[i + 1:]):
                add("ISSUES_WITHOUT_DECISION",
                    f"{e.get('task')} went into issues at {e['ts']} and no decision was recorded after it")

    # T-5253: a consequential decision holds the arc until it is approved.
    st = approval_state(arc, project_root, entries)
    for e in st["unapproved"]:
        f_ = {"code": "CONSEQUENTIAL_UNAPPROVED", "blocking": True, "ref": entry_ref(e),
              "reason": (f"{entry_ref(e)} ({e.get('category') or 'consequential'}, {e['ts']}, by {e['by']}): "
                         f"'{e.get('text')}' needs approval before anyone acts on it "
                         f"(decision_review: {st['setting']}); operator: {approve_command(arc, e)}")}
        findings.append(f_)
    for a, why in st["invalid"]:
        findings.append({"code": "INVALID_APPROVAL", "blocking": False, "ref": entry_ref(a),
                         "reason": f"{entry_ref(a)} (approval of {a.get('ref')}) does not count: {why}"})

    resumable = not any(f["blocking"] for f in findings)
    return findings, resumable


def task_event(task_file: str, old: str, new: str, project_root=None) -> dict | None:
    """Append an event for a task's status change if its arc opted in. None when not applicable."""
    fm, _complete = read_frontmatter(Path(task_file))
    m_arc = re.search(r"(?m)^arc_id:\s*(.+?)\s*$", fm)
    arc = parse_arc_id_value(m_arc.group(1)) if m_arc else ""
    if not arc:
        return None
    m_id = re.search(r"(?m)^id:\s*(T-\d+)\s*$", fm)
    if m_id:
        task = m_id.group(1)
    else:
        m_name = re.match(r"(T-\d+)", Path(task_file).name)
        task = m_name.group(1) if m_name else Path(task_file).stem
    try:
        if not journal_enabled(arc, project_root):
            return None
    except JournalError:
        return None  # arc_id not resolving is check-arc-id's business, not ours
    return append(arc, "event", "update-task", project_root, task=task, **{"from": old or "", "to": new})


# ---------------------------------------------------------------- CLI

def _clean(row: dict) -> dict:
    return {k: v for k, v in row.items() if not k.startswith("_")}


def render_pending(arc: str, items: list[dict]) -> str:
    if not items:
        return f"{arc}: no consequential decision is waiting for approval"
    out = [f"{arc}: {len(items)} consequential decision(s) waiting for approval:"]
    for i in items:
        out.append(f"  {i['ref']}  [{i.get('category') or 'consequential'}] {i['text']} — {i['reason']} (by {i['by']}, {i['ts'][:16]})")
        out.append(f"        approve (operator): {i['command']}")
    return "\n".join(out)


def _log_i_am_human(arc: str, ref: str) -> None:
    """--i-am-human under agent control is logged like the other operator verbs (T-1716 shape)."""
    log = _project_root() / ".context" / "working" / ".gate-bypass-log.yaml"
    try:
        log.parent.mkdir(parents=True, exist_ok=True)
        q = lambda v: "'" + str(v).replace("'", "''") + "'"  # noqa: E731
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(f"- timestamp: {q(_now()[:19] + 'Z')}\n  task: {q('<arc ' + arc + ' ' + ref + '>')}\n"
                     f"  flag: '--i-am-human'\n  caller: 'fw arc approve'\n"
                     f"  reason: 'operator-only approval of a consequential arc decision (T-5253)'\n")
    except OSError as e:
        print(f"arc_journal: warning: could not log --i-am-human: {e}", file=sys.stderr)


def _cli_approve(args) -> int:
    operator = args.words is not None
    if operator and args.dispatch_id is not None:
        raise JournalError("give --words (operator) or --dispatch-id/--outcome (reviewer), not both")
    if not operator and args.dispatch_id is None:
        raise JournalError("give --words \"<your words>\" (operator) or --dispatch-id D --outcome green (reviewer)")
    agent = os.environ.get("CLAUDECODE") == "1"
    if operator and agent and not args.i_am_human:
        print("ERROR: fw arc approve with --words is the operator's approval (T-5253, T-5224 IW-4).\n"
              "  You appear to be running inside Claude Code ($CLAUDECODE=1). An agent, the arc owner\n"
              "  included, cannot approve a consequential decision on the operator's behalf.\n"
              f"  Who can run it: the operator, in their own terminal:\n"
              f"    fw arc approve {args.arc} {args.ref} --words \"<your words>\"\n"
              "  Or, if this arc takes reviewer approval (fw arc owner <arc> on --decision-review\n"
              "  reviewer|either): an independent review dispatch's green verdict,\n"
              f"    fw arc approve {args.arc} {args.ref} --dispatch-id <review dispatch id> --outcome green\n"
              "  If this is a human typing inside an agent session (rare), pass --i-am-human (logged).",
              file=sys.stderr)
        return 1
    if operator and agent and args.i_am_human:
        _log_i_am_human(args.arc, args.ref)
    by = args.by or ("operator" if operator else f"reviewer:{args.dispatch_id}")
    try:
        row = approve(args.arc, args.ref, by, words=args.words, dispatch_id=args.dispatch_id,
                      outcome=args.outcome)
    except JournalError as e:
        print(f"arc_journal: {e}", file=sys.stderr)
        return 1
    print(json.dumps(row, ensure_ascii=False))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="arc_journal.py", description="Append-only arc journal (T-5250)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("append")
    a.add_argument("arc")
    a.add_argument("kind")
    a.add_argument("--by", required=True)
    for f in ("text", "result", "reason", "step", "owner", "deadline", "task", "where", "from", "to"):
        a.add_argument(f"--{f}", dest=f"f_{f}")
    a.add_argument("--consequential", action="store_true", default=None)
    a.add_argument("--category", dest="f_category", choices=CATEGORIES)
    ap_ = sub.add_parser("approve")
    ap_.add_argument("arc")
    ap_.add_argument("ref")
    ap_.add_argument("--by")
    ap_.add_argument("--words")
    ap_.add_argument("--dispatch-id", dest="dispatch_id")
    ap_.add_argument("--outcome")
    ap_.add_argument("--i-am-human", dest="i_am_human", action="store_true")
    pe = sub.add_parser("pending")
    pe.add_argument("arc")
    pe.add_argument("--json", action="store_true")
    s = sub.add_parser("show")
    s.add_argument("arc")
    s.add_argument("--json", action="store_true")
    c = sub.add_parser("check")
    c.add_argument("arc")
    c.add_argument("--json", action="store_true")
    t = sub.add_parser("task-event")
    t.add_argument("task_file")
    t.add_argument("old")
    t.add_argument("new")
    try:
        args = ap.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0

    try:
        if args.cmd == "append":
            fields = {k[2:]: v for k, v in vars(args).items() if k.startswith("f_") and v is not None}
            if args.consequential:
                fields["consequential"] = True
            row = append(args.arc, args.kind, args.by, **fields)
            print(json.dumps(row, ensure_ascii=False))
            return 0
        if args.cmd == "show":
            entries, bad = read(args.arc)
            if args.json:
                print(json.dumps({"arc": args.arc, "entries": [_clean(e) for e in entries], "malformed": bad},
                                 ensure_ascii=False, indent=2))
            else:
                if not entries and not bad:
                    print(f"{args.arc}: journal is empty")
                for e in entries:
                    rest = {k: v for k, v in _clean(e).items() if k not in ("id", "ts", "kind", "by")}
                    print(f"{entry_ref(e):<7} {e['ts']}  {e['kind']:<8} {e['by']:<14} "
                          + "  ".join(f"{k}={v}" for k, v in rest.items()))
                for b in bad:
                    print(f"MALFORMED line {b['line']}: {b['reason']}", file=sys.stderr)
            return 1 if bad else 0
        if args.cmd == "check":
            findings, ok = check(args.arc)
            if args.json:
                print(json.dumps({"arc": args.arc, "resumable": ok, "findings": findings}, ensure_ascii=False, indent=2))
            else:
                print(f"{args.arc}: {'resumable' if ok else 'NOT resumable'}")
                for f in findings:
                    tag = "" if f["blocking"] else " (informational)"
                    print(f"  {f['code']}{tag}: {f['reason']}")
            return 0 if ok else 1
        if args.cmd == "pending":
            items = unapproved(args.arc)
            if args.json:
                print(json.dumps({"arc": args.arc, "unapproved": items}, ensure_ascii=False, indent=2))
            else:
                print(render_pending(args.arc, items))
            return 1 if items else 0
        if args.cmd == "approve":
            return _cli_approve(args)
        if args.cmd == "task-event":
            task_event(args.task_file, args.old, args.new)
            return 0
    except JournalError as e:
        print(f"arc_journal: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"arc_journal: cannot write journal: {e}", file=sys.stderr)
        return 3
    return 2


if __name__ == "__main__":
    sys.exit(main())
