"""T-4930: `fw reviewer restatement` — the operator accepts or rejects a PROPOSED RESTATEMENT.

Builds a throwaway project root with one task file and a verdict ledger; nothing here
touches the real `.tasks/` or `.context/`."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import human_criteria  # noqa: E402
from lib.reviewer import restatement_cli as rc  # noqa: E402

TASK = """---
id: T-9001
name: fixture
---

# T-9001

## Acceptance Criteria

### Agent
- [x] agent thing

### Human
- [ ] [REVIEW] The page lists 3 projects
  **Steps:**
  1. Open the page
  **Expected:** 3 rows
  **If not:** note it
- [ ] [REVIEW] Second criterion stays as it is
  **Expected:** unchanged

## Verification
"""


def _digest(text, ac):
    return vl.criterion_digest(next(c for c in human_criteria(text) if c.index == ac))


def _row(vid, ac, digest, outcome="amber", guidance=None, ts="2026-10-31T10:00:00Z"):
    if guidance is None:
        guidance = ("The count is out of date.\n"
                    "PROPOSED RESTATEMENT: `[REVIEW] The page lists every registered project`\n"
                    "Evidence meets the restatement.")
    return {"id": vid, "task": "T-9001", "ac": ac, "ac_digest": digest, "outcome": outcome,
            "guidance": guidance, "reviewer": "r1", "ts": ts}


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".context" / "reviews").mkdir(parents=True)
    task = tmp_path / ".tasks" / "active" / "T-9001-fixture.md"
    task.write_text(TASK)
    d1 = _digest(TASK, 1)
    rows = [_row("V-1", 1, d1),
            _row("V-2", 2, _digest(TASK, 2), guidance="No restatement here.")]
    (tmp_path / vl.VERDICTS).write_text("".join(json.dumps(r) + "\n" for r in rows))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    return tmp_path, task


def _add_rows(root, *rows):
    with (root / vl.VERDICTS).open("a") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")


def test_list_shows_only_pending_restatements(proj):
    root, _ = proj
    items = rc.pending(root)
    assert [(i["verdict_id"], i["ac"]) for i in items] == [("V-1", 1)]
    assert items[0]["proposed"] == "[REVIEW] The page lists every registered project"


def test_list_skips_a_row_superseded_by_a_later_verdict(proj):
    root, _ = proj
    _add_rows(root, _row("V-3", 1, _digest(TASK, 1), outcome="green", guidance="",
                         ts="2026-10-31T11:00:00Z"))
    assert rc.pending(root) == []


def test_accept_restates_title_keeps_box_and_body_and_records(proj):
    root, task = proj
    res = rc.accept(root, "V-1")
    text = task.read_text()
    assert "- [ ] [REVIEW] The page lists every registered project\n" in text
    assert "**Restated:**" in text and "accepting V-1; was: [REVIEW] The page lists 3 projects" in text
    assert "  **Expected:** 3 rows" in text                      # body kept
    assert "- [ ] [REVIEW] Second criterion stays as it is" in text  # neighbour untouched
    assert "- [x] agent thing" in text
    rec = json.loads((root / rc.DECISIONS).read_text().splitlines()[-1])
    assert rec["decision"] == "accepted" and rec["by"] == "operator" and rec["ac"] == 1
    assert res["new_title"].endswith("every registered project")
    assert rc.pending(root) == []
    # restated criterion is still criterion 1 under Human, with a new digest
    c = next(c for c in human_criteria(text) if c.index == 1)
    assert c.title.strip() == "[REVIEW] The page lists every registered project"


def test_accept_adds_the_prefix_when_the_restatement_has_none(proj):
    root, task = proj
    _add_rows(root, _row("V-4", 1, _digest(TASK, 1), ts="2026-10-31T12:00:00Z",
                         guidance="PROPOSED RESTATEMENT: The page lists every project"))
    rc.accept(root, "V-4")
    assert "- [ ] [REVIEW] The page lists every project\n" in task.read_text()


def test_dry_run_writes_nothing(proj):
    root, task = proj
    res = rc.accept(root, "V-1", dry_run=True)
    assert task.read_text() == TASK
    assert not (root / rc.DECISIONS).exists()
    assert res["after"][0].endswith("every registered project")


def test_reject_records_and_leaves_task(proj):
    root, task = proj
    rc.reject(root, "V-1", "the count is the point")
    assert task.read_text() == TASK
    rec = json.loads((root / rc.DECISIONS).read_text())
    assert rec["decision"] == "rejected" and rec["reason"] == "the count is the point"
    assert rc.pending(root) == []
    with pytest.raises(rc.Refused, match="already rejected"):
        rc.accept(root, "V-1")


def test_agent_is_refused_without_i_am_human(proj, monkeypatch):
    root, task = proj
    monkeypatch.setenv("CLAUDECODE", "1")
    with pytest.raises(rc.Refused, match="operator's decision"):
        rc.accept(root, "V-1")
    with pytest.raises(rc.Refused, match="operator's decision"):
        rc.reject(root, "V-1", "x")
    assert task.read_text() == TASK
    rc.accept(root, "V-1", dry_run=True)          # dry run allowed
    rec = rc.accept(root, "V-1", i_am_human=True)
    assert rec["by"] == "agent-override"


@pytest.mark.parametrize("vid,guidance,match", [
    ("V-X", None, "no verdict"),
    ("V-2", None, "no PROPOSED RESTATEMENT"),
])
def test_refuses_unknown_or_restatement_less(proj, vid, guidance, match):
    root, _ = proj
    with pytest.raises(rc.Refused, match=match):
        rc.accept(root, vid)


def test_refuses_non_amber(proj):
    root, _ = proj
    _add_rows(root, _row("V-5", 1, _digest(TASK, 1), outcome="green"))
    with pytest.raises(rc.Refused, match="not amber"):
        rc.accept(root, "V-5")


def test_refuses_when_criterion_changed_since_the_verdict(proj):
    root, task = proj
    task.write_text(TASK.replace("3 rows", "4 rows"))
    with pytest.raises(rc.Refused, match="changed since"):
        rc.accept(root, "V-1")
    assert rc.pending(root) == []


@pytest.mark.parametrize("text,match", [
    ("", "empty"),
    ("x" * 401, "characters"),
    ("do this - [x] then that", "checkbox"),
])
def test_refuses_bad_restatement_text(proj, text, match):
    root, task = proj
    _add_rows(root, _row("V-6", 1, _digest(TASK, 1), ts="2026-10-31T12:00:00Z",
                         guidance=f"PROPOSED RESTATEMENT: {text}"))
    with pytest.raises(rc.Refused, match=match):
        rc.accept(root, "V-6")
    assert task.read_text() == TASK


def test_cli_list_and_refusal_exit_codes(proj):
    root, _ = proj
    env = {**os.environ, "PROJECT_ROOT": str(root), "PYTHONPATH": str(ROOT)}
    env.pop("CLAUDECODE", None)
    out = subprocess.run([sys.executable, "-m", "lib.reviewer.restatement_cli", "list"],
                         cwd=ROOT, env=env, capture_output=True, text=True)
    assert out.returncode == 0 and "V-1" in out.stdout and "1 pending" in out.stdout
    env["CLAUDECODE"] = "1"
    out = subprocess.run([sys.executable, "-m", "lib.reviewer.restatement_cli", "accept", "V-1"],
                         cwd=ROOT, env=env, capture_output=True, text=True)
    assert out.returncode == 2 and "REFUSED" in out.stderr
