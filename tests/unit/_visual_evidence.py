"""T-4214 test helper: the T-4202 visual evidence a render criterion's review run must carry.

A render green needs (a) a screenshot per checklist state at every configured width, each cited
as evidence, and (b) a Visual Verification checklist that passes. `write_shots` makes the shots
and the run's `visual` record; `add_checklist` also writes the checklist into the task file and
the shots at the convention path, for tests that go through `fw reviewer judge`.
"""
from __future__ import annotations

from pathlib import Path

from lib import verdict_ledger as vl  # noqa: E402

WIDTHS = (1024, 1440, 1920)

CHECKLIST = (
    "\n## Visual Verification\n\n"
    "| state | control | 1024 | 1440 | 1920 | note |\n"
    "|-------|---------|------|------|------|------|\n"
    "| {state} | Load | ok | ok | ok | |\n"
)


def write_shots(root: Path, prefix: str, state: str = "page", widths=WIDTHS) -> list[dict]:
    """Shots at `<root>/<prefix>-<state>@<w>.png`. Returns [{state, width, path, sha256}]."""
    out = []
    for w in widths:
        f = root / f"{prefix}-{state}@{w}.png"
        f.write_bytes(b"vis-" + str(w).encode() + prefix.encode())
        out.append({"state": state, "width": w, "path": f.name, "sha256": vl._hash_path(f)})
    return out


def run_visual(shots: list[dict], widths=WIDTHS) -> dict:
    """The `visual` argument of `register_run` for a passing checklist over `shots`."""
    return {"widths": list(widths), "problems": [], "shots": shots}


def add_checklist(task_file: Path, root: Path, task: str, state: str = "page") -> None:
    """Judge path: append a passing checklist to the task file and write the shots where
    `fw ux shots` writes them (`.context/visual/<task>/<state>@<w>.png`)."""
    task_file.write_text(task_file.read_text() + CHECKLIST.format(state=state))
    d = root / ".context" / "visual" / task
    d.mkdir(parents=True, exist_ok=True)
    for w in WIDTHS:
        (d / f"{state}@{w}.png").write_bytes(b"vis-" + str(w).encode())
