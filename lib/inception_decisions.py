#!/usr/bin/env python3
"""
T-1984: inception_decisions / unlocks_inception_decision frontmatter parser.

Two new optional frontmatter fields:

  inception_decisions: (list)           # on workflow_type: inception tasks
    Each entry: {id: <kebab-slug>, text: <one-liner>, ships_in: <referent>}
    ships_in accepts five shapes:
      1. path/to/file.ext              → file must exist at PROJECT_ROOT/<path>
      2. module.function               → symbol grepped in lib/ / agents/ / bin/
      3. tests/path/test.py::test_func → file exists + symbol in file
      4. T-XXX                         → task in .tasks/completed/
      5. deferred:T-YYYY               → task in .tasks/{active,completed}/

  unlocks_inception_decision: (list)    # on workflow_type: build tasks
    Each entry: "T-XXX:decision-id"
    Validates: inception T-XXX exists AND has a decision with that id.

Origin: T-1983 GO, T-1984 build — structural prevention for G-066.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import yaml

# ── Regex helpers ─────────────────────────────────────────────────────────────

_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_TASK_ID_RE = re.compile(r"^T-\d+$")
_DEFERRED_RE = re.compile(r"^deferred:T-\d+$")
_UNLOCK_REF_RE = re.compile(r"^(T-\d+):([a-z0-9][a-z0-9-]*)$")
_KEBAB_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")


# ── Data types ─────────────────────────────────────────────────────────────────


@dataclass
class InceptionDecision:
    id: str
    text: str
    ships_in: str


@dataclass
class ParseResult:
    decisions: list[InceptionDecision] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return len(self.errors) == 0


# ── Shape detection ───────────────────────────────────────────────────────────


def detect_shape(ships_in: str) -> str:
    """
    Return the ships_in shape identifier:
      'test'     → path::test_func
      'task'     → T-XXX
      'deferred' → deferred:T-YYYY
      'file'     → path/to/file.ext
      'module'   → module.function
      'unknown'  → unrecognized
    """
    if "::" in ships_in:
        return "test"
    if _TASK_ID_RE.match(ships_in):
        return "task"
    if _DEFERRED_RE.match(ships_in):
        return "deferred"
    if "/" in ships_in:
        return "file"
    if "." in ships_in and ships_in[0].isalpha():
        return "module"
    return "unknown"


# ── Frontmatter extraction ────────────────────────────────────────────────────


def extract_frontmatter(content: str) -> Optional[dict]:
    """Parse YAML frontmatter from task file content. Returns dict or None."""
    m = _FRONTMATTER_RE.search(content)
    if not m:
        return None
    try:
        fm = yaml.safe_load(m.group(1))
        return fm if isinstance(fm, dict) else None
    except yaml.YAMLError:
        return None


# ── inception_decisions parser ────────────────────────────────────────────────


def parse_inception_decisions(content: str) -> ParseResult:
    """
    Parse and structurally validate inception_decisions: from task content
    (full file text including frontmatter).

    Validates:
      - Each entry has id (kebab-case), text, ships_in
      - id is unique within the task
      - ships_in matches one of the 5 accepted shapes

    Does NOT check reachability (that's check_ships_in_reachable).
    """
    fm = extract_frontmatter(content)
    if fm is None:
        return ParseResult()

    raw = fm.get("inception_decisions")
    if not raw:
        return ParseResult()

    if not isinstance(raw, list):
        return ParseResult(errors=["inception_decisions: must be a YAML list"])

    result = ParseResult()
    seen_ids: set[str] = set()

    for i, entry in enumerate(raw):
        if not isinstance(entry, dict):
            result.errors.append(f"inception_decisions[{i}]: must be a mapping (id/text/ships_in)")
            continue

        eid = str(entry.get("id") or "").strip()
        text = str(entry.get("text") or "").strip()
        ships_in = str(entry.get("ships_in") or "").strip()

        if not eid:
            result.errors.append(f"inception_decisions[{i}]: missing 'id' field")
            continue

        if not _KEBAB_RE.match(eid):
            result.errors.append(
                f"inception_decisions[{i}] id '{eid}': "
                "must be kebab-case (lowercase alphanumeric + hyphens, no leading hyphen)"
            )

        if eid in seen_ids:
            result.errors.append(f"inception_decisions: duplicate id '{eid}'")
        seen_ids.add(eid)

        if not text:
            result.errors.append(f"inception_decisions id '{eid}': missing 'text' field")

        if not ships_in:
            result.errors.append(f"inception_decisions id '{eid}': missing 'ships_in' field")
        else:
            shape = detect_shape(ships_in)
            if shape == "unknown":
                result.errors.append(
                    f"inception_decisions id '{eid}': ships_in '{ships_in}' does not match "
                    "any of the 5 accepted shapes: "
                    "file path, module.function, path::test_func, T-XXX, deferred:T-YYYY"
                )

        result.decisions.append(InceptionDecision(id=eid, text=text, ships_in=ships_in))

    return result


# ── unlocks_inception_decision parser ─────────────────────────────────────────


def parse_unlocks_field(content: str) -> tuple[list[str], list[str]]:
    """
    Parse unlocks_inception_decision: from task content.
    Returns (entries, errors).
    """
    fm = extract_frontmatter(content)
    if fm is None:
        return [], []

    raw = fm.get("unlocks_inception_decision")
    if not raw:
        return [], []

    if not isinstance(raw, list):
        return [], ["unlocks_inception_decision: must be a YAML list"]

    entries = []
    errors = []
    for item in raw:
        s = str(item).strip()
        if not _UNLOCK_REF_RE.match(s):
            errors.append(
                f"unlocks_inception_decision entry '{s}' must match T-XXX:decision-id "
                "(e.g. T-1983:my-decision)"
            )
        else:
            entries.append(s)

    return entries, errors


# ── Reachability checks ───────────────────────────────────────────────────────


def check_ships_in_reachable(
    ships_in: str, decision_id: str, project_root: Path
) -> Optional[str]:
    """
    Verify that the ships_in referent is reachable.
    Returns an error string, or None if the referent is reachable.
    """
    shape = detect_shape(ships_in)

    if shape == "file":
        path = project_root / ships_in
        if not path.exists():
            return (
                f"decision '{decision_id}': ships_in file path '{ships_in}' "
                f"does not exist at {path}"
            )
        return None

    if shape == "test":
        file_part, func_part = ships_in.split("::", 1)
        fpath = project_root / file_part
        if not fpath.exists():
            return (
                f"decision '{decision_id}': ships_in test file '{file_part}' "
                f"does not exist"
            )
        try:
            if func_part not in fpath.read_text():
                return (
                    f"decision '{decision_id}': ships_in test function '{func_part}' "
                    f"not found in {file_part}"
                )
        except OSError as e:
            return f"decision '{decision_id}': cannot read {file_part}: {e}"
        return None

    if shape == "module":
        # Grep for symbol in lib/, agents/, bin/ source files
        symbol = ships_in.rsplit(".", 1)[-1]
        search_dirs = [
            project_root / "lib",
            project_root / "agents",
            project_root / "bin",
        ]
        extensions = {".py", ".sh", ".rb", ".js", ".ts"}
        for search_dir in search_dirs:
            if not search_dir.is_dir():
                continue
            for fpath in sorted(search_dir.rglob("*")):
                if not fpath.is_file():
                    continue
                if fpath.suffix not in extensions and fpath.name not in {"fw"}:
                    continue
                try:
                    if symbol in fpath.read_text():
                        return None
                except (OSError, UnicodeDecodeError):
                    continue
        return (
            f"decision '{decision_id}': ships_in module.function '{ships_in}' — "
            f"symbol '{symbol}' not found in lib/, agents/, or bin/"
        )

    if shape == "task":
        task_id = ships_in
        completed_dir = project_root / ".tasks" / "completed"
        if not completed_dir.is_dir():
            return (
                f"decision '{decision_id}': ships_in task '{task_id}' — "
                f".tasks/completed/ not found"
            )
        if not list(completed_dir.glob(f"{task_id}-*.md")):
            return (
                f"decision '{decision_id}': ships_in task '{task_id}' is not in "
                f".tasks/completed/ (task must be work-completed before inception closes)"
            )
        return None

    if shape == "deferred":
        target_id = ships_in[len("deferred:"):]
        tasks_dir = project_root / ".tasks"
        for subdir in ("active", "completed"):
            sub = tasks_dir / subdir
            if sub.is_dir() and list(sub.glob(f"{target_id}-*.md")):
                return None
        return (
            f"decision '{decision_id}': deferred target '{target_id}' does not "
            f"exist in .tasks/{{active,completed}}/"
        )

    return f"decision '{decision_id}': ships_in '{ships_in}' has unrecognized shape"


def validate_unlocks_references(
    entries: list[str], project_root: Path
) -> list[str]:
    """
    Validate each T-XXX:decision-id reference in unlocks_inception_decision:.
    Returns a list of error strings (empty = all valid).
    """
    errors = []
    for ref in entries:
        m = _UNLOCK_REF_RE.match(ref)
        if not m:
            errors.append(f"unlocks_inception_decision '{ref}': malformed (expected T-XXX:id)")
            continue
        task_id, decision_id = m.group(1), m.group(2)

        # Find inception task
        task_file = None
        for subdir in ("active", "completed"):
            sub = project_root / ".tasks" / subdir
            if sub.is_dir():
                matches = list(sub.glob(f"{task_id}-*.md"))
                if matches:
                    task_file = matches[0]
                    break
        if task_file is None:
            errors.append(
                f"unlocks_inception_decision '{ref}': inception task {task_id} not found "
                f"in .tasks/{{active,completed}}/"
            )
            continue

        try:
            content = task_file.read_text()
        except OSError as e:
            errors.append(f"unlocks_inception_decision '{ref}': cannot read {task_file}: {e}")
            continue

        pr = parse_inception_decisions(content)
        known_ids = {d.id for d in pr.decisions}
        if decision_id not in known_ids:
            known_str = ", ".join(sorted(known_ids)) if known_ids else "(none)"
            errors.append(
                f"unlocks_inception_decision '{ref}': decision '{decision_id}' "
                f"not found in {task_id}'s inception_decisions: "
                f"(known: {known_str})"
            )

    return errors


# ── Block message formatter ───────────────────────────────────────────────────


def format_block_message(failures: list[str], task_id: str = "") -> str:
    """
    Format a user-readable block message listing all failing decisions/refs.
    Kept under 8 lines per T-1984 Human AC.
    """
    header = (
        f"INCEPTION-SCOPE-TRACE gate (T-1984, G-066): inception task {task_id} "
        f"has {len(failures)} unresolved decision(s):"
    )
    items = "\n".join(f"  - {f}" for f in failures)
    footer = (
        "To override (Tier-2 logged):\n"
        "  Direct invocation:  --skip-inception-scope-trace \"rationale\"\n"
        "  Indirect/git-hook:  FW_SKIP_INCEPTION_SCOPE_TRACE=1 <command>\n"
        "When to pick which: use --skip flag when calling fw task update directly;\n"
        "use env-var when the call goes through git commit or other wrappers."
    )
    return f"{header}\n{items}\n{footer}"


if __name__ == "__main__":
    # Quick smoke test
    sample = """---
id: T-9999
name: test
workflow_type: inception
inception_decisions:
  - id: my-decision
    text: "Do the thing"
    ships_in: lib/some_module.py
---
# body
"""
    result = parse_inception_decisions(sample)
    print("Decisions:", result.decisions)
    print("Errors:", result.errors)
    sys.exit(0 if result.ok else 1)
