"""T-5222 (slice 2 of T-5211): operator actions that hand the next step to the agent post
ONE notice through the shared notifier lib/agent_notice.py.

  * Watchtower toggle-ac: one notice when a Human criterion becomes ticked, an "all ticked"
    text for the last one, none on untick.
  * restatement accept / reject: one notice naming the task and the verdict id.
  * paid-review approve: one notice naming the proposal and the task.
  * a failed post never changes the action's result; no notice carries task-file text.

Every test stubs the sender (agent_notice.send_notice) — no real sidecar message is sent.
Temp project roots only."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

from lib import agent_notice as an  # noqa: E402
from lib import review_cost  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import human_criteria  # noqa: E402
from lib.reviewer import restatement_cli as rc  # noqa: E402

SECRET_TITLE = "Zebra-quartz criterion wording"
SECRET_STEP = "open the moonbeam page"

TASK = f"""---
id: T-9003
name: fixture
status: started-work
owner: human
---

# T-9003

## Acceptance Criteria

### Agent
- [x] Agent criterion

### Human
- [ ] [REVIEW] {SECRET_TITLE} one
  **Steps:** {SECRET_STEP}
  **Expected:** fine
- [ ] [REVIEW] {SECRET_TITLE} two
  **Expected:** fine
- [ ] [REVIEW] {SECRET_TITLE} three
  **Expected:** fine

