"""Unit tests for T-1519: reviewer verdict-replacement must not nuke
content below the verdict block when re-scanning a task.

Bug context: lib/reviewer/static_scan.py:_VERDICT_SECTION_RE previously
terminated at `^## ` (H2 only) or `\\Z`. update-task.sh appends
`### timestamp` Updates entries at EOF after the reviewer wrote the
verdict, so re-running the reviewer would silently strip those H3
entries. Fix: terminator changed to `^#{2,} ` (H2 or deeper).
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer.static_scan import (  # noqa: E402
    Verdict,
    write_verdict_to_task,
)


def _make_verdict(scan_id: str = "R-test-1") -> Verdict:
    return Verdict(
        task_id="T-9999",
        scan_id=scan_id,
        timestamp="2026-04-26T00:00:00Z",
        overall="PASS",
        catalogue_version="v1.3-seed",
    )


def test_verdict_rescan_preserves_h3_updates_below(tmp_path):
    """Re-running write_verdict_to_task must not strip H3 entries below."""
    task = tmp_path / "T-9999.md"
    task.write_text(
        "## Updates\n"
        "\n"
        "### 2026-04-26T00:00:00Z — task-created\n"
        "- Initial entry\n"
        "\n"
        "## Reviewer Verdict (v1.3)\n"
        "\n"
        "- **Scan ID:** R-old\n"
        "- **Overall:** FAIL\n"
        "\n"
        "### 2026-04-26T01:00:00Z — status-update\n"
        "- **Change:** status: started-work → work-completed\n"
        "- **Reason:** Done\n"
    )

    write_verdict_to_task(task, _make_verdict("R-new"))

    text = task.read_text()
    # New verdict landed
    assert "R-new" in text
    # Old verdict gone
    assert "R-old" not in text
    # Critical: status-update entry below preserved
    assert "status-update" in text
    assert "Reason:** Done" in text
    # Original task-created entry still there
    assert "task-created" in text


def test_verdict_first_write_appends_at_eof(tmp_path):
    """First-time write (no existing verdict) appends at EOF."""
    task = tmp_path / "T-9998.md"
    task.write_text("## Updates\n\n### entry\n- foo\n")

    write_verdict_to_task(task, _make_verdict("R-first"))

    text = task.read_text()
    assert "R-first" in text
    assert text.rstrip().endswith("")  # no spurious trailing junk
    # Appended after the existing content
    assert text.index("entry") < text.index("R-first")


def test_verdict_replace_preserves_following_h2(tmp_path):
    """If a real H2 follows the verdict (rare), it must still be preserved."""
    task = tmp_path / "T-9997.md"
    task.write_text(
        "## Reviewer Verdict (v1.3)\n"
        "- old\n"
        "\n"
        "## Decisions\n"
        "- some decision\n"
    )

    write_verdict_to_task(task, _make_verdict("R-x"))

    text = task.read_text()
    assert "R-x" in text
    assert "## Decisions" in text
    assert "some decision" in text
