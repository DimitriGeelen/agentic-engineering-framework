#!/usr/bin/env python3
"""T-4907: is a task's ``## Context`` written for a human?

Operator 2026-10-29: tasks did not say why they exist. The reason sat in a
one-line frontmatter ``description:`` and ``## Context`` was the template's
empty comment. The template now carries four labelled parts, and this module is
the one decision point for "are all four filled in":

  **Background / trigger:**   what happened, who reported it, evidence
  **Problem / hypothesis:**   what we think is wrong and why
  **Goal:**                   what we are trying to achieve
  **Expected outcome:**       what will be different when this is done

Readers: ``agents/context/check-active-task.sh`` (refuses source edits under a
task whose context is incomplete, beside G-020) and anything that wants the
same answer. Inception tasks are exempt: they carry their own Problem Statement.

Rules, kept deliberately small:
  - HTML comments are removed first, so template guidance never counts.
  - A label counts only at the start of a line (optionally after a ``- ``
    bullet), written bold with its colon: ``**Goal:**`` or ``**Goal**:``.
  - Its text runs from the label to the next line-start bold label or the end
    of the section. ``<…>`` placeholders are removed; what is left must contain
    at least one letter or digit.
  - No ``## Context`` section at all means all four parts are missing.

CLI: ``python3 lib/task_context.py <task-file>`` prints ``complete`` (exit 0) or
``missing: <labels>`` (exit 1). Exit 2 means the file could not be read.
"""

from __future__ import annotations

import re
import sys

#: Display names, in template order, and the lowercase prefix each one matches.
LABELS = (
    ("Background / trigger", "background"),
    ("Problem / hypothesis", "problem"),
    ("Goal", "goal"),
    ("Expected outcome", "expected outcome"),
)

_COMMENT = re.compile(r"<!--.*?-->", re.S)
_PLACEHOLDER = re.compile(r"<[^<>\n]*>")
# A bold label at line start: "**Goal:**", "**Goal**:", "- **Goal:**".
_LABEL_LINE = re.compile(r"^[ \t]*(?:[-*+][ \t]+)?\*\*([^*\n]+?)\*\*", re.M)
_FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)


def _workflow_type(text: str) -> str:
    m = _FRONTMATTER.match(text)
    if not m:
        return ""
    wt = re.search(r"^workflow_type:[ \t]*(\S*)", m.group(1), re.M)
    return wt.group(1).strip("'\"") if wt else ""


def _context_section(text: str) -> str | None:
    m = re.search(r"^## Context[ \t]*$", text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    nxt = re.search(r"^## ", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def _label_key(bold: str) -> str | None:
    name = bold.strip().rstrip(":").strip().lower()
    for display, prefix in LABELS:
        if name.startswith(prefix):
            return display
    return None


def _has_text(chunk: str) -> bool:
    return bool(re.search(r"[A-Za-z0-9]", _PLACEHOLDER.sub("", chunk)))


def context_status_text(text: str) -> tuple[bool, list[str]]:
    """Same as :func:`context_status`, on the file's text."""
    if _workflow_type(text) == "inception":
        return True, []
    section = _context_section(text)
    if section is None:
        return False, [d for d, _ in LABELS]
    section = _COMMENT.sub("", section)

    filled: dict[str, bool] = {}
    matches = list(_LABEL_LINE.finditer(section))
    for i, m in enumerate(matches):
        bold = m.group(1)
        end = matches[i + 1].start() if i + 1 < len(matches) else len(section)
        chunk = section[m.end():end]
        if not bold.rstrip().endswith(":"):
            # "**Goal**:" — the colon sits just outside the bold.
            if not chunk.startswith(":"):
                continue
            chunk = chunk[1:]
        key = _label_key(bold)
        if key is None:
            continue
        filled[key] = filled.get(key, False) or _has_text(chunk)

    missing = [d for d, _ in LABELS if not filled.get(d)]
    return not missing, missing


def context_status(task_path: str) -> tuple[bool, list[str]]:
    """Return ``(complete, missing_labels)`` for the task file at *task_path*."""
    with open(task_path, encoding="utf-8") as f:
        return context_status_text(f.read())


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: task_context.py <task-file>", file=sys.stderr)
        return 2
    try:
        complete, missing = context_status(argv[1])
    except OSError as exc:
        print(f"task_context: cannot read {argv[1]}: {exc}", file=sys.stderr)
        return 2
    if complete:
        print("complete")
        return 0
    print("missing: " + ", ".join(missing))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
