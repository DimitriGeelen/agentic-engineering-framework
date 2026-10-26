"""T-4769: a Human tick licensed by a provenance row that is NOT committed.

The ledger budget is the working-tree file (unchanged), so the tick passes in the
checkout that wrote the row and FAILs everywhere else. The audit now says so on both
sides; the verdicts (rc) are pinned unchanged.
"""
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import human_ac_ticks as hat  # noqa: E402

TASK = "T-9769"
REL = f".tasks/active/{TASK}-fixture.md"
CRIT = "[REVIEW] Operator approves the thing"


def body(box):
    return (f"---\nid: {TASK}\nname: fixture\n---\n\n# {TASK}\n\n## Acceptance Criteria\n\n"
            f"### Agent\n- [x] agent thing\n\n### Human\n- [{box}] {CRIT}\n\n## Verification\n")


def git(root, *args):
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path):
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "op@example.com")
    git(tmp_path, "config", "user.name", "Operator")
    tf = tmp_path / REL
    tf.parent.mkdir(parents=True)
    tf.write_text(body(" "))
    git(tmp_path, "add", "-A")
    git(tmp_path, "commit", "-qm", f"{TASK}: create")
    tf.write_text(body("x"))
    git(tmp_path, "add", REL)
    git(tmp_path, "commit", "-qm", f"{TASK}: tick")
    return tmp_path


def add_row(root):
    hat.record(root, TASK, hat.criterion_key(CRIT), "operator-ack", "op")


def test_committed_row_passes_without_note(repo):
    add_row(repo)
    git(repo, "add", hat.LEDGER)
    git(repo, "commit", "-qm", f"{TASK}: ledger")
    rc, lines = hat.audit(repo, "2000-01-01")
    assert rc == 0, lines
    assert "UNCOMMITTED" not in lines[-1] and not any(ln.startswith("NOTE") for ln in lines)


def test_uncommitted_row_still_passes_here_but_names_the_commit_remedy(repo):
    add_row(repo)  # written, never committed
    rc, lines = hat.audit(repo, "2000-01-01")
    assert rc == 0, lines  # verdict unchanged: the working-tree row counts in this checkout
    assert "1 tick(s) licensed only by UNCOMMITTED rows" in lines[-1]
    assert f"commit {hat.LEDGER}" in lines[-1]
    assert any(ln.startswith(f"NOTE {TASK}") for ln in lines)


def test_no_row_fails_and_names_the_other_checkout_cause(repo):
    rc, lines = hat.audit(repo, "2000-01-01")
    assert rc == 2, lines
    fail = next(ln for ln in lines if ln.startswith("FAIL"))
    assert "no Watchtower/operator record" in fail
    assert f"Recorded in another checkout? A row counts only where it exists: commit {hat.LEDGER}" in fail
    assert "UNCOMMITTED" not in lines[-1]


def test_one_committed_row_does_not_cover_a_second_uncommitted_licence(repo):
    """Two ticks of the same criterion, one row committed, one only in the working tree:
    both pass here (budget 2), and exactly the second is named as uncommitted."""
    add_row(repo)
    git(repo, "add", hat.LEDGER)
    git(repo, "commit", "-qm", f"{TASK}: ledger")
    tf = repo / REL
    tf.write_text(body(" "))
    git(repo, "commit", "-qam", f"{TASK}: untick")
    tf.write_text(body("x"))
    git(repo, "commit", "-qam", f"{TASK}: re-tick")
    add_row(repo)
    rc, lines = hat.audit(repo, "2000-01-01")
    assert rc == 0, lines
    assert "1 tick(s) licensed only by UNCOMMITTED rows" in lines[-1]
