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
  decided  text, reason, consequential (bool, default false)
  next     step, owner, deadline (YYYY-MM-DD, optional)
  outside  text, reason, where
  event    task, from, to

Optional on any kind: ``task``.

Resumability check findings:
  NO_NEXT                  no next entry at all                       (blocks)
  STALE_NEXT               a decided/outside/event row is later than
                           the latest next                            (blocks)
  ISSUES_WITHOUT_DECISION  an event into ``issues`` with no decided
                           row after it                               (blocks)
  DEADLINE_PASSED          the latest next's deadline is in the past  (informational)
  MALFORMED_ROW            a line that is not a valid entry           (blocks)

CLI (the ``fw arc`` verbs are T-5251):
  python3 lib/arc_journal.py append <arc> <kind> --by X [--text ..] [--result ..]
        [--reason ..] [--step ..] [--owner ..] [--deadline YYYY-MM-DD] [--task T-..]
        [--consequential] [--where ..] [--from ..] [--to ..]
  python3 lib/arc_journal.py show <arc> [--json]
  python3 lib/arc_journal.py check <arc> [--json]
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
    "decided": (("text", "reason"), ("consequential", "task")),
    "next": (("step", "owner"), ("deadline", "task")),
    "outside": (("text", "reason", "where"), ("task",)),
    "event": (("task", "from", "to"), ()),
}
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
        row["consequential"] = bool(fields.get("consequential") or False)
    if row.get("deadline") and not _DEADLINE_RE.match(str(row["deadline"])):
        raise JournalError(f"deadline must be YYYY-MM-DD, got '{row['deadline']}'")
    return row


def append(arc: str, kind: str, by: str, project_root=None, **fields) -> dict:
    """Append one entry; returns the row written. Raises JournalError on bad input."""
    body = _validate(kind, by, fields)
    path = journal_path(arc, project_root)
    row = {"ts": _now(), "kind": kind, "by": str(by), **body}
    line = (json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n").encode("utf-8")
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
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
            if not isinstance(row, dict) or row.get("kind") not in KINDS or not row.get("ts") or not row.get("by"):
                bad.append({"line": n, "reason": "missing ts/by or unknown kind", "raw": raw.rstrip("\n")[:200]})
                continue
            missing = [f for f in KINDS[row["kind"]][0] if row.get(f) in (None, "")]
            if missing:
                bad.append({"line": n, "reason": f"'{row['kind']}' row lacks {', '.join(missing)}",
                            "raw": raw.rstrip("\n")[:200]})
                continue
            row["_line"] = n
            entries.append(row)
    return entries, bad


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
                    rest = {k: v for k, v in _clean(e).items() if k not in ("ts", "kind", "by")}
                    print(f"{e['ts']}  {e['kind']:<8} {e['by']:<14} " + "  ".join(f"{k}={v}" for k, v in rest.items()))
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
