#!/usr/bin/env python3
"""Validate a task's `## Visual Verification` checklist for a render-surface commit (T-4213).

T-4202 GO: a render-surface change is screenshotted at >=3 widths per touched state,
and each control is read per width. The checklist is the record of that reading:

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load    | ok   | ok   | ok   |      |
    | toolbar | Save    | clipped | clipped | ok | Save cut off below 1440 |

Checks (all must pass; each failure is one line on stderr):
  1. the section exists, and has a checklist table with a `state` and `control` column
  2. the width columns equal the configured UX_SHOT_WIDTHS (so every width is read)
  3. no blank cell; every cell is one of ok / clipped / hidden / overlap / unreachable
  4. a non-ok cell has a note in the trailing `note` column
  5. every listed state has >=3 configured widths of screenshots at
     .context/visual/<task>/<state>@<width>.png

HTML comments are ignored, so the template's inert example never counts.

Usage: visual_checklist.py --task-file F --root DIR --task T-NNNN --widths "1024,1440,1920"
Exit: 0 pass, 1 refused (reasons on stderr), 2 usage/config error.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ux-review"))
from ux_shots import MIN_WIDTHS, PlanError, parse_widths  # noqa: E402

VALID_CELLS = ("ok", "clipped", "hidden", "overlap", "unreachable")
HEADING = re.compile(r"^## Visual Verification\s*$")
NEXT_HEADING = re.compile(r"^## ")
COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)


def section_body(text: str) -> str | None:
    """Body of `## Visual Verification` up to the next `## ` heading, comments removed."""
    lines = text.splitlines()
    start = next((i for i, ln in enumerate(lines) if HEADING.match(ln)), None)
    if start is None:
        return None
    body: list[str] = []
    for ln in lines[start + 1:]:
        if NEXT_HEADING.match(ln):
            break
        body.append(ln)
    return COMMENT.sub("", "\n".join(body))


def _cells(line: str) -> list[str]:
    inner = line.strip()
    if inner.startswith("|"):
        inner = inner[1:]
    if inner.endswith("|"):
        inner = inner[:-1]
    return [c.strip() for c in inner.split("|")]


def parse_table(body: str):
    """Return (header, rows) for the first pipe table whose header has state + control, else (None, [])."""
    table: list[str] = []
    for ln in body.splitlines():
        if ln.strip().startswith("|"):
            table.append(ln)
        elif table:
            break
    if len(table) < 2:
        return None, []
    header = [h.lower() for h in _cells(table[0])]
    if "state" not in header or "control" not in header:
        return None, []
    rows = []
    for ln in table[1:]:
        cells = _cells(ln)
        if cells and all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue  # separator row
        rows.append(cells)
    return header, rows


def check(task_file: Path, root: Path, task: str, widths: list[int]) -> list[str]:
    problems: list[str] = []
    text = task_file.read_text(encoding="utf-8")
    body = section_body(text)
    if body is None:
        return ["no `## Visual Verification` section in the task file"]

    header, rows = parse_table(body)
    if header is None:
        return ["`## Visual Verification` has no checklist table with `state` and `control` columns "
                "(| state | control | 1024 | 1440 | 1920 | note |)"]

    width_cols = {int(h): i for i, h in enumerate(header) if h.isdigit()}
    if sorted(width_cols) != sorted(widths):
        problems.append(
            f"checklist width columns {sorted(width_cols)} must equal UX_SHOT_WIDTHS {sorted(widths)}"
        )
    note_idx = header.index("note") if "note" in header else None

    states: list[str] = []
    for cells in rows:
        if not cells or not cells[0]:
            continue
        state = cells[0]
        control = cells[header.index("control")] if header.index("control") < len(cells) else ""
        if state not in states:
            states.append(state)
        note = cells[note_idx] if note_idx is not None and note_idx < len(cells) else ""
        for w, col in sorted(width_cols.items()):
            val = cells[col].lower() if col < len(cells) else ""
            where = f"{state} / {control or '?'} @ {w}"
            if not val:
                problems.append(f"blank cell: {where}")
            elif val not in VALID_CELLS:
                problems.append(f"cell {val!r} is not one of {'/'.join(VALID_CELLS)}: {where}")
            elif val != "ok" and not note:
                problems.append(f"non-ok cell '{val}' without a note in the `note` column: {where}")

    for state in states:
        present = []
        for w in sorted(widths):
            if (root / ".context" / "visual" / task / f"{state}@{w}.png").is_file():
                present.append(w)
        if len(present) < MIN_WIDTHS:
            missing = [w for w in sorted(widths) if w not in present]
            problems.append(
                f"state '{state}': {len(present)} width(s) of screenshots in .context/visual/{task}/, "
                f"need {MIN_WIDTHS} (missing {missing}); run `fw ux shots {task} {state}=<URL>`"
            )
    if not states:
        problems.append("checklist table has no rows")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Visual Verification checklist gate (T-4213)")
    ap.add_argument("--task-file", required=True)
    ap.add_argument("--root", default=os.environ.get("PROJECT_ROOT") or os.getcwd())
    ap.add_argument("--task", required=True)
    ap.add_argument("--widths", default=None, help="UX_SHOT_WIDTHS value; default T-4202 trio")
    args = ap.parse_args(argv)
    try:
        widths = parse_widths(args.widths)
    except PlanError as exc:
        print(f"visual checklist: {exc}", file=sys.stderr)
        return 2
    task_file = Path(args.task_file)
    if not task_file.is_file():
        print(f"visual checklist: task file not found: {task_file}", file=sys.stderr)
        return 2
    problems = check(task_file, Path(args.root), args.task, widths)
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
