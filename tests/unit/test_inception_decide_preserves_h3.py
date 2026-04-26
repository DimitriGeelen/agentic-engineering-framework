"""T-1526 regression: do_inception_decide rewriter must not swallow `### timestamp`
H3 entries living between `## Decision` and EOF.

Bug context: lib/inception.sh:431-453 ran a line-by-line rewrite of the
`## Decision` section. The state machine only exited `in_decision` on
`line.startswith('## ')` (H2). update-task.sh appends `### timestamp` Updates
entries at EOF; if a task lacks a trailing `## Updates` H2, those H3s sat
between the Decision block and EOF, so they were swallowed on the next
decide call. Same shape as T-1519 (verdict regex). Fix: terminate at any
H2-or-deeper heading.

This test mirrors the python heredoc embedded in lib/inception.sh — keep
it in sync if that heredoc evolves.
"""

from __future__ import annotations

import re


def _rewrite_decision(content: str, decision: str, rationale: str, timestamp: str) -> str:
    """Mirror of lib/inception.sh:do_inception_decide PYDECIDE block."""
    lines = content.split("\n")
    new_lines: list[str] = []
    in_decision = False
    decision_written = False
    for line in lines:
        if line.strip() == "## Decision":
            in_decision = True
            if not decision_written:
                new_lines.append(line)
                new_lines.append("")
                new_lines.append(f"**Decision**: {decision}")
                new_lines.append("")
                new_lines.append(f"**Rationale**: {rationale}")
                new_lines.append("")
                new_lines.append(f"**Date**: {timestamp}")
                decision_written = True
            continue
        if in_decision:
            if re.match(r"^#{2,} ", line):  # T-1526: H2 or deeper
                in_decision = False
                new_lines.append("")
                new_lines.append(line)
            continue
        new_lines.append(line)
    return "\n".join(new_lines)


def test_h3_below_decision_preserved_on_rewrite():
    """T-1526 core: an H3 entry below ## Decision must survive a re-decide."""
    body = (
        "## Recommendation\nGO\n\n"
        "## Decision\n**Decision**: OLD-DEFER\n**Rationale**: old\n\n"
        "### 2026-04-26T00:00:00Z — task-update [agent]\n"
        "- **Action:** important update entry\n"
    )
    out = _rewrite_decision(body, "GO", "new rationale", "2026-04-26T01:00:00Z")
    # New decision landed
    assert "**Decision**: GO" in out
    # Old decision collapsed
    assert "OLD-DEFER" not in out
    # Critical: H3 entry survived
    assert "### 2026-04-26T00:00:00Z" in out
    assert "important update entry" in out


def test_duplicate_decision_blocks_still_collapse():
    """Pre-existing T-1262 behavior: multiple ## Decision blocks collapse to one."""
    body = "## Decision\nold A\n\n## Decision\nold B\n\n## Updates\n- foo\n"
    out = _rewrite_decision(body, "GO", "r", "t")
    assert out.count("## Decision") == 1
    assert "## Updates" in out and "- foo" in out


def test_h2_termination_still_works():
    """Existing H2 terminator path still preserves following H2 sections."""
    body = "## Decision\nold\n\n## Updates\n- entry\n"
    out = _rewrite_decision(body, "NO-GO", "r", "t")
    assert "## Updates" in out
    assert "- entry" in out
