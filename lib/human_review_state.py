#!/usr/bin/env python3
"""Classify a task file's `### Human` AC blocks for the P-013 render gate.

Prints exactly one of: has_review, only_other, empty, no_section, error.

Extracted from the check_render_surface_human_ac heredoc in
agents/task-create/update-task.sh so the classification is testable and has a
single source of truth (T-3288, OBS-373).

Heading match history:
  - T-1901: scan ALL `### Human` blocks, not just the first — a template-stub
    block plus a real ACs block used to hide the real one.
  - T-3288: tolerate heading SUFFIXES — `### Human (Slice 1)` is a Human block.
    The prior `^### Human\\s*$` exact match saw only the empty stub and refused
    T-1719's close with "no [REVIEW] Human AC" while a valid one existed.
    `\\b` keeps lookalikes (`### HumanX`, `### Humanoid`) excluded.
"""
import re
import sys

HUMAN_BLOCK_RE = re.compile(
    r"^### Human\b[^\n]*$(.*?)(?=^#{2,} |\Z)", re.MULTILINE | re.DOTALL
)
REVIEW_AC_RE = re.compile(r"\s*-\s*\[[ x]\]\s*\[REVIEW\]")
ANY_AC_RE = re.compile(r"\s*-\s*\[[ x]\]")


def review_state(text):
    matches = list(HUMAN_BLOCK_RE.finditer(text))
    if not matches:
        return "no_section"
    human = "\n".join(m.group(1) for m in matches)
    human = re.sub(r"<!--.*?-->", "", human, flags=re.DOTALL)
    if any(REVIEW_AC_RE.match(l) for l in human.splitlines()):
        return "has_review"
    if any(ANY_AC_RE.match(l) for l in human.splitlines()):
        return "only_other"
    return "empty"


if __name__ == "__main__":
    try:
        text = open(sys.argv[1]).read()
    except (OSError, IndexError):
        print("error")
        sys.exit(0)
    print(review_state(text))
