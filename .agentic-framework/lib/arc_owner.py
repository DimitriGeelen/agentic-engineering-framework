#!/usr/bin/env python3
"""Arc owner opt-in and the resume brief (T-5251, T-5224 slice 2).

T-5224 GO, IW-3 (docs/reports/T-5224-arc-orchestrator.md): the owner role is opt-in
per arc. ``fw arc owner <arc> on`` switches it on by writing, in the arc YAML,

    journal: true
    owner:
      role: "on"
      wake: notice        # or worker; read by T-5252
      since: "<UTC ts>"

T-5253 adds ``decision_review: operator|reviewer|either`` (who may approve a
consequential journal decision; default operator), set with ``--decision-review`` and,
like ``wake_limit``, kept across off/on.

``off`` writes ``journal: false`` and ``role: "off"`` (the journal file is kept).
The edit is line-based: every other line of the YAML, comments included, is left
byte-for-byte as it was. ``role`` is quoted because YAML 1.1 reads a bare ``on``
as a boolean.

``brief`` is what ``fw arc resume`` prints: the resumability check
(lib/arc_journal.py) first, then the latest decided/outside entries (newest first,
capped), the latest next step with owner and deadline, and the arc's open member
tasks. ``fw arc resume`` sets focus from it; this module never touches focus files.

CLI:
  python3 lib/arc_owner.py set <arc> on|off [--wake notice|worker] [--decision-review operator|reviewer|either]
  python3 lib/arc_owner.py state <arc> [--json]
  python3 lib/arc_owner.py brief <arc> [--json] [--limit N]
Exit codes: set/state 0 ok, 2 usage/unknown arc; brief 0 resumable, 1 not, 2 usage.
``brief --json`` carries ``focus_task`` (the next entry's task when it is active).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib import arc_journal as aj  # noqa: E402
from lib.arc_membership import scan_tasks_by_arc_membership  # noqa: E402

WAKES = ("notice", "worker")
DECISION_LIMIT = 5
_TOP_KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):")


def _root(project_root=None) -> Path:
    return Path(project_root or os.environ.get("PROJECT_ROOT") or Path.cwd())


def _now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _block_end(lines: list[str], start: int) -> int:
    """Index after the top-level key at ``start`` and its indented/blank continuation."""
    i = start + 1
    while i < len(lines):
        ln = lines[i]
        if ln.strip() == "" or ln[0] in (" ", "\t"):
            i += 1
            continue
        break
    # trailing blank lines belong to whatever follows, not to this block
    while i > start + 1 and lines[i - 1].strip() == "":
        i -= 1
    return i


def _find_top(lines: list[str], key: str) -> int | None:
    for i, ln in enumerate(lines):
        m = _TOP_KEY_RE.match(ln)
        if m and m.group(1) == key:
            return i
    return None


def state(arc: str, project_root=None) -> dict:
    """{slug, journal (bool), owner: {role, wake, since} or None}."""
    slug, _n, path = aj.resolve_arc(arc, project_root)
    lines = path.read_text(encoding="utf-8").splitlines()
    owner = None
    i = _find_top(lines, "owner")
    if i is not None:
        owner = {}
        for ln in lines[i + 1:_block_end(lines, i)]:
            m = re.match(r"^\s+(role|wake|since|wake_limit|decision_review):\s*(.*?)\s*(#.*)?$", ln)
            if m:
                owner[m.group(1)] = m.group(2).strip("'\"")
        if not owner:
            owner = None
    return {"slug": slug, "journal": aj.journal_enabled(arc, project_root), "owner": owner}


def set_owner(arc: str, on: bool, wake: str | None = None, project_root=None,
              decision_review: str | None = None) -> dict:
    """Switch the owner role on or off. Returns the new state."""
    if wake is not None and wake not in WAKES:
        raise aj.JournalError(f"--wake must be one of {', '.join(WAKES)}, got '{wake}'")
    if decision_review is not None and decision_review not in aj.DECISION_REVIEW:
        raise aj.JournalError(f"--decision-review must be one of {', '.join(aj.DECISION_REVIEW)}, "
                              f"got '{decision_review}'")
    _slug, _n, path = aj.resolve_arc(arc, project_root)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    prev = state(arc, project_root).get("owner") or {}
    if wake is None:
        wake = prev.get("wake") if prev.get("wake") in WAKES else "notice"

    # drop the old owner block
    i = _find_top(lines, "owner")
    if i is not None:
        del lines[i:_block_end(lines, i)]

    journal_line = f"journal: {'true' if on else 'false'}"
    owner_block = ["owner:", f'  role: "{"on" if on else "off"}"', f"  wake: {wake}", f'  since: "{_now()}"']
    # T-5252: a per-arc wake limit set by hand survives switching on/off again.
    if str(prev.get("wake_limit") or "").isdigit():
        owner_block.append(f"  wake_limit: {prev['wake_limit']}")
    # T-5253: who approves consequential decisions; kept across off/on like wake_limit.
    if decision_review is None and prev.get("decision_review") in aj.DECISION_REVIEW:
        decision_review = prev["decision_review"]
    owner_block.append(f"  decision_review: {decision_review or aj.DEFAULT_DECISION_REVIEW}")
    j = _find_top(lines, "journal")
    if j is not None:
        m = re.match(r"^journal:\s*\S*(\s+#.*)?$", lines[j])
        lines[j] = journal_line + ((m.group(1) or "") if m else "")
        lines[j + 1:j + 1] = owner_block
    else:
        while lines and lines[-1].strip() == "":
            lines.pop()
        lines.extend([journal_line, *owner_block])
    out = "\n".join(lines) + "\n"
    tmp = path.with_name(path.name + ".tmp-arc-owner")
    tmp.write_text(out, encoding="utf-8")
    os.replace(tmp, path)
    return state(arc, project_root)


# ---------------------------------------------------------------- brief

def _task_info(root: Path, tid: str) -> dict | None:
    for sub in ("active", "completed"):
        for md in sorted((root / ".tasks" / sub).glob(f"{tid}-*.md")):
            head = md.read_text(encoding="utf-8", errors="replace")[:8192]
            def g(k):
                m = re.search(rf"(?m)^{k}:\s*(.*?)\s*$", head)
                return m.group(1).strip("'\"") if m else ""
            return {"id": tid, "status": g("status"), "horizon": g("horizon"),
                    "name": g("name"), "active": sub == "active"}
    return None


def _members(root: Path, slug: str, numeric: str | None) -> list[str]:
    by_id, by_tag = scan_tasks_by_arc_membership(root)
    ids = set(by_id.get(slug, [])) | set(by_tag.get(f"arc:{slug}", []))
    if numeric:
        ids |= set(by_id.get(numeric, []))
    return sorted(ids, key=lambda t: int(re.sub(r"\D", "", t) or 0))


def brief(arc: str, project_root=None, limit: int = DECISION_LIMIT, today=None) -> dict:
    root = _root(project_root)
    slug, numeric, _p = aj.resolve_arc(arc, root)
    findings, resumable = aj.check(arc, root, today=today)
    entries, _bad = aj.read(arc, root)
    decisions = [dict(aj._clean(e), ref=aj.entry_ref(e))
                 for e in entries if e["kind"] in ("decided", "outside")][::-1][:limit]
    nexts = [e for e in entries if e["kind"] == "next"]
    nxt = aj._clean(nexts[-1]) if nexts else None
    open_tasks = []
    for tid in _members(root, slug, numeric):
        info = _task_info(root, tid)
        if info and info["active"] and info["status"] != "work-completed":
            open_tasks.append(info)
    focus_task = None
    if nxt and nxt.get("task"):
        info = _task_info(root, str(nxt["task"]))
        if info and info["active"]:
            focus_task = info["id"]
    return {"arc": slug, "id": numeric, "resumable": resumable, "findings": findings,
            "owner": state(arc, root)["owner"], "decisions": decisions, "next": nxt,
            "open_tasks": open_tasks, "focus_task": focus_task,
            "unapproved": aj.unapproved(arc, root)}


def render(b: dict) -> str:
    out = []
    name = b["arc"] + (f" ({b['id']})" if b.get("id") and b["id"] != b["arc"] else "")
    out.append(f"Arc {name}: {'RESUMABLE' if b['resumable'] else 'NOT resumable'}")
    for f in b["findings"]:
        tag = "" if f["blocking"] else " (informational)"
        out.append(f"  {f['code']}{tag}: {f['reason']}")
    out.append("")
    out.append("Latest decisions (newest first):")
    if not b["decisions"]:
        out.append("  (none recorded)")
    for d in b["decisions"]:
        extra = f" [where: {d['where']}]" if d["kind"] == "outside" else ""
        flag = " [consequential]" if d.get("consequential") else ""
        out.append(f"  {d.get('ref', ''):<6} {d['ts'][:16]}  {d['kind']:<7} {d['text']} — {d['reason']}{extra}{flag} (by {d['by']})")
    if b.get("unapproved"):
        out.append("")
        out.append("Consequential decisions waiting for approval (the arc is held until each is approved):")
        for u in b["unapproved"]:
            out.append(f"  {u['ref']}  [{u.get('category') or 'consequential'}] {u['text']} (by {u['by']})")
            out.append(f"        operator: {u['command']}")
    out.append("")
    out.append("Next step:")
    n = b["next"]
    if not n:
        out.append("  (none written — write one with: fw arc journal " + b["arc"] + " next --step ... --owner ...)")
    else:
        out.append(f"  {n['step']}")
        out.append(f"  owner: {n['owner']}   deadline: {n.get('deadline') or '(none)'}"
                   + (f"   task: {n['task']}" if n.get("task") else ""))
    out.append("")
    out.append("Open member tasks:")
    if not b["open_tasks"]:
        out.append("  (none)")
    for t in b["open_tasks"]:
        out.append(f"  {t['id']} [{t['status'] or '?'}/{t['horizon'] or '?'}]  {t['name']}")
    return "\n".join(out)


# ---------------------------------------------------------------- CLI

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="arc_owner.py", description="Arc owner opt-in and resume brief (T-5251)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("set")
    s.add_argument("arc")
    s.add_argument("mode", choices=("on", "off"))
    s.add_argument("--wake", choices=WAKES)
    s.add_argument("--decision-review", dest="decision_review", choices=aj.DECISION_REVIEW)
    st = sub.add_parser("state")
    st.add_argument("arc")
    st.add_argument("--json", action="store_true")
    b = sub.add_parser("brief")
    b.add_argument("arc")
    b.add_argument("--json", action="store_true")
    b.add_argument("--limit", type=int, default=DECISION_LIMIT)
    try:
        args = ap.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    try:
        if args.cmd == "set":
            if args.mode == "off" and (args.wake or args.decision_review):
                print("arc_owner: --wake and --decision-review apply to 'on' only", file=sys.stderr)
                return 2
            new = set_owner(args.arc, args.mode == "on", args.wake, decision_review=args.decision_review)
            o = new["owner"] or {}
            print(f"Arc {new['slug']}: owner {o.get('role')} (wake {o.get('wake')}, decision review "
                  f"{o.get('decision_review')}), journal "
                  f"{'on' if new['journal'] else 'off'}")
            return 0
        if args.cmd == "state":
            cur = state(args.arc)
            if args.json:
                print(json.dumps(cur))
            else:
                o = cur["owner"]
                own = (f"{o.get('role')} (wake {o.get('wake')}, since {o.get('since')}, decision review "
                       f"{o.get('decision_review') or aj.DEFAULT_DECISION_REVIEW})"
                       if o else "not set")
                print(f"Owner: {own}   Journal: {'on' if cur['journal'] else 'off'}")
            return 0
        if args.cmd == "brief":
            br = brief(args.arc, limit=args.limit)
            print(json.dumps(br, ensure_ascii=False) if args.json else render(br))
            return 0 if br["resumable"] else 1
    except aj.JournalError as e:
        print(f"arc_owner: {e}", file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
