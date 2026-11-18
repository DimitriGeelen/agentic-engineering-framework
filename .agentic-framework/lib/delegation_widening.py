#!/usr/bin/env python3
"""Operator-granted widening of reviewer delegation (T-5180, inception T-5171).

`lib/delegation.py` routes act-in-the-world criteria to OPERATOR-ONLY in every project.
A project's operator may rule otherwise for a stated scope: "the agent may close such a
step once it measured it (command + recorded output) and an independent reviewer passed
it" (010-termlink T-3800). This module is the ONE decision point for that ruling:
`active_widening` says whether a widening covers one criterion, and why not when it does
not. Every consumer (verdict_ledger record/apply, reviewer judge) asks it; none decides
on its own.

THE ROW. The operator records it through `human_ac_ticks.py delegation widen` (refused under
agent control unless --i-am-human) as `kind: widening` in the same append-only
`.context/reviews/standing-delegations.jsonl` that holds standing grants (T-4165). A
`revoke` row naming its id stops it. Fields: id (SD-xxxxxxxx), class (only
`act-in-the-world`), ruling (the project's ruling id), text (the ruling, verbatim),
pattern (regex on the criterion title), arc and/or tasks (scope), expires, by.

WHAT IT NEVER WIDENS. Only a criterion that `classify` puts in `act-in-the-world`. The
classes ahead of it — operator-marked, tier0-or-bypass, sovereignty-field — win first in
`classify`, so a criterion carrying any of their signals is never widened, whatever the
pattern says.

THE MEASURED BLOCK. A widened criterion closes only on measured evidence written in its
body (so it is inside the criterion digest the reviewer submits):

    **Measured:** `systemctl is-active foo.service`
    ```
    active
    ```

A `**Measured:**` line naming the command, then a fenced block (``` or ~~~) holding its
recorded output, closed, with at least one non-blank line. Without it the widening does
not apply.

NO WIDENING RECORDED → `active_widening` returns (None, "") and every caller behaves
exactly as before this module existed.
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

DELEGATIONS = ".context/reviews/standing-delegations.jsonl"
WIDENABLE_CLASSES = ("act-in-the-world",)
# T-5235: the classes a recorded operator ruling can lift (lib/recorded_ruling.py)
LIFTABLE_CLASSES = ("act-in-the-world", "operator-marked")
MEASURED_RE = re.compile(r"^\s*\*\*Measured:\*\*\s*(.*?)\s*$")
_FENCE_RE = re.compile(r"^\s*(```+|~~~+)")
MEASURED_FORMAT = ("a `**Measured:** <command>` line followed by a fenced block (```) "
                   "holding its recorded output")


def _rows(root: Path) -> list[dict]:
    p = Path(root) / DELEGATIONS
    out: list[dict] = []
    if not p.is_file():
        return out
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            r = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue
        if isinstance(r, dict):
            out.append(r)
    return out


def widenings(root: Path) -> dict[str, dict]:
    """{widening id: row + 'revoked' (ts or "")}, ledger order; a revoke for an unknown id is
    ignored. Grants (kind: grant) are not widenings and are never returned here."""
    out: dict[str, dict] = {}
    for r in _rows(root):
        wid = str(r.get("id") or "")
        if r.get("kind") == "widening" and wid and wid not in out:
            out[wid] = dict(r, revoked="")
        elif r.get("kind") == "revoke" and wid in out and not out[wid]["revoked"]:
            out[wid]["revoked"] = str(r.get("ts") or "")
    return out


def measured_block(lines: list[str]) -> tuple[str, str] | None:
    """(command, recorded output) from the first valid Measured block in a criterion's lines,
    else None. The fence must open on the next non-blank line and be closed."""
    for i, ln in enumerate(lines):
        m = MEASURED_RE.match(ln)
        if not m:
            continue
        cmd = m.group(1).strip().strip("`").strip()
        if not cmd:
            continue
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j >= len(lines):
            continue
        f = _FENCE_RE.match(lines[j])
        if not f:
            continue
        fence = f.group(1)[0] * 3
        body: list[str] = []
        for k in range(j + 1, len(lines)):
            if lines[k].strip().startswith(fence):
                if any(b.strip() for b in body):
                    return cmd, "\n".join(body)
                break
            body.append(lines[k])
    return None



def _workflow(text: str) -> str:
    m = re.search(r"(?m)^workflow_type:\s*['\"]?([\w-]+)", text or "")
    return m.group(1) if m else ""


def active_widening(root: Path, task_id: str, task_text: str, criterion,
                    today: str | None = None) -> tuple[dict | None, str]:
    """(widening row, "") when an operator widening makes `criterion` reviewer-judgeable,
    else (None, why not). (None, "") when the project records no widening at all — the
    caller's behaviour must then be exactly what it was before widening existed.

    T-5235: a recorded operator ruling (lib/recorded_ruling.py) is asked FIRST. It lifts an
    act-in-the-world or operator-marked criterion whose digest it was recorded for; the row
    comes back in widening shape (`kind: ruling`, id RL-…) and needs no Measured block."""
    try:
        from lib import recorded_ruling  # noqa: PLC0415
        from lib.delegation import classify  # noqa: PLC0415
    except ImportError:
        import sys  # noqa: PLC0415
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        from lib import recorded_ruling  # noqa: PLC0415
        from lib.delegation import classify  # noqa: PLC0415
    ruled, rwhy = None, ""
    if (Path(root) / recorded_ruling.RULINGS).is_file():
        rcls = classify(criterion, workflow_type=_workflow(task_text)).cls
        ruled, rwhy = recorded_ruling.active_ruling(root, task_id, criterion, rcls)
        if ruled is not None:
            return recorded_ruling.as_widening(ruled), ""
    ws = widenings(root)
    if not ws:
        return None, rwhy
    cls = classify(criterion, workflow_type=_workflow(task_text)).cls
    if cls not in WIDENABLE_CLASSES:
        return None, (f"criterion class {cls} is never widened (only {', '.join(WIDENABLE_CLASSES)})"
                      + (f"; {rwhy}" if rwhy else ""))
    today = today or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    title = re.sub(r"\s+", " ", criterion.title).strip()
    why: list[str] = []
    hit = None
    for wid, w in ws.items():
        if w.get("class") not in WIDENABLE_CLASSES:
            why.append(f"{wid} widens class {w.get('class')!r}, not {cls}")
            continue
        if w.get("revoked"):
            why.append(f"{wid} revoked {w['revoked']}")
            continue
        if str(w.get("expires") or "") < today:
            why.append(f"{wid} expired {w.get('expires')}")
            continue
        if w.get("by") == "agent-override":
            # T-5180 review #1: T-5171's GO says the ruling is operator-authored, never an agent's.
            why.append(f"{wid} was recorded under agent control (by: agent-override) and never applies")
            continue
        scope = w.get("tasks")
        if not isinstance(scope, list) or task_id not in scope:
            # T-5180 review #2/#6: task-list scope only. A task's arc_id/tags are agent-editable
            # and outside the digest, so an arc scope could be pulled onto any task.
            why.append(f"{task_id} is outside {wid}'s task list")
            continue
        pat = str(w.get("pattern") or "")
        try:
            if not pat or re.search(pat, "") or not re.search(pat, title):
                why.append(f"criterion title does not match {wid}'s pattern {pat!r}")
                continue
        except re.error:
            why.append(f"{wid}'s pattern does not compile")
            continue
        hit = w
        break
    if rwhy:
        why.insert(0, rwhy)
    if hit is None:
        return None, "no active widening covers it: " + "; ".join(why)
    if measured_block(list(criterion.lines)) is None:
        return None, (f"{hit['id']} (ruling {hit.get('ruling')}) covers it, but the criterion has "
                      f"no Measured block — add {MEASURED_FORMAT}")
    return hit, ""


def widened_note(w: dict) -> str:
    """The phrase every widened tick and verdict carries (T-5235: a recorded ruling's own)."""
    if w.get("kind") == "ruling":
        return f"ruling recorded ({w['id']})"
    return f"widened by {w['id']} (ruling {w.get('ruling')})"
