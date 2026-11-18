#!/usr/bin/env python3
"""Recorded operator rulings (T-5235; operator ruling 2026-11-18, question 6, option A).

A Human criterion that only RECORDS a decision the operator already gave ("Should P-002
exempt read-only Bash …? GO / NO-GO / DEFER", answered "a") is classed OPERATOR-ONLY
when its text names an act in the world, so the operator is asked to rubber-stamp their
own ruling. Free text cannot carry "the operator already decided": an agent could write
"Ruling: a" under the criterion itself. So the ruling is recorded by the operator, in a
ledger an agent cannot write:

    fw reviewer ruling record T-XXX --ac N --ruling "<verbatim>" --ref "<where it was given>"

appends to `.context/reviews/recorded-rulings.jsonl`. The row is bound to the criterion's
current digest (`verdict_ledger.criterion_digest`, the digest a reviewer submits), so any
later edit to the criterion voids it.

WHAT IT LIFTS. Only `act-in-the-world` and `operator-marked` criteria. tier0-or-bypass and
sovereignty-field criteria stay OPERATOR-ONLY with any ruling recorded. A lifted criterion
is reviewer-judged ("ruling recorded (RL-…)"); the reviewer checks that the box matches the
recorded ruling, it does not make the ruling.

THE ONE DECISION POINT is `lib/delegation_widening.active_widening`, which asks
`active_ruling` first; the delegate report, the verdict ledger and the judge all call it.

VALIDATION. The ledger is the operator's: refused to agents by the module (even with
--i-am-human), by the Bash text gate and by the Write/Edit guard (T-5205). On read it must
be well formed and append-only against its committed version; otherwise no ruling applies
and the reason says why. A row recorded under agent control never applies.

NO LEDGER → `active_ruling` returns (None, "") and every caller behaves as before.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import secrets
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

RULINGS = ".context/reviews/recorded-rulings.jsonl"
LEDGER_BASENAME = "recorded-rulings.jsonl"
RULING_CLASSES = ("act-in-the-world", "operator-marked")
NEVER_CLASSES = ("tier0-or-bypass", "sovereignty-field")
ID_RE = re.compile(r"^RL-[0-9a-f]{8}$")
_DIGEST_RE = re.compile(r"^[0-9a-f]{12}$")
_TASK_RE = re.compile(r"^T-\d+$")
FIELDS = ("ts", "id", "task", "ac", "ac_digest", "ruling", "ref", "by")
MAX_LEN = 2000


class Refused(ValueError):
    pass


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _under_agent_control() -> bool:
    return os.environ.get("CLAUDECODE") == "1" or bool(os.environ.get("AI_AGENT", "").strip())


def _digest(crit) -> str:
    from lib.verdict_ledger import criterion_digest  # noqa: PLC0415 — verdict_ledger imports us
    return criterion_digest(crit)


def _row_problem(r) -> str:
    if not isinstance(r, dict):
        return "not an object"
    missing = [k for k in FIELDS if k not in r]
    if missing:
        return f"missing {', '.join(missing)}"
    if not ID_RE.match(str(r["id"])):
        return f"bad id {r['id']!r}"
    if not _TASK_RE.match(str(r["task"])):
        return f"bad task {r['task']!r}"
    if not isinstance(r["ac"], int) or isinstance(r["ac"], bool) or r["ac"] < 1:
        return f"bad ac {r['ac']!r}"
    if not _DIGEST_RE.match(str(r["ac_digest"])):
        return f"bad digest {r['ac_digest']!r}"
    for k in ("ruling", "ref", "by"):
        if not isinstance(r[k], str) or not r[k].strip():
            return f"empty {k}"
    return ""


def _committed(root: Path) -> str | None:
    """The ledger as committed at HEAD; None when it is not tracked (or no git)."""
    try:
        p = subprocess.run(["git", "-C", str(root), "show", f"HEAD:{RULINGS}"],
                           capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    return p.stdout if p.returncode == 0 else None


def load(root: Path) -> tuple[list[dict], str]:
    """(rows, problem). A non-empty problem means the ledger refuses as a whole: a malformed
    or duplicated row, or committed history that the working file does not extend."""
    p = Path(root) / RULINGS
    if not p.is_file():
        return [], ""
    text = p.read_text(encoding="utf-8", errors="replace")
    committed = _committed(Path(root))
    if committed is not None and not text.startswith(committed):
        return [], f"{RULINGS} is not append-only against its committed version"
    rows, seen = [], set()
    for n, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            return [], f"{RULINGS} line {n} is not JSON"
        why = _row_problem(r)
        if why:
            return [], f"{RULINGS} line {n}: {why}"
        if r["id"] in seen:
            return [], f"{RULINGS} line {n}: duplicate id {r['id']}"
        seen.add(r["id"])
        rows.append(r)
    return rows, ""


def active_ruling(root: Path, task_id: str, criterion, cls: str) -> tuple[dict | None, str]:
    """(row, "") when a valid recorded ruling lifts `criterion` (of class `cls`) to
    reviewer-judged, else (None, why not). (None, "") when no ruling names this criterion."""
    if not (Path(root) / RULINGS).is_file():
        return None, ""
    rows, problem = load(root)
    if problem:
        return None, f"recorded rulings refused: {problem}"
    mine = [r for r in rows if r["task"] == task_id and r["ac"] == criterion.index]
    if not mine:
        return None, ""
    if cls not in RULING_CLASSES:
        return None, (f"{mine[-1]['id']} is recorded, but a {cls} criterion stays with the "
                      f"operator whatever is recorded (only {', '.join(RULING_CLASSES)})")
    digest = _digest(criterion)
    why = []
    for r in reversed(mine):
        if r["by"] == "agent-override":
            why.append(f"{r['id']} was recorded under agent control and never applies")
        elif r["ac_digest"] != digest:
            why.append(f"{r['id']} was recorded for digest {r['ac_digest']}; the criterion "
                       f"now reads {digest} (edited since), so the ruling no longer applies")
        else:
            return r, ""
    return None, "; ".join(why)


def as_widening(r: dict) -> dict:
    """The row in the shape the widening consumers read (id, ruling, kind)."""
    return {**r, "kind": "ruling", "ruling_text": r["ruling"]}


def note(r: dict) -> str:
    return f"ruling recorded ({r['id']})"


# ── the operator's verb ──────────────────────────────────────────────────────

def _find_task(root: Path, task_id: str) -> Path | None:
    hits = sorted((root / ".tasks" / "active").glob(f"{task_id}-*.md")) + \
        sorted((root / ".tasks" / "active").glob(f"{task_id}.md"))
    return hits[0] if hits else None


def record(root: Path, task_id: str, ac: int, ruling: str, ref: str, *,
           dry_run: bool = False) -> dict:
    """Validate and append one ruling row. Refused under agent control, always."""
    from lib.delegation import classify, frontmatter, human_criteria  # noqa: PLC0415
    if not dry_run and _under_agent_control():
        raise Refused("recording a ruling is the operator's act (T-5235); it is refused under "
                      "agent control (CLAUDECODE / AI_AGENT), --i-am-human included. An agent may "
                      "only --dry-run. Operator: run it in your own terminal")
    ruling, ref = (ruling or "").strip(), (ref or "").strip()
    if not ruling or not ref:
        raise Refused("--ruling and --ref are both required (the ruling verbatim, and where it "
                      "was given)")
    if len(ruling) > MAX_LEN or len(ref) > MAX_LEN:
        raise Refused(f"--ruling / --ref longer than {MAX_LEN} characters")
    path = _find_task(root, task_id)
    if path is None:
        raise Refused(f"{task_id} is not an active task")
    text = path.read_text(encoding="utf-8", errors="replace")
    crit = next((c for c in human_criteria(text) if c.index == ac), None)
    if crit is None:
        raise Refused(f"{task_id} has no Human criterion {ac}")
    cl = classify(crit, workflow_type=str(frontmatter(text).get("workflow_type") or ""))
    if cl.cls in NEVER_CLASSES or cl.cls not in RULING_CLASSES:
        raise Refused(f"{task_id} Human AC#{ac} is {cl.cls}: a recorded ruling lifts only "
                      f"{', '.join(RULING_CLASSES)} criteria" +
                      (" — this one stays with the operator" if cl.cls in NEVER_CLASSES else
                       " — this one is not operator-only, nothing to lift"))
    _rows, problem = load(root)
    if problem:
        raise Refused(f"the ruling ledger refuses: {problem}")
    row = {"ts": _now(), "id": f"RL-{secrets.token_hex(4)}", "task": task_id, "ac": ac,
           "ac_digest": _digest(crit), "criterion": crit.title.strip()[:200],
           "ruling": ruling, "ref": ref, "by": os.environ.get("USER") or "operator"}
    if dry_run:
        return {**row, "dry_run": True}
    p = root / RULINGS
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, sort_keys=True) + "\n")
    return row


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw reviewer ruling",
                                 description="record the operator's ruling on a Human criterion "
                                             "(T-5235)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    rc = sub.add_parser("record", help="record a ruling (operator only)")
    rc.add_argument("task_id")
    rc.add_argument("--ac", type=int, required=True, help="Human criterion number")
    rc.add_argument("--ruling", required=True, help="the ruling, verbatim")
    rc.add_argument("--ref", required=True, help="where the ruling was given")
    rc.add_argument("--dry-run", action="store_true")
    rc.add_argument("--i-am-human", action="store_true",
                    help="accepted and ignored: it does not open this verb under agent control")
    ls = sub.add_parser("list", help="recorded rulings")
    ls.add_argument("--task")
    ls.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    try:
        if a.cmd == "list":
            rows, problem = load(root)
            if problem:
                print(f"REFUSED: {problem}", file=sys.stderr)
                return 2
            rows = [r for r in rows if not a.task or r["task"] == a.task]
            if a.json:
                print(json.dumps(rows, indent=2))
            else:
                for r in rows:
                    print(f"{r['id']}  {r['task']} AC#{r['ac']} digest {r['ac_digest']}  "
                          f"by {r['by']}  ref: {r['ref']}")
                    print(f"  ruling: {r['ruling']}")
                print(f"{len(rows)} recorded ruling(s).")
            return 0
        row = record(root, a.task_id, a.ac, a.ruling, a.ref, dry_run=a.dry_run)
        if a.dry_run:
            print(f"DRY RUN: would record {a.task_id} AC#{a.ac} digest {row['ac_digest']}: "
                  f"nothing written")
            return 0
        print(f"Recorded {row['id']}: {a.task_id} AC#{a.ac} (digest {row['ac_digest']}) in "
              f"{RULINGS}")
        print(f"Next: commit {RULINGS}; then fw reviewer judge {a.task_id}")
        return 0
    except Refused as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