## Verification
"""


@pytest.fixture
def sent(monkeypatch):
    """Allow notices in this test run and stub the sender; returns the captured calls."""
    calls = []

    def fake(fw_bin, to, body, **kw):
        calls.append({"fw_bin": fw_bin, "to": to, "body": body, **kw})
        return True, "sent"
    monkeypatch.setenv("FW_AGENT_NOTICES", "1")
    monkeypatch.setattr(an, "send_notice", fake)
    monkeypatch.setattr(an, "own_address", lambda: "proj")
    return calls


def _fail_sender(monkeypatch, how):
    monkeypatch.setenv("FW_AGENT_NOTICES", "1")
    monkeypatch.setattr(an, "own_address", lambda: "proj")
    if how == "raise":
        def boom(*a, **k):
            raise RuntimeError("sender exploded")
        monkeypatch.setattr(an, "send_notice", boom)
    elif how == "address":
        def noaddr():
            raise RuntimeError("no id")
        monkeypatch.setattr(an, "own_address", noaddr)
    else:
        monkeypatch.setattr(an, "send_notice", lambda *a, **k: (False, "exit 3: no receiver"))


def _log(root):
    p = Path(root) / an.LOG
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def _no_task_text(body):
    assert SECRET_TITLE not in body and SECRET_STEP not in body and "REVIEW" not in body


# ------------------------------------------------------------ shared module

def test_decide_runner_uses_the_shared_module():
    src = (FRAMEWORK_ROOT / "web" / "decide_runner.py").read_text()
    assert "agent_notice.send_notice(" in src and "agent_notice.own_address()" in src
    assert "subprocess.run([fw_bin, \"sidecar\"" not in src  # no second copy of the sender


def test_test_runs_never_send_for_real_without_opt_in(tmp_path, monkeypatch):
    called = []
    monkeypatch.delenv("FW_AGENT_NOTICES", raising=False)
    monkeypatch.setattr(an, "send_notice", lambda *a, **k: called.append(a) or (True, "sent"))
    rec = an.post("x", "T-1", "body", root=tmp_path)
    assert rec["state"] == "skipped" and called == []


def test_switch_off(tmp_path, monkeypatch, sent):
    monkeypatch.setenv("FW_AGENT_NOTICES", "0")
    assert an.post("x", "T-1", "body", root=tmp_path)["state"] == "skipped"
    assert sent == []


def test_real_sender_timeout_is_short_and_reported(tmp_path):
    slow = tmp_path / "fw-slow"
    slow.write_text("#!/bin/sh\nsleep 5\n")
    slow.chmod(0o755)
    ok, detail = an.send_notice(str(slow), "proj", "b", cwd=tmp_path, timeout=0.3)
    assert not ok and "timed out" in detail
    assert an.ACTION_TIMEOUT <= 10


def test_wait_false_returns_without_waiting(tmp_path, monkeypatch):
    import threading
    gate = threading.Event()
    monkeypatch.setenv("FW_AGENT_NOTICES", "1")
    monkeypatch.setattr(an, "own_address", lambda: "proj")
    monkeypatch.setattr(an, "send_notice", lambda *a, **k: (gate.wait(5), "sent"))
    th = an.post("x", "T-1", "b", root=tmp_path, wait=False)
    assert th.is_alive()        # the caller got control back while the post is pending
    gate.set()
    th.join(5)
    assert _log(tmp_path)[-1]["state"] == "sent"


@pytest.mark.parametrize("bad", ["T-1; rm", "x y", ""])
def test_texts_refuse_anything_but_ids(bad):
    with pytest.raises(ValueError):
        an.restatement_text("T-1", bad, "accepted")
    with pytest.raises(ValueError):
        an.paid_review_approved_text(bad, "T-1")


# ------------------------------------------------------------ toggle-ac

def git(root, *args):
    subprocess.run(["git", "-C", str(root), "-c", "user.name=Operator",
                    "-c", "user.email=op@example.com", *args], check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path, monkeypatch):
    from flask import Flask
    from web.blueprints import tasks as tasks_bp
    root = tmp_path
    (root / ".tasks" / "active").mkdir(parents=True)
    tf = root / ".tasks" / "active" / "T-9003-fixture.md"
    tf.write_text(TASK)
    git(root, "init", "-q")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "T-9003: seed")
    monkeypatch.setattr(tasks_bp, "PROJECT_ROOT", root)
    # run the post inline so the test can see it (the route asks for wait=False)
    real_post = an.post
    monkeypatch.setattr(an, "post", lambda *a, **k: real_post(*a, **{**k, "wait": True}))
    app = Flask(__name__)
    app.register_blueprint(tasks_bp.bp)
    return root, tf, app.test_client()


def _tick(client, tf, needle):
    body = tf.read_text().split("---\n", 2)[2]
    line = next(i for i, ln in enumerate(body.split("\n")) if needle in ln)
    return client.post("/api/task/T-9003/toggle-ac", data={"line": line})


def test_route_posts_without_waiting():
    src = (FRAMEWORK_ROOT / "web" / "blueprints" / "tasks.py").read_text()
    assert "notify_criterion_ticked(" in src and "wait=False" in src


def test_tick_posts_one_notice_with_counts(repo, sent):
    _, tf, client = repo
    r = _tick(client, tf, f"{SECRET_TITLE} two")
    assert r.status_code == 200
    assert [c["body"] for c in sent] == [
        "T-9003: Human criterion 2 ticked by the operator (1 of 3 ticked)."]
    assert sent[0]["to"] == "proj"


def test_last_tick_posts_the_all_ticked_text(repo, sent):
    _, tf, client = repo
    for n in ("one", "two", "three"):
        _tick(client, tf, f"{SECRET_TITLE} {n}")
    assert len(sent) == 3
    assert sent[-1]["body"] == ("T-9003: all Human criteria ticked by the operator (3 of 3); "
                                "close it with fw task update T-9003 --status work-completed.")
    for c in sent:
        _no_task_text(c["body"])


def test_untick_posts_nothing(repo, sent):
    _, tf, client = repo
    _tick(client, tf, f"{SECRET_TITLE} one")
    _tick(client, tf, f"{SECRET_TITLE} one")   # untick
    assert len(sent) == 1
    assert "[ ] [REVIEW] " + SECRET_TITLE + " one" in tf.read_text()


def test_agent_criterion_tick_posts_nothing(repo, sent):
    _, tf, client = repo
    _tick(client, tf, "Agent criterion")      # untick an Agent box
    _tick(client, tf, "Agent criterion")      # tick it again
    assert sent == []


@pytest.mark.parametrize("how", ["raise", "address", "fail"])
def test_failed_post_never_changes_the_tick(repo, monkeypatch, how):
    root, tf, client = repo
    _fail_sender(monkeypatch, how)
    r = _tick(client, tf, f"{SECRET_TITLE} one")
    assert r.status_code == 200 and "checked" in r.get_data(as_text=True)
    assert "- [x] [REVIEW] " + SECRET_TITLE + " one" in tf.read_text()
    assert _log(root)[-1]["state"] == "failed"


def test_notifier_itself_raising_never_changes_the_tick(repo, monkeypatch):
    _, tf, client = repo

    def boom(*a, **k):
        raise RuntimeError("notifier exploded")
    monkeypatch.setattr(an, "notify_criterion_ticked", boom)
    r = _tick(client, tf, f"{SECRET_TITLE} one")
    assert r.status_code == 200
    assert "- [x] [REVIEW] " + SECRET_TITLE + " one" in tf.read_text()


# ------------------------------------------------------------ restatement

def _digest(text, ac):
    return vl.criterion_digest(next(c for c in human_criteria(text) if c.index == ac))


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".context" / "reviews").mkdir(parents=True)
    (tmp_path / ".tasks" / "active" / "T-9003-fixture.md").write_text(TASK)
    row = {"id": "V-1", "task": "T-9003", "ac": 1, "ac_digest": _digest(TASK, 1),
           "outcome": "amber", "reviewer": "r1", "ts": "2026-11-18T10:00:00Z",
           "guidance": f"PROPOSED RESTATEMENT: [REVIEW] {SECRET_TITLE} restated"}
    (tmp_path / vl.VERDICTS).write_text(json.dumps(row) + "\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    return tmp_path


def test_accept_posts_one_notice(proj, sent):
    rc.accept(proj, "V-1")
    assert [c["body"] for c in sent] == [
        "T-9003: restatement V-1 accepted by the operator; commit the task file, "
        "then re-run fw reviewer judge T-9003."]
    _no_task_text(sent[0]["body"])


def test_reject_posts_one_notice(proj, sent):
    rc.reject(proj, "V-1", f"because {SECRET_TITLE}")
    assert len(sent) == 1
    assert sent[0]["body"].startswith("T-9003: restatement V-1 rejected by the operator;")
    _no_task_text(sent[0]["body"])
    assert "because" not in sent[0]["body"]   # the reason is task-adjacent text: not carried


def test_dry_runs_post_nothing(proj, sent):
    rc.accept(proj, "V-1", dry_run=True)
    rc.reject(proj, "V-1", "r", dry_run=True)
    assert sent == []


@pytest.mark.parametrize("how", ["raise", "address", "fail"])
def test_failed_post_never_changes_accept_or_reject(proj, monkeypatch, capsys, how):
    _fail_sender(monkeypatch, how)
    assert rc.main(["accept", "V-1"]) == 0
    assert "restated" in (proj / ".tasks" / "active" / "T-9003-fixture.md").read_text()
    rec = json.loads((proj / rc.DECISIONS).read_text().splitlines()[-1])
    assert rec["decision"] == "accepted"
    assert _log(proj)[-1]["state"] == "failed"


def test_failed_post_never_changes_reject(proj, monkeypatch):
    _fail_sender(monkeypatch, "raise")
    assert rc.main(["reject", "V-1", "--reason", "no"]) == 0
    assert json.loads((proj / rc.DECISIONS).read_text())["decision"] == "rejected"


# ------------------------------------------------------------ paid-review approve

@pytest.fixture
def costs(tmp_path, monkeypatch):
    (tmp_path / "policy").mkdir()
    shutil.copy(FRAMEWORK_ROOT / "policy" / "review-backends.yaml", tmp_path / "policy")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(FRAMEWORK_ROOT))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    p = review_cost.propose(task="T-9003", backend="openrouter", why="high risk",
                            est_cost=3, est_tokens=None)
    return tmp_path, p["id"]


def test_approve_posts_one_notice(costs, sent):
    root, pid = costs
    review_cost.approve(pid=pid, i_am_human=False, reason="ok")
    assert [c["body"] for c in sent] == [
        f"Paid review {pid} approved by the operator for T-9003; run it, then log the cost "
        f"with fw review cost log --task T-9003 --proposal-id {pid}."]


def test_refused_approve_posts_nothing(costs, sent, monkeypatch):
    _, pid = costs
    monkeypatch.setenv("CLAUDECODE", "1")
    with pytest.raises(review_cost.CostError):
        review_cost.approve(pid=pid, i_am_human=False, reason="ok")
    assert sent == []


@pytest.mark.parametrize("how", ["raise", "address", "fail"])
def test_failed_post_never_changes_approve(costs, monkeypatch, how):
    root, pid = costs
    _fail_sender(monkeypatch, how)
    rec = review_cost.approve(pid=pid, i_am_human=False, reason="ok")
    assert rec["event"] == "approved"
    assert review_cost.proposals()[pid]["status"] == "approved"
    assert _log(root)[-1]["state"] == "failed"


def test_failed_post_never_changes_approve_exit_status(costs, monkeypatch):
    root, pid = costs
    _fail_sender(monkeypatch, "raise")
    assert review_cost.main(["approve", pid, "--reason", "ok"]) == 0
    assert review_cost.proposals()[pid]["status"] == "approved"
