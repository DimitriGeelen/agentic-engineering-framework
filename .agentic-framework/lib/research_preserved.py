#!/usr/bin/env python3
"""Does a task file itself carry its research? (T-3569, C-001)

C-001 asks that inception research be persisted. The audit scanners used to
answer that by LOCATION only — a `docs/reports/` file named after the task, the
literal string `docs/reports/` in the body, or an episodic reference. A task
that wrote its research into its own Problem Statement / Findings / Dialogue
Log sections was reported as having none. 832 measured 3/3 of their live
completed-scan findings as that false positive (offer, offset 14).

This module is the one definition of "the task record itself preserves the
research". Both scanners import it (agents/audit/completed-task-scan.py and
agents/audit/active-task-scan.py); neither carries its own section list.

WHAT COUNTS
-----------
Prose under research-bearing `## ` headings (RESEARCH_SECTIONS), after HTML
comments and `[placeholder]` brackets are stripped and whitespace collapsed.
Everything else is excluded on purpose — Acceptance Criteria, Verification,
Updates, Recommendation, Decision(s), Go/No-Go: those sections are filled on
every task, research or not, so counting them would make coverage universal.

THE THRESHOLD
-------------
Calibrated on this repo's completed inceptions, not copied from 832's 400.
The numbers and the two boundary cases are recorded in T-3569 (## Decisions).
"""

from __future__ import annotations

import re
import sys

# Heading prefixes, lowercase. Prefix match so "Findings (spike 2)",
# "Hypotheses" and "Spike 1: ..." all count.
RESEARCH_SECTIONS = (
    "problem statement",
    "open questions",
    "exploration plan",
    "technical constraints",
    "hypothes",
    "findings",
    "evidence",
    "dialogue log",
    "scope fence",
    "spike",
    "prior art",
    "assumptions",
    # Not in 832's list; used by this corpus's inceptions for research prose
    # (T-3240 "Candidate Answers", "Investigation Findings"). T-3569.
    "candidate",
    "investigation",
)

# Minimum research prose, in characters after stripping. See module docstring.
THRESHOLD = 400

_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
# A `[placeholder]` bracket: not a checkbox's content we care about and not the
# text of a markdown link (which is followed by `(`). Single line only.
_PLACEHOLDER_RE = re.compile(r"\[[^\]\n]*\](?!\()")
_WS_RE = re.compile(r"\s+")


def _is_research_heading(title: str) -> bool:
    t = title.strip().lower().lstrip("0123456789. ")
    return any(t.startswith(p) for p in RESEARCH_SECTIONS)


def research_sections(text: str) -> dict[str, str]:
    """Map each research-bearing `## ` heading to its raw body."""
    out: dict[str, str] = {}
    current = None
    buf: list[str] = []
    in_fence = False
    for line in _COMMENT_RE.sub("", text).split("\n"):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        if not in_fence and line.startswith("## "):
            if current is not None:
                out[current] = out.get(current, "") + "\n".join(buf)
            title = line[3:].strip()
            current = title if _is_research_heading(title) else None
            buf = []
            continue
        if current is not None:
            buf.append(line)
    if current is not None:
        out[current] = out.get(current, "") + "\n".join(buf)
    return out


def _clean(body: str) -> str:
    body = _PLACEHOLDER_RE.sub("", body)
    return _WS_RE.sub(" ", body).strip()


def research_prose_chars(text: str) -> int:
    """Characters of research prose the task file carries (after stripping)."""
    return sum(len(_clean(b)) for b in research_sections(text).values())


def research_preserved(text: str, threshold: int = THRESHOLD) -> bool:
    """True when the task record itself preserves substantive research."""
    return research_prose_chars(text) >= threshold


if __name__ == "__main__":
    # Calibration aid: `python3 lib/research_preserved.py FILE...` prints
    # "<chars>\t<file>" per file.
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8", errors="replace") as fh:
            print(f"{research_prose_chars(fh.read())}\t{path}")
