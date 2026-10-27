"""T-4824 (upstream of 055's T-483): an unprovenanced ### Human tick that has since been
UN-ticked no longer fails the audit; a tick that still stands does.

Before: `human_ac_ticks.py audit` scanned history only, so once an agent's tick was undone
the old commit kept failing, and the only way out was the operator's `ack` of a tick they
did not make. The resolution is fail-closed: EVERY box carrying the criterion, in every
file of the task at the audited revision, must be unticked; a criterion that is gone or
renamed keeps its finding; if git cannot answer, the finding is kept.
"""
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import human_ac_ticks as hat  # noqa: E402

TID = "T-9824"
REL = f".tasks/active/{TID}-x.md"
DESIGN = "[REVIEW] The operator approves the design\n  **Steps:** look at it\n"
WORDING = "[REVIEW] The operator approves the wording\n  **Steps:** read it\n"


def body(a, b, design=DESIGN):
    return (f"---\nid: {TID}\n---\n## Acceptance Criteria\n### Agent\n- [x] built\n"
            f"### Human\n- [{a}] {design}- [{b}] {WORDING}## Verification\n")


def git(root, *args):
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


def commit(root, text, msg, rel=REL):
    f = root / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)
    git(root, "add", "-A")
    git(root, "commit", "-qm", msg)


@pytest.fixture
def repo(tmp_path):
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "agent@example.invalid")
    git(tmp_path, "config", "user.name", "Agent")
    commit(tmp_path, body(" ", " "), f"{TID}: created")
    return tmp_path


def audit(root):
    rc, lines = hat.audit(root, since="2000-01-01")
    return rc, [ln for ln in lines if ln.startswith("FAIL")], lines


def test_an_agent_tick_fails(repo):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    rc, fails, _ = audit(repo)
    assert (rc, len(fails)) == (2, 1)
    assert "approves the design" in fails[0]


def test_unticking_resolves_it(repo):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    commit(repo, body(" ", " "), f"{TID}: un-tick, the operator did not tick it")
    rc, fails, lines = audit(repo)
    assert (rc, fails) == (0, []), lines


def test_ticking_it_again_fails_again(repo):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    commit(repo, body(" ", " "), f"{TID}: un-tick")
    commit(repo, body("x", " "), f"{TID}: agent ticks it again")
    rc, fails, _ = audit(repo)
    assert rc == 2 and fails and all("approves the design" in f for f in fails)


def test_unticking_one_criterion_leaves_the_other_flagged(repo):
    commit(repo, body("x", "x"), f"{TID}: agent ticks both")
    commit(repo, body(" ", "x"), f"{TID}: un-tick only the design")
    rc, fails, _ = audit(repo)
    assert (rc, len(fails)) == (2, 1)
    assert "approves the wording" in fails[0]


def test_an_unticked_copy_does_not_hide_a_tick_that_stands(repo):
    # 055's review: judging the first matching box let an identical unticked copy ABOVE
    # the ticked one resolve the finding while the tick stood
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    text = (repo / REL).read_text()
    tick = "- [x] " + DESIGN
    assert tick in text
    commit(repo, text.replace(tick, "- [ ] " + DESIGN + tick), f"{TID}: unticked copy above")
    rc, fails, _ = audit(repo)
    assert rc == 2, "a tick that still stands must still fail"
    assert any("approves the design" in f for f in fails)


def test_untick_in_the_completed_file_counts_too(repo):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    (repo / REL).unlink()  # closing moves the file
    commit(repo, body(" ", " "), f"{TID}: closed and un-ticked",
           rel=f".tasks/completed/{TID}-x.md")
    assert audit(repo)[:2] == (0, [])


def test_a_tick_standing_in_another_file_of_the_task_keeps_the_finding(repo):
    # the scan reads every T-NNNN*.md under .tasks/; the un-tick must cover all of them
    commit(repo, body("x", " "), f"{TID}: tick in a second file of the task",
           rel=f".tasks/completed/{TID}-copy.md")
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    commit(repo, body(" ", " "), f"{TID}: un-tick in .tasks only")
    rc, fails, _ = audit(repo)
    assert rc == 2 and len(fails) == 2, fails


def test_a_renamed_criterion_keeps_its_finding(repo):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    renamed = DESIGN.replace("design", "layout")
    commit(repo, body(" ", " ", design=renamed), f"{TID}: rename and untick")
    rc, fails, _ = audit(repo)
    assert rc == 2 and len(fails) == 1 and "approves the design" in fails[0]


def test_a_removed_task_file_keeps_its_finding(repo):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    (repo / REL).unlink()
    git(repo, "add", "-A")
    git(repo, "commit", "-qm", f"{TID}: delete the file")
    assert audit(repo)[0] == 2


def test_git_failure_keeps_the_finding(repo, monkeypatch):
    commit(repo, body("x", " "), f"{TID}: agent ticks the design")
    commit(repo, body(" ", " "), f"{TID}: un-tick")
    real = hat._git

    def broken(root, *args):
        if args[:1] == ("ls-tree",):
            raise subprocess.CalledProcessError(128, ["git", *args])
        return real(root, *args)

    monkeypatch.setattr(hat, "_git", broken)
    rc, fails, _ = audit(repo)
    assert rc == 2 and len(fails) == 1  # cannot tell: fail closed


def test_pending_note_is_filtered_by_the_untick_too(repo):
    commit(repo, body("x", " "), f"{TID}: tick")
    key = hat.boxes(hat._human_section(body("x", " ")))[0][0]
    hat.record(repo, TID, key, "operator-ack", "op")  # written, never committed
    rc, _, lines = audit(repo)
    assert rc == 0 and any(ln.startswith("NOTE") for ln in lines), lines
    commit(repo, body(" ", " "), f"{TID}: un-tick")
    git(repo, "rm", "-q", "--cached", hat.LEDGER)  # keep the row uncommitted
    git(repo, "commit", "-qm", f"{TID}: keep ledger out")
    rc, _, lines = audit(repo)
    assert rc == 0 and not any(ln.startswith("NOTE") for ln in lines), lines
    assert "UNCOMMITTED" not in lines[-1]
