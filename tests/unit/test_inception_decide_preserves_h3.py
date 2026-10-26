"""T-1526 regression: do_inception_decide rewriter must not swallow `### timestamp`
H3 entries living between `## Decision` and EOF.

Bug context: lib/inception.sh:431-453 ran a line-by-line rewrite of the
`## Decision` section. The state machine only exited `in_decision` on
`line.startswith('## ')` (H2). update-task.sh appends `### timestamp` Updates
entries at EOF; if a task lacks a trailing `## Updates` H2, those H3s sat
between the Decision block and EOF, so they were swallowed on the next
decide call. Same shape as T-1519 (verdict regex). Fix: terminate at any
H2-or-deeper heading.

T-4380: these tests run the SHIPPED python heredoc (PYDECIDE), cut out of
lib/inception.sh and executed on a fixture task file. They used to run a mirror
of it written out in the test, which stayed green when the shipped terminator was
changed back to the pre-fix H2-only check.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

INCEPTION_SH = Path(__file__).resolve().parents[2] / "lib" / "inception.sh"


def _shipped_pydecide() -> str:
    src = INCEPTION_SH.read_text()
    m = re.search(r"<< 'PYDECIDE'\n(.*?)\nPYDECIDE\n", src, re.S)
    assert m, "PYDECIDE heredoc not found in lib/inception.sh - did it move?"
    code = m.group(1)
    assert "## Decision" in code
    return code


def _shell_invocation_argc() -> int:
    """Count the positional args lib/inception.sh passes to the PYDECIDE heredoc."""
    src = INCEPTION_SH.read_text()
    m = re.search(r"^\s*python3 - (.*?) << 'PYDECIDE'$", src, re.M)
    assert m, "PYDECIDE invocation line not found in lib/inception.sh"
    return len(re.findall(r'"[^"]*"', m.group(1)))


def _rewrite_decision(tmp_path, content: str, decision: str, rationale: str,
                      timestamp: str, diverges: str = "") -> str:
    """Run lib/inception.sh's PYDECIDE block on a task file holding `content`.

    T-4760: argv mirrors the shell call (T-4727 added `$_diverges`, always passed,
    empty when the verb matches the Recommendation).
    """
    task = tmp_path / "T-9999-fixture.md"
    task.write_text(content)
    script = tmp_path / "pydecide.py"
    script.write_text(_shipped_pydecide())
    subprocess.run(
        ["python3", str(script), str(task), decision, rationale, timestamp, diverges],
        check=True, capture_output=True, text=True,
    )
    return task.read_text()


def test_harness_argv_matches_shell_invocation():
    """T-4760: the harness must pass as many args as the shipped call does."""
    assert _shell_invocation_argc() == 5, (
        "lib/inception.sh changed the PYDECIDE call signature - update "
        "_rewrite_decision to pass the same args"
    )


def test_diverges_line_written_and_h3_preserved(tmp_path):
    """T-4727 note survives alongside the T-1526 H3 contract."""
    body = (
        "## Decision\n**Decision**: OLD\n\n"
        "### 2026-04-26T00:00:00Z — task-update [agent]\n- keep me\n"
    )
    out = _rewrite_decision(tmp_path, body, "NO-GO", "r", "t", diverges="GO")
    assert out.count("**Diverges from Recommendation**: GO") == 1
    assert "**Decision**: NO-GO" in out and "OLD" not in out
    assert "- keep me" in out


def test_h3_below_decision_preserved_on_rewrite(tmp_path):
    """T-1526 core: an H3 entry below ## Decision must survive a re-decide."""
    body = (
        "## Recommendation\nGO\n\n"
        "## Decision\n**Decision**: OLD-DEFER\n**Rationale**: old\n\n"
        "### 2026-04-26T00:00:00Z — task-update [agent]\n"
        "- **Action:** important update entry\n"
    )
    out = _rewrite_decision(tmp_path, body, "GO", "new rationale", "2026-04-26T01:00:00Z")
    # New decision landed
    assert "**Decision**: GO" in out
    # Old decision collapsed
    assert "OLD-DEFER" not in out
    # Critical: H3 entry survived
    assert "### 2026-04-26T00:00:00Z" in out
    assert "important update entry" in out


def test_duplicate_decision_blocks_still_collapse(tmp_path):
    """Pre-existing T-1262 behavior: multiple ## Decision blocks collapse to one."""
    body = "## Decision\nold A\n\n## Decision\nold B\n\n## Updates\n- foo\n"
    out = _rewrite_decision(tmp_path, body, "GO", "r", "t")
    assert out.count("## Decision") == 1
    assert "## Updates" in out and "- foo" in out


def test_h2_termination_still_works(tmp_path):
    """Existing H2 terminator path still preserves following H2 sections."""
    body = "## Decision\nold\n\n## Updates\n- entry\n"
    out = _rewrite_decision(tmp_path, body, "NO-GO", "r", "t")
    assert "## Updates" in out
    assert "- entry" in out
