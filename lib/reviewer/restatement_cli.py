"""`fw reviewer restatement` — the operator accepts or rejects a reviewer's PROPOSED RESTATEMENT.

T-4930. Since T-4916 (decision i) a reviewer that finds a criterion's literal out of date
returns amber with a line `PROPOSED RESTATEMENT: <the criterion as it should read now>`,
for the operator to accept or reject once. Before this verb the restatement was free text
inside the amber row's `guidance`: nothing listed what was waiting, nothing recorded the
decision, and a rejection left no trace.

  list   [--task T-XXX] [--json]          pending restatements
  accept <verdict-id> [--dry-run]         restate the criterion, record the decision
  reject <verdict-id> --reason "…"        record the decision, change no task file

A restatement is pending while its amber row is the latest verdict for that criterion,
the row's digest still matches the criterion as it reads now, and no decision is in
`.context/reviews/restatements.jsonl`. Accept and reject are operator actions: under
CLAUDECODE=1 they refuse without --i-am-human (recorded `by: agent-override`). The agent
never edits criterion text on its own initiative.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from lib import verdict_ledger as vl
from lib.delegation import human_criteria

DECISIONS = Path(".context/reviews/restatements.jsonl")
MARKER_RE = re.compile(r"PROPOSED RESTATEMENT:[ \t]*(.*)")
_BOX_RE = re.compile(r"^(\s*[-*]\s*\[[ xX]\]\s*)(.*)$")
_PREFIX_RE = re.compile(r"^(\[[A-Za-z-]+\]\s*)")
MAX_LEN = 400


class Refused(ValueError):
    pass


def _root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def proposed(row: dict) -> str | None:
    """The restatement in an amber row's guidance, cleaned; None when there is none.

    Takes the rest of the marker's line; quotes or backticks wrapping the whole text go."""
    m = MARKER_RE.search(str(row.get("guidance") or ""))
    if not m:
        return None
    text = m.group(1).strip()
    while len(text) >= 2 and text[0] == text[-1] and text[0] in "`\"'":
        text = text[1:-1].strip()
    return text


def _check_text(text: str) -> None:
    if not text:
        raise Refused("the restatement is empty")
    if "\n" in text or "\r" in text:
        raise Refused("the restatement spans several lines")
    if len(text) > MAX_LEN:
        raise Refused(f"the restatement is {len(text)} characters (limit {MAX_LEN})")
    if re.search(r"\[[ xX]\]", text):
        raise Refused("the restatement contains a checkbox")


def _decided(root: Path) -> dict[str, dict]:
    return {str(r.get("verdict_id")): r for r in vl._read(DECISIONS, root) if r.get("verdict_id")}


def _latest_rows(root: Path, task: str | None = None) -> dict[tuple[str, int], dict]:
    """The latest verdict row per (task, ac); file order breaks ts ties (append-only)."""
    latest: dict[tuple[str, int], dict] = {}
    for row in vl._read(vl.VERDICTS, root):
        t = str(row.get("task") or "")
        if not t or (task and t != task):
            continue
        try:
            key = (t, int(row.get("ac")))
        except (TypeError, ValueError):
            continue
        if key not in latest or str(row.get("ts", "")) >= str(latest[key].get("ts", "")):
            latest[key] = row
    return latest


def _criterion(root: Path, task: str, ac: int):
    path, _ = vl._find_task(root, task)
    if path is None:
        return None, None, ""
    text = path.read_text(encoding="utf-8", errors="replace")
    crit = next((c for c in human_criteria(text) if c.index == ac), None)
    return path, crit, text


def pending(root: Path, task: str | None = None) -> list[dict]:
    decided = _decided(root)
    out = []
    for (t, ac), row in sorted(_latest_rows(root, task).items()):
        if row.get("outcome") != "amber" or str(row.get("id")) in decided:
            continue
        new = proposed(row)
        if new is None:
            continue
        _path, crit, _ = _criterion(root, t, ac)
        if crit is None or vl.criterion_digest(crit) != row.get("ac_digest"):
            continue
        out.append({"verdict_id": row.get("id"), "task": t, "ac": ac,
                    "current": crit.title.strip(), "proposed": new,
                    "reviewer": row.get("reviewer", ""), "ts": row.get("ts", "")})
    return out


def _find(root: Path, verdict_id: str) -> dict:
    rows = [r for r in vl._read(vl.VERDICTS, root) if str(r.get("id")) == verdict_id]
    if not rows:
        raise Refused(f"no verdict {verdict_id} in {vl.VERDICTS}")
    return rows[-1]


def _resolve(root: Path, verdict_id: str):
    """(row, restatement, path, crit, text) for a restatement that may still be decided."""
    row = _find(root, verdict_id)
    if row.get("outcome") != "amber":
        raise Refused(f"{verdict_id} is {row.get('outcome')}, not amber")
    new = proposed(row)
    if new is None:
        raise Refused(f"{verdict_id} has no PROPOSED RESTATEMENT line")
    if verdict_id in _decided(root):
        d = _decided(root)[verdict_id]
        raise Refused(f"{verdict_id} was already {d.get('decision')} ({d.get('ts', '')})")
    task, ac = str(row.get("task")), int(row.get("ac"))
    path, crit, text = _criterion(root, task, ac)
    if crit is None:
        raise Refused(f"{task} has no Human criterion {ac}")
    if vl.criterion_digest(crit) != row.get("ac_digest"):
        raise Refused(f"{task} criterion {ac} changed since {verdict_id} was written "
                      f"(digest {vl.criterion_digest(crit)}, verdict {row.get('ac_digest')}); "
                      f"re-run fw reviewer judge {task}")
    return row, new, path, crit, text


