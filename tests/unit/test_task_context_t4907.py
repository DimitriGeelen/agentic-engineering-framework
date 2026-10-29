"""T-4907: a task's ## Context must state Background / trigger, Problem / hypothesis,
Goal and Expected outcome in plain language (operator ruling 2026-10-29)."""

import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))

import task_context  # noqa: E402

FULL = """**Background / trigger:** 055 reported X on 2026-10-29 (msg abc).
**Problem / hypothesis:** the runner treats no files as no failures.
**Goal:** an empty run is never green.
**Expected outcome:** exit 3 and LATEST.yaml untouched."""


def task(context: str | None, workflow_type: str = "build") -> str:
    body = f"---\nid: T-1\nworkflow_type: {workflow_type}\n---\n# T-1\n\n"
    if context is not None:
        body += f"## Context\n\n{context}\n\n"
    return body + "## Acceptance Criteria\n\n- [ ] real\n"


def test_complete_context_passes():
    assert task_context.context_status_text(task(FULL)) == (True, [])


@pytest.mark.parametrize("label", ["Background / trigger", "Problem / hypothesis", "Goal", "Expected outcome"])
def test_each_missing_label_is_named(label):
    lines = [ln for ln in FULL.splitlines() if not ln.startswith(f"**{label}")]
    ok, missing = task_context.context_status_text(task("\n".join(lines)))
    assert not ok and missing == [label]


def test_placeholders_only_is_incomplete():
    tpl = "\n".join(f"**{d}:** <fill this in>" for d, _ in task_context.LABELS)
    ok, missing = task_context.context_status_text(task(tpl))
    assert not ok and len(missing) == 4


def test_html_comment_does_not_count():
    hidden = "<!--\n" + FULL + "\n-->"
    ok, missing = task_context.context_status_text(task(hidden))
    assert not ok and len(missing) == 4


def test_no_context_section_is_incomplete():
    ok, missing = task_context.context_status_text(task(None))
    assert not ok and len(missing) == 4


def test_inception_is_exempt():
    assert task_context.context_status_text(task(None, "inception")) == (True, [])


def test_text_on_following_lines_counts():
    multi = FULL.replace("**Goal:** an empty run is never green.", "**Goal:**\n- an empty run is never green")
    assert task_context.context_status_text(task(multi))[0]


def test_shipped_template_is_incomplete_until_filled():
    tpl = (REPO / ".tasks" / "templates" / "default.md").read_text()
    ok, missing = task_context.context_status_text(tpl)
    assert not ok and len(missing) == 4


def test_cli_exit_codes(tmp_path):
    good, bad = tmp_path / "good.md", tmp_path / "bad.md"
    good.write_text(task(FULL))
    bad.write_text(task("<!-- nothing -->"))
    cli = [sys.executable, "-I", str(REPO / "lib" / "task_context.py")]
    r = subprocess.run(cli + [str(good)], capture_output=True, text=True)
    assert r.returncode == 0 and r.stdout.strip() == "complete"
    r = subprocess.run(cli + [str(bad)], capture_output=True, text=True)
    assert r.returncode == 1 and r.stdout.startswith("missing: ")
