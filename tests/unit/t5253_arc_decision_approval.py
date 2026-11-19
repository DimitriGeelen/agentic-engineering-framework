"""T-5253 (T-5224 slice 4): consequential arc decisions need operator approval or a green
independent-reviewer verdict.

Every test uses a temporary project root (git-initialised, like the reviewer tests); the real
.context/arcs and the real .context/reviews ledgers are never touched. The review-dispatch
registry fixture is built the way the reviewer tests build it (tests/unit/_review_runtime.py).
Run: python3 -m pytest tests/unit/t5253_arc_decision_approval.py -q
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import arc_journal as aj  # noqa: E402
from lib import arc_owner as ao  # noqa: E402
import _review_runtime as rt  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse: no host hub/session)

JOURNAL_CLI = [sys.executable, str(FW / "lib" / "arc_journal.py")]


def _git(root, *a):
    subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *a], cwd=root, check=True,
                   capture_output=True)


@pytest.fixture
def root(tmp_path, monkeypatch):
    d = tmp_path / ".context" / "arcs"
    d.mkdir(parents=True)
    (d / "demo-arc.yaml").write_text("id: arc-901\nslug: demo-arc\nname: \"fixture\"\nstatus: in-progress\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(FW))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    _git(tmp_path, "init", "-q")
    ao.set_owner("demo-arc", True, project_root=tmp_path)
    return tmp_path


def _cli(root, *args, agent=True):
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    env["PROJECT_ROOT"] = str(root)
    if agent:
        env["CLAUDECODE"] = "1"
    return subprocess.run(JOURNAL_CLI + list(args), capture_output=True, text=True, env=env, cwd=root)


def _arc_sh(root, *args, agent=True):
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "_FW_PATHS_DERIVED_BY")}
    env.update({"PROJECT_ROOT": str(root), "FRAMEWORK_ROOT": str(FW),
                "ARCS_DIR": str(root / ".context" / "arcs"),
                "ARC_FOCUS_FILE": str(root / ".context" / "working" / "arc-focus.yaml")})
    if agent:
        env["CLAUDECODE"] = "1"
    (root / ".context" / "working").mkdir(parents=True, exist_ok=True)
    return subprocess.run(["bash", "-c", '. "$FRAMEWORK_ROOT/lib/arc.sh"; arc_dispatch "$@"', "_", *args],
                          capture_output=True, text=True, env=env, cwd=root)


def _resumable_with(root, **decided):
    """A journal whose only blocker can be the decision under test."""
    row = aj.append("demo-arc", "decided", "owner-agent", root, text="skip K3", reason="K3 is moot", **decided)
    aj.append("demo-arc", "next", "owner-agent", root, step="go on", owner="agent")
    return row


def _codes(root):
    findings, ok = aj.check("demo-arc", root)
    return [f["code"] for f in findings], ok, findings


# ---------------------------------------------------------------- ids and categories

def test_new_rows_get_sequential_ids_old_rows_addressed_by_position(root):
    path = root / ".context" / "arcs" / "demo-arc.journal.jsonl"
    old = {"ts": "2026-11-01T00:00:00Z", "kind": "decided", "by": "old", "text": "legacy",
           "reason": "pre-id", "consequential": True}
    path.write_text(json.dumps(old) + "\n")
    r1 = aj.append("demo-arc", "tried", "a", root, text="x", result="y")
    r2 = aj.append("demo-arc", "next", "a", root, step="s", owner="a")
    assert (r1["id"], r2["id"]) == ("J-1", "J-2")
    entries, bad = aj.read("demo-arc", root)
    assert bad == [] and [aj.entry_ref(e) for e in entries] == ["J@1", "J-1", "J-2"]
    assert aj.find_entry(entries, "J@1")["text"] == "legacy"
    assert aj.find_entry(entries, "J@2") is None          # line 2 has an id; position does not address it
    # the old consequential row is pending and addressable
    assert [u["ref"] for u in aj.unapproved("demo-arc", root)] == ["J@1"]
    r = aj.approve("demo-arc", "J@1", "operator", words="fine, skip it", project_root=root)
    assert r["id"] == "J-3" and r["ref"] == "J@1"
    assert aj.unapproved("demo-arc", root) == []


def test_ids_survive_a_torn_line(root):
    aj.append("demo-arc", "tried", "a", root, text="x", result="y")
    path = root / ".context" / "arcs" / "demo-arc.journal.jsonl"
    with open(path, "a") as fh:
        fh.write('{"torn')
    assert aj.append("demo-arc", "tried", "a", root, text="x", result="y")["id"] == "J-2"


@pytest.mark.parametrize("cat", ["skip-step", "accept-failed-check", "defer", "change-scope"])
def test_consequential_category_implies_flag(root, cat):
    assert aj.append("demo-arc", "decided", "a", root, text="t", reason="r", category=cat)["consequential"] is True


def test_other_category_is_routine_and_bad_category_refused(root):
    assert aj.append("demo-arc", "decided", "a", root, text="t", reason="r", category="other")["consequential"] is False
    with pytest.raises(aj.JournalError, match="category"):
        aj.append("demo-arc", "decided", "a", root, text="t", reason="r", category="whatever")


def test_append_refuses_approved_kind(root):
    _resumable_with(root, consequential=True)
    with pytest.raises(aj.JournalError, match="approve"):
        aj.append("demo-arc", "approved", "a", root, ref="J-1", route="operator", words="w")
    r = _cli(root, "append", "demo-arc", "approved", "--by", "a")
    assert r.returncode == 2


# ---------------------------------------------------------------- check / resumability

def test_check_flags_unapproved_and_clears_after_operator_approval(root):
    row = _resumable_with(root, category="skip-step")
    codes, ok, findings = _codes(root)
    assert codes == ["CONSEQUENTIAL_UNAPPROVED"] and not ok
    assert findings[0]["ref"] == row["id"] and "fw arc approve demo-arc J-1" in findings[0]["reason"]
    aj.approve("demo-arc", row["id"], "operator", words="yes, skip K3", project_root=root)
    codes, ok, _ = _codes(root)
    assert codes == [] and ok


def test_routine_decision_needs_nothing_and_cannot_be_approved(root):
    row = _resumable_with(root)
    assert _codes(root)[1] is True
    with pytest.raises(aj.JournalError, match="routine"):
        aj.approve("demo-arc", row["id"], "operator", words="ok", project_root=root)


def test_approve_refuses_unknown_ref_non_decision_and_duplicates(root):
    row = _resumable_with(root, consequential=True)
    with pytest.raises(aj.JournalError, match="no entry"):
        aj.approve("demo-arc", "J-99", "operator", words="ok", project_root=root)
    with pytest.raises(aj.JournalError, match="only decisions"):
        aj.approve("demo-arc", "J-2", "operator", words="ok", project_root=root)
    with pytest.raises(aj.JournalError, match="words"):
        aj.approve("demo-arc", row["id"], "operator", words="  ", project_root=root)
    aj.approve("demo-arc", row["id"], "operator", words="ok", project_root=root)
    with pytest.raises(aj.JournalError, match="already approved"):
        aj.approve("demo-arc", row["id"], "operator", words="again", project_root=root)


def test_brief_lists_unapproved_with_ids_and_is_not_resumable(root):
    _resumable_with(root, category="defer")
    b = ao.brief("demo-arc", root)
    assert not b["resumable"] and [u["ref"] for u in b["unapproved"]] == ["J-1"]
    text = ao.render(b)
    assert "waiting for approval" in text and "J-1" in text and "fw arc approve demo-arc J-1" in text


# ---------------------------------------------------------------- operator-only CLI

def test_operator_approve_refused_under_agent_control(root):
    _resumable_with(root, consequential=True)
    r = _cli(root, "approve", "demo-arc", "J-1", "--words", "agent says ok")
    assert r.returncode == 1 and "operator" in r.stderr and "--i-am-human" in r.stderr
    assert _codes(root)[1] is False                      # nothing written
    assert not (root / ".context" / "working" / ".gate-bypass-log.yaml").exists()


def test_operator_approve_accepted_with_i_am_human_and_logged(root):
    _resumable_with(root, consequential=True)
    r = _cli(root, "approve", "demo-arc", "J-1", "--words", "go ahead", "--i-am-human")
    assert r.returncode == 0, r.stderr
    row = json.loads(r.stdout)
    assert row["kind"] == "approved" and row["route"] == "operator" and row["words"] == "go ahead"
    log = (root / ".context" / "working" / ".gate-bypass-log.yaml").read_text()
    assert "--i-am-human" in log and "fw arc approve" in log
    assert _codes(root)[1] is True


def test_operator_approve_outside_agent_control_needs_no_flag(root):
    _resumable_with(root, consequential=True)
    r = _cli(root, "approve", "demo-arc", "J-1", "--words", "go", agent=False)
    assert r.returncode == 0, r.stderr


def test_fw_arc_approve_verb_refuses_agent_and_resume_holds_focus(root):
    _resumable_with(root, consequential=True, task="T-9001")
    (root / ".tasks" / "active").mkdir(parents=True)
    (root / ".tasks" / "active" / "T-9001-x.md").write_text(
        "---\nid: T-9001\nname: \"x\"\nstatus: started-work\nhorizon: now\narc_id: demo-arc\nowner: agent\n---\n")
    aj.append("demo-arc", "next", "a", root, step="build", owner="agent", task="T-9001")
    r = _arc_sh(root, "approve", "demo-arc", "J-1", "--words", "x")
    assert r.returncode == 1 and "operator" in r.stderr
    r = _arc_sh(root, "resume", "demo-arc")
    assert r.returncode == 1
    assert "CONSEQUENTIAL_UNAPPROVED" in r.stdout and "J-1" in r.stdout
    assert "Task focus NOT moved to T-9001" in r.stdout
    r = _arc_sh(root, "show", "demo-arc")
    assert "J-1" in r.stdout and "waiting for approval" in r.stdout


# ---------------------------------------------------------------- reviewer route

def test_decision_review_setting_default_set_and_preserved(root):
    assert aj.decision_review("demo-arc", root) == "operator"
    ao.set_owner("demo-arc", True, decision_review="reviewer", project_root=root)
    assert aj.decision_review("demo-arc", root) == "reviewer"
    ao.set_owner("demo-arc", False, project_root=root)
    ao.set_owner("demo-arc", True, project_root=root)
    assert ao.state("demo-arc", root)["owner"]["decision_review"] == "reviewer"
    with pytest.raises(aj.JournalError):
        ao.set_owner("demo-arc", True, decision_review="anyone", project_root=root)


def test_reviewer_route_accepts_registered_green_review_dispatch(root):
    ao.set_owner("demo-arc", True, decision_review="reviewer", project_root=root)
    _resumable_with(root, consequential=True)
    did = rt.dispatch(root, "rv-arc-1", "T-9001")
    r = _cli(root, "approve", "demo-arc", "J-1", "--dispatch-id", did, "--outcome", "green")
    assert r.returncode == 0, r.stderr                    # evidence-based: allowed under agent control
    assert json.loads(r.stdout)["route"] == "reviewer"
    assert _codes(root)[1] is True


@pytest.mark.parametrize("did,outcome,setting,needle", [
    ("rv-unknown", "green", "reviewer", "not in the review-dispatch registry"),
    ("rv-arc-1", "amber", "reviewer", "not green"),
    ("rv-arc-1", "green", "operator", "decision_review"),
])
def test_reviewer_route_refusals(root, did, outcome, setting, needle):
    ao.set_owner("demo-arc", True, decision_review=setting, project_root=root)
    _resumable_with(root, consequential=True)
    rt.dispatch(root, "rv-arc-1", "T-9001")
    with pytest.raises(aj.JournalError, match=needle):
        aj.approve("demo-arc", "J-1", "rev", dispatch_id=did, outcome=outcome, project_root=root)
    assert _codes(root)[1] is False


def test_reviewer_route_refuses_non_review_dispatch(root):
    ao.set_owner("demo-arc", True, decision_review="either", project_root=root)
    _resumable_with(root, consequential=True)
    rt.dispatch(root, "bd-1", "T-9001", task_type="build")
    with pytest.raises(aj.JournalError, match="not a review dispatch"):
        aj.approve("demo-arc", "J-1", "rev", dispatch_id="bd-1", outcome="green", project_root=root)


def test_one_review_dispatch_approves_one_decision(root):
    ao.set_owner("demo-arc", True, decision_review="reviewer", project_root=root)
    _resumable_with(root, consequential=True)
    aj.append("demo-arc", "decided", "a", root, text="defer K4", reason="r", category="defer")
    aj.append("demo-arc", "next", "a", root, step="s", owner="a")
    rt.dispatch(root, "rv-arc-1", "T-9001")
    aj.approve("demo-arc", "J-1", "rev", dispatch_id="rv-arc-1", outcome="green", project_root=root)
    with pytest.raises(aj.JournalError, match="already approved J-1"):
        aj.approve("demo-arc", "J-3", "rev", dispatch_id="rv-arc-1", outcome="green", project_root=root)


def test_reviewer_approval_ignored_at_check_time_once_invalid(root):
    ao.set_owner("demo-arc", True, decision_review="reviewer", project_root=root)
    _resumable_with(root, consequential=True)
    rt.dispatch(root, "rv-arc-1", "T-9001")
    aj.approve("demo-arc", "J-1", "rev", dispatch_id="rv-arc-1", outcome="green", project_root=root)
    assert _codes(root)[1] is True
    # the project switches back to operator-only: the reviewer approval no longer counts
    ao.set_owner("demo-arc", True, decision_review="operator", project_root=root)
    codes, ok, _ = _codes(root)
    assert not ok and "CONSEQUENTIAL_UNAPPROVED" in codes and "INVALID_APPROVAL" in codes
    # a forged row (registry entry gone) is ignored too
    ao.set_owner("demo-arc", True, decision_review="reviewer", project_root=root)
    reg = root / ".context" / "reviews" / "review-dispatches.jsonl"
    reg.write_text("")
    codes, ok, _ = _codes(root)
    assert not ok and "INVALID_APPROVAL" in codes


def test_operator_approval_counts_whatever_the_setting(root):
    ao.set_owner("demo-arc", True, decision_review="reviewer", project_root=root)
    _resumable_with(root, consequential=True)
    aj.approve("demo-arc", "J-1", "operator", words="I decide", project_root=root)
    assert _codes(root)[1] is True


# ---------------------------------------------------------------- operator pending

def test_operator_pending_lists_unapproved_with_command(root, monkeypatch):
    import importlib
    from lib import operator_pending as op
    _resumable_with(root, category="change-scope")
    monkeypatch.setattr(op, "PROJECT", root)
    items = op.arc_unapproved_decisions()
    assert [(i["arc"], i["ref"]) for i in items] == [("demo-arc", "J-1")]
    data = {"arc_decisions": items, "arc_wake_limits": [], "hub_profiles": [], "outside_commits": [],
            "issue_replies": [], "inceptions": [], "inception_questions": [], "reviews": [],
            "runmes": [], "paid_proposals": [], "waiting_on_agent": 0}
    text = op.render(data)
    assert "Arc decisions waiting for your approval" in text
    assert 'fw arc approve demo-arc J-1 --words "<your words>"' in text
    aj.approve("demo-arc", "J-1", "operator", words="ok", project_root=root)
    assert op.arc_unapproved_decisions() == []
    importlib.reload(op)