def _who(i_am_human: bool, action: str) -> str:
    if os.environ.get("CLAUDECODE") == "1":
        if not i_am_human:
            raise Refused(f"{action} a restatement is the operator's decision (T-4916 decision i); "
                          f"an agent may only --dry-run. Operator: add --i-am-human")
        return "agent-override"
    return "operator"


def restated_lines(crit, new: str, verdict_id: str, date: str) -> list[str]:
    """The criterion's lines with the title replaced and a `**Restated:**` line added."""
    first = crit.lines[0]
    m = _BOX_RE.match(first)
    if not m:
        raise Refused("the criterion's checkbox line is not in the expected form")
    box, old = m.group(1), m.group(2).strip()
    pm = _PREFIX_RE.match(old)
    title = new if (not pm or _PREFIX_RE.match(new)) else pm.group(1) + new
    indent = re.match(r"^\s*", first).group(0) + "  "
    for ln in crit.lines[1:]:
        if ln.strip():
            indent = re.match(r"^\s*", ln).group(0)
            break
    note = (f"{indent}**Restated:** {date}, accepting {verdict_id}; was: "
            f"{old.replace(chr(10), ' ')}")
    return [box + title, note] + crit.lines[1:]


def _write_atomic(path: Path, content: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.chmod(tmp, path.stat().st_mode & 0o777)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def _append(root: Path, rec: dict) -> None:
    p = root / DECISIONS
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, sort_keys=True) + "\n")


def accept(root: Path, verdict_id: str, *, dry_run: bool = False, i_am_human: bool = False) -> dict:
    row, new, path, crit, text = _resolve(root, verdict_id)
    _check_text(new)
    ts = _now()
    lines = text.split("\n")
    new_lines = restated_lines(crit, new, verdict_id, ts[:10])
    out = lines[:crit.start] + new_lines + lines[crit.end:]
    rec = {"verdict_id": verdict_id, "task": row["task"], "ac": int(row["ac"]),
           "decision": "accepted", "old_digest": row.get("ac_digest"),
           "old_title": crit.title.strip(), "new_title": new_lines[0].strip(), "ts": ts}
    if dry_run:
        return {**rec, "dry_run": True, "before": crit.lines[0], "after": new_lines[:2]}
    rec["by"] = _who(i_am_human, "accepting")
    _write_atomic(path, "\n".join(out))
    _append(root, rec)
    return {**rec, "file": str(path.relative_to(root))}


def reject(root: Path, verdict_id: str, reason: str, *, dry_run: bool = False,
           i_am_human: bool = False) -> dict:
    if not reason.strip():
        raise Refused("a rejection needs --reason")
    row, new, _path, crit, _text = _resolve(root, verdict_id)
    rec = {"verdict_id": verdict_id, "task": row["task"], "ac": int(row["ac"]),
           "decision": "rejected", "old_digest": row.get("ac_digest"),
           "proposed": new, "reason": reason.strip(), "ts": _now()}
    if dry_run:
        return {**rec, "dry_run": True}
    rec["by"] = _who(i_am_human, "rejecting")
    _append(root, rec)
    return rec


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw reviewer restatement",
                                 description="accept or reject a reviewer's PROPOSED RESTATEMENT (T-4930)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    ls = sub.add_parser("list", help="pending restatements")
    ls.add_argument("--task")
    ls.add_argument("--json", action="store_true")
    ac = sub.add_parser("accept", help="restate the criterion and record the decision (operator)")
    ac.add_argument("verdict_id")
    ac.add_argument("--dry-run", action="store_true")
    ac.add_argument("--i-am-human", action="store_true")
    rj = sub.add_parser("reject", help="record a rejection; no task file changes (operator)")
    rj.add_argument("verdict_id")
    rj.add_argument("--reason", required=True)
    rj.add_argument("--dry-run", action="store_true")
    rj.add_argument("--i-am-human", action="store_true")
    a = ap.parse_args(argv)
    root = _root()
    try:
        if a.cmd == "list":
            items = pending(root, a.task)
            if a.json:
                print(json.dumps(items, indent=2))
                return 0
            if not items:
                print("No pending restatements.")
                return 0
            for it in items:
                print(f"{it['verdict_id']}  {it['task']} AC {it['ac']}")
                print(f"  now:      {it['current']}")
                print(f"  proposed: {it['proposed']}")
            print(f"\n{len(items)} pending. Decide each: fw reviewer restatement accept <id> "
                  f"| reject <id> --reason \"…\"")
            return 0
        if a.cmd == "accept":
            res = accept(root, a.verdict_id, dry_run=a.dry_run, i_am_human=a.i_am_human)
            if a.dry_run:
                print(f"DRY RUN {a.verdict_id} ({res['task']} AC {res['ac']}): nothing written")
                print(f"  before: {res['before']}")
                for ln in res["after"]:
                    print(f"  after:  {ln}")
                return 0
            print(f"Accepted {a.verdict_id}: {res['task']} AC {res['ac']} restated in {res['file']}")
            print(f"Next: commit the task file, then re-run: fw reviewer judge {res['task']}")
            return 0
        res = reject(root, a.verdict_id, a.reason, dry_run=a.dry_run, i_am_human=a.i_am_human)
        print(("DRY RUN: would record " if a.dry_run else "Recorded ")
              + f"rejection of {a.verdict_id} ({res['task']} AC {res['ac']})")
        return 0
    except Refused as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
