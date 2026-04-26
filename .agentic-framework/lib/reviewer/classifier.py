"""Verification-line classifier (T-1483 v1.5).

Classifies each line of a `## Verification` block into a safety category
so Pass B re-verification (worktree re-execution) can skip lines that
would touch shared state, network, or time-sensitive resources.

Categories (rank-ordered by re-execution risk):
    READ_ONLY         — safe to re-run anywhere, no side effects
    STATE_TOUCHING    — writes/mutates files; re-run only inside worktree
    NETWORK_DEPENDENT — needs network or local services; skip in Pass B
    TIME_DEPENDENT    — references date/sleep; results may differ across runs
    UNCLASSIFIED      — heuristics didn't fire; treat as STATE_TOUCHING

Origin: T-1482 Spike 1, 50-task sample → 50% read-only / 17.5% state /
20% network / 12.5% other. Patterns refined from the worst-case classifier.

Public API:
    Category (Enum)
    classify(line: str) -> Category
    classify_block(text: str) -> dict[Category, list[str]]
"""

from __future__ import annotations

import re
from enum import Enum


class Category(Enum):
    READ_ONLY = "read_only"
    STATE_TOUCHING = "state_touching"
    NETWORK_DEPENDENT = "network_dependent"
    TIME_DEPENDENT = "time_dependent"
    UNCLASSIFIED = "unclassified"


_NETWORK_PATTERNS = [
    re.compile(r"\bcurl\b"),
    re.compile(r"\bwget\b"),
    re.compile(r"\bnc\b\s"),
    re.compile(r"\bping\b"),
    re.compile(r"https?://"),
]

_TIME_PATTERNS = [
    re.compile(r"\$\(date\b"),
    re.compile(r"\bdate\s+\+"),
    re.compile(r"\bsleep\s+\d"),
]

_STATE_PATTERNS = [
    re.compile(r"\bfw\s+task\s+update\b"),
    re.compile(r"\bfw\s+work-on\b"),
    re.compile(r"\bfw\s+context\s+add"),
    re.compile(r"\bfw\s+inception\s+(start|decide)\b"),
    re.compile(r"\bfw\s+(audit|doctor|metrics|reviewer)\b"),
    # Redirect to a path that isn't /dev/null (which is a no-op sink, not state)
    re.compile(r">(?!\s*/dev/null\b)\s*\S"),
    re.compile(r">>(?!\s*/dev/null\b)\s*\S"),
    re.compile(r"\btee\b\s"),
    re.compile(r"\brm\b\s"),
    re.compile(r"\bmv\b\s"),
    re.compile(r"\bcp\b\s"),
    re.compile(r"\bgit\s+(commit|add|push|reset|checkout|merge|rebase|tag)\b"),
    re.compile(r"\bmkdir\b\s"),
    re.compile(r"\btouch\b\s"),
]

_READ_ONLY_PATTERNS = [
    re.compile(r"^\s*test\s+-[fdersxLkw]"),
    re.compile(r"^\s*\[\s+-[fdersxLkw]\s"),
    re.compile(r"^\s*grep\b"),
    re.compile(r"^\s*find\b"),
    re.compile(r"^\s*python3\s+-c\s+[\"']import\s+(yaml|json|os|sys|re|pathlib)"),
    re.compile(r"^\s*bash\s+-n\b"),
    re.compile(r"^\s*ls\s"),
    re.compile(r"^\s*cat\s"),
    re.compile(r"^\s*head\s"),
    re.compile(r"^\s*tail\s"),
    re.compile(r"^\s*wc\s"),
    re.compile(r"^\s*awk\b[^>]*$"),
    re.compile(r"^\s*sed\b[^>]*$"),
    re.compile(r"^\s*git\s+(log|status|diff|show|rev-parse|ls-files|branch|remote)\b"),
    re.compile(r"^\s*jq\b"),
    re.compile(r"^\s*pytest\b"),
    re.compile(r"^\s*bats\b"),
    re.compile(r"^\s*python3\s+-m\s+pytest\b"),
    re.compile(r"^\s*bin/fw\s+(version|help|list)\b"),
]


def classify(line: str) -> Category:
    """Classify a single verification line. Empty/comment lines → READ_ONLY (no-op)."""
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return Category.READ_ONLY

    # Order matters: most-restrictive checks win.
    for pat in _NETWORK_PATTERNS:
        if pat.search(stripped):
            return Category.NETWORK_DEPENDENT
    for pat in _TIME_PATTERNS:
        if pat.search(stripped):
            return Category.TIME_DEPENDENT
    for pat in _STATE_PATTERNS:
        if pat.search(stripped):
            return Category.STATE_TOUCHING
    for pat in _READ_ONLY_PATTERNS:
        if pat.search(stripped):
            return Category.READ_ONLY

    return Category.UNCLASSIFIED


def classify_block(text: str) -> dict[Category, list[str]]:
    """Classify every non-empty/non-comment line. Returns {category: [lines]}."""
    out: dict[Category, list[str]] = {c: [] for c in Category}
    if not text:
        return out
    for raw in text.splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        out[classify(raw)].append(raw)
    return out


def worst_case(text: str) -> Category:
    """Return the most-restrictive category present in the block.
    Order: NETWORK > TIME > STATE > UNCLASSIFIED > READ_ONLY.
    Used to decide whether a whole task is safe for Pass B execution.
    """
    by_cat = classify_block(text)
    for cat in (
        Category.NETWORK_DEPENDENT,
        Category.TIME_DEPENDENT,
        Category.STATE_TOUCHING,
        Category.UNCLASSIFIED,
        Category.READ_ONLY,
    ):
        if by_cat[cat]:
            return cat
    return Category.READ_ONLY
