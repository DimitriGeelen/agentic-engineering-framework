"""T-3749: Watchtower's inception decide runs detached and says what landed.

Origin: the operator pressed GO on T-3631. Watchtower ran the decide chain
under a 30 s timeout; the chain took ~40 s (task in completed/ at ~23 s), the
subprocess was killed mid-chain, and the page said "Automatic completion was
blocked by a framework gate … Reason: Command timed out" — for a decision
that had landed and a task that had completed.

Pinned here:
  1. classify(): one outcome per (landed, completed, running, rc) state.
  2. The route's wording per outcome: landed+running, landed+done,
     landed+gate-refused, not landed — and never "timed out" or a gate claim
     for a chain that is still running.
  3. A slow fake chain is not killed: it outlives the request, runs in its own
     session, and finishes; a second launch while it runs is refused (Busy).
  4. LazyTaskIndex returns exactly what task_index() returns, per id.
"""
from __future__ import annotations

import importlib
import os
import sys
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from web import decide_runner as dr  # noqa: E402


# ---------------------------------------------------------------- 1. classify

@pytest.mark.parametrize("decision,landed,completed,running,rc,expected", [
    ("go", True, True, True, None, dr.LANDED_RUNNING),
    ("go", True, True, False, 0, dr.LANDED_DONE),
    ("go", True, True, False, 1, dr.LANDED_FOLLOWUP_FAILED),
    ("go", True, False, False, 1, dr.LANDED_GATE_REFUSED),
    ("go", True, False, True, None, dr.LANDED_COMPLETING),
    ("no-go", True, False, False, 1, dr.LANDED_GATE_REFUSED),
    ("go", False, False, True, None, dr.PENDING),
    ("go", False, False, False, 1, dr.NOT_LANDED),
    ("go", False, False, False, 0, dr.NOT_LANDED),
    # defer never completes the task: landed is the whole primary result
    ("defer", True, False, True, None, dr.LANDED_RUNNING),
    ("defer", True, False, False, 0, dr.LANDED_DONE),
    # killed / crashed with the decision written: never gate wording (review r1)
    ("go", True, False, False, -9, dr.LANDED_INTERRUPTED),
    ("go", True, False, False, 137, dr.LANDED_INTERRUPTED),
    ("go", True, False, False, 124, dr.LANDED_GATE_REFUSED),  # <128: a plain exit code
    ("go", True, False, False, -1, dr.LANDED_INTERRUPTED),
    ("go", True, False, False, None, dr.LANDED_INTERRUPTED),
    ("go", True, False, False, 0, dr.LANDED_INTERRUPTED),
])
def test_classify(decision, landed, completed, running, rc, expected):
    assert dr.classify(decision, landed=landed, completed=completed,
                       running=running, rc=rc) == expected


def test_a_running_chain_is_never_a_gate_refusal():
    for completed in (True, False):
        for landed in (True, False):
            out = dr.classify("go", landed=landed, completed=completed, running=True, rc=None)
            assert out not in (dr.LANDED_GATE_REFUSED, dr.NOT_LANDED, dr.LANDED_FOLLOWUP_FAILED)


def test_only_a_plain_nonzero_exit_is_a_gate_refusal():
    for rc in (None, -15, -9, -1, 0, 128, 137, 143, 255):
        out = dr.classify("go", landed=True, completed=False, running=False, rc=rc)
        assert out != dr.LANDED_GATE_REFUSED, rc


# ---------------------------------------------------------------- 2. route wording

DECIDED = """---
id: {tid}
name: "fixture"
status: work-completed
workflow_type: inception
owner: human
---
# {tid}: fixture

## Decision

**Decision**: GO

**Rationale**: test

## Updates
"""

UNDECIDED = """---
id: {tid}
name: "fixture"
status: started-work
workflow_type: inception
owner: human
---
# {tid}: fixture

## Decision

<!-- fw inception decide T-XXX go|no-go -->

## Updates
"""


@pytest.fixture
def app_env(tmp_path, monkeypatch):
    for d in (".context/working", ".tasks/active", ".tasks/completed"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    inc = web.blueprints.inception
    # The auto-commit is pinned by test_decide_commit.py; here it would need a repo.
    monkeypatch.setattr(inc, "_commit_decision", lambda *a, **k: (True, "nothing to commit"))
    with app.test_client() as c:
        yield c, tmp_path, inc


def _post(c, tid, htmx=True):
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "tok"
    return c.post(f"/inception/{tid}/decide",
                  data={"decision": "go", "rationale": "r", "_csrf_token": "tok"},
                  headers={"HX-Request": "true"} if htmx else {})


FORBIDDEN = ("timed out", "blocked by a framework gate", "Decision not recorded")


def test_landed_and_still_running_says_so(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/completed/T-9701-x.md").write_text(DECIDED.format(tid="T-9701"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        running=True, run_dir=".context/working/decide/T-9701-run"))
    html = _post(c, "T-9701").get_data(as_text=True)
    assert "Decision recorded" in html
    assert "still finishing in the background" in html
    assert ".context/working/decide/T-9701-run" in html
    for bad in FORBIDDEN:
        assert bad not in html


def test_landed_and_done_is_plain_success(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/completed/T-9702-x.md").write_text(DECIDED.format(tid="T-9702"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(rc=0))
    html = _post(c, "T-9702").get_data(as_text=True)
    assert "Decision recorded" in html
    assert "⚠" not in html and "⏳" not in html
    for bad in FORBIDDEN:
        assert bad not in html


def test_landed_and_gate_refused_keeps_gate_wording_with_real_reason(app_env, monkeypatch):
    c, p, inc = app_env
    # Decision written, chain FINISHED non-zero, task still in active/.
    (p / ".tasks/active/T-9703-x.md").write_text(
        DECIDED.format(tid="T-9703").replace("work-completed", "started-work"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        err="ERROR: Cannot complete — P-010 unchecked acceptance criteria", rc=1))
    html = _post(c, "T-9703").get_data(as_text=True)
    assert "Decision recorded" in html
    assert "blocked by a framework gate" in html
    assert "P-010 unchecked acceptance criteria" in html
    assert "timed out" not in html


def test_landed_completion_still_running_is_not_a_gate_claim(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/active/T-9704-x.md").write_text(
        DECIDED.format(tid="T-9704").replace("work-completed", "started-work"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(running=True))
    html = _post(c, "T-9704").get_data(as_text=True)
    assert "Completing the task is still running" in html
    for bad in FORBIDDEN:
        assert bad not in html


def test_not_landed_and_finished_is_a_failure(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/active/T-9705-x.md").write_text(UNDECIDED.format(tid="T-9705"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        err="ERROR: ## Recommendation section required", rc=1))
    html = _post(c, "T-9705").get_data(as_text=True)
    assert "Decision not recorded" in html
    assert "Recommendation section required" in html


def test_not_landed_and_still_running_is_in_progress_not_failure(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/active/T-9706-x.md").write_text(UNDECIDED.format(tid="T-9706"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(running=True))
    html = _post(c, "T-9706").get_data(as_text=True)
    assert "Decision in progress" in html
    for bad in FORBIDDEN + ("Decision recorded",):
        assert bad not in html


def test_second_click_while_running_is_refused_not_restarted(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/active/T-9707-x.md").write_text(UNDECIDED.format(tid="T-9707"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(busy=True))
    html = _post(c, "T-9707").get_data(as_text=True)
    assert "already being recorded" in html
    for bad in FORBIDDEN:
        assert bad not in html


def test_landed_and_killed_is_not_a_gate_claim(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/active/T-9709-x.md").write_text(
        DECIDED.format(tid="T-9709").replace("work-completed", "started-work"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        err="", rc=-9, run_dir=".context/working/decide/T-9709-run"))
    html = _post(c, "T-9709").get_data(as_text=True)
    assert "Decision recorded" in html
    assert "stopped (exit -9) before completing the task" in html
    for bad in FORBIDDEN:
        assert bad not in html


def test_not_landed_and_killed_says_it_stopped(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/active/T-9710-x.md").write_text(UNDECIDED.format(tid="T-9710"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        err="", rc=-9, run_dir=".context/working/decide/T-9710-run"))
    html = _post(c, "T-9710").get_data(as_text=True)
    assert "Decision not recorded" in html
    assert "stopped unexpectedly (exit -9)" in html
    assert "blocked by a framework gate" not in html


def test_request_does_not_commit(app_env, monkeypatch):
    """The runner commits; the request must never wait on git or the commit lock."""
    c, p, inc = app_env
    (p / ".tasks/completed/T-9711-x.md").write_text(DECIDED.format(tid="T-9711"))
    calls = []
    monkeypatch.setattr(inc, "_commit_decision", lambda *a, **k: calls.append(a) or (True, ""))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(running=True))
    _post(c, "T-9711")
    assert calls == []


def test_runner_reported_commit_failure_is_shown(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/completed/T-9712-x.md").write_text(DECIDED.format(tid="T-9712"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        rc=0, commit_ok=False, commit_msg="pre-commit hook refused"))
    html = _post(c, "T-9712").get_data(as_text=True)
    assert "Decision recorded but not committed" in html and "pre-commit hook refused" in html


def test_form_path_landed_running_redirects_with_notice_not_warning(app_env, monkeypatch):
    c, p, inc = app_env
    (p / ".tasks/completed/T-9708-x.md").write_text(DECIDED.format(tid="T-9708"))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(running=True))
    resp = _post(c, "T-9708", htmx=False)
    assert resp.status_code == 302
    loc = resp.headers["Location"]
    assert "notice=" in loc and "warning=" not in loc and "error=" not in loc


# ---------------------------------------------------------------- 3. slow chain

SLOW_FW = """#!/usr/bin/env python3
# Fake `fw inception decide`: writes the decision, moves the task, then keeps
# running well past the caller's wait. Records that it reached its end.
import os, sys, time, pathlib
root = pathlib.Path(os.environ["PROJECT_ROOT"])
tid, decision = sys.argv[3], sys.argv[4]
src = next((root / ".tasks/active").glob(tid + "-*.md"))
time.sleep(float(os.environ.get("SLOW_FW_PRE", "0.3")))
text = src.read_text().replace("<!-- fw inception decide T-XXX go|no-go -->",
                               "**Decision**: " + decision.upper())
dst = root / ".tasks/completed" / src.name
dst.write_text(text)
src.unlink()
print("moved", flush=True)
time.sleep(float(os.environ.get("SLOW_FW_TAIL", "3")))
(root / "chain-finished").write_text(str(os.getsid(0)))
print("finished", flush=True)
"""


@pytest.fixture
def slow_chain(tmp_path, monkeypatch):
    proj = tmp_path / "proj"
    for d in (".context/working", ".tasks/active", ".tasks/completed"):
        (proj / d).mkdir(parents=True)
    (proj / ".tasks/active/T-9750-x.md").write_text(UNDECIDED.format(tid="T-9750"))
    # Its own repo: the runner commits when the chain ends, and git must not walk
    # up into whatever repo encloses the temp dir (on some hosts / is one).
    import subprocess
    subprocess.run(["git", "init", "-q"], cwd=proj, check=True)
    fake = tmp_path / "fakefw"
    (fake / "bin").mkdir(parents=True)
    fw = fake / "bin" / "fw"
    fw.write_text(SLOW_FW)
    fw.chmod(0o755)
    monkeypatch.setenv("SLOW_FW_TAIL", "3")
    return proj, fake


def _wait_for(path: Path, seconds: float) -> bool:
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if path.exists():
            return True
        time.sleep(0.1)
    return False


def test_slow_chain_outlives_the_wait_and_is_not_killed(slow_chain, monkeypatch):
    proj, fake = slow_chain
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    inc = importlib.reload(web.blueprints.inception)
    monkeypatch.setattr(inc, "FRAMEWORK_ROOT", fake)
    monkeypatch.setattr(inc, "_commit_decision", lambda *a, **k: (True, "nothing to commit"))

    t0 = time.monotonic()
    res = inc._run_decide("T-9750", "go", "r", wait=10)
    waited = time.monotonic() - t0
    # Returned on the PRIMARY result (task in completed/ with the decision),
    # not after the 3 s tail and not at the 10 s wait.
    assert waited < 3, waited
    assert res.running is True and res.busy is False
    assert inc._task_in_completed("T-9750")
    assert inc._decision_recorded_in_task("T-9750", "go")

    # A second launch while the chain still runs is refused, not started.
    with pytest.raises(dr.Busy):
        dr.launch("T-9750", "go", "r", project_root=proj, framework_root=fake)

    # The chain reaches its end, in a session of its own (a request timeout or
    # a Watchtower restart signals Flask's session, not this one).
    assert _wait_for(proj / "chain-finished", 15), "slow chain did not finish — killed?"
    assert int((proj / "chain-finished").read_text()) != os.getsid(0)
    run_dir = proj / res.run_dir
    end = time.monotonic() + 15
    while dr.read_status(run_dir).get("state") != "done" and time.monotonic() < end:
        time.sleep(0.1)
    st = dr.read_status(run_dir)
    assert st["state"] == "done" and st["rc"] == 0
    assert "finished" in (run_dir / "stdout.log").read_text()
    # The scratch repo has no HEAD, so the runner's follow-up commit fails: that
    # must be recorded and surfaced on the inception page, never silent.
    assert st["commit_ok"] is False
    assert "not committed" in (dr.surface(proj, "T-9750") or "")
    # Lock released once the runner exits.
    end = time.monotonic() + 5
    while dr.is_running(proj, "T-9750") and time.monotonic() < end:
        time.sleep(0.1)
    assert not dr.is_running(proj, "T-9750")


def test_chain_slower_than_the_wait_through_the_real_route(slow_chain, monkeypatch):
    """Wait expiry (review r1): the request answers 'in progress' and the chain
    still finishes and commits — nothing mocked between route and runner."""
    proj, fake = slow_chain
    monkeypatch.setenv("SLOW_FW_PRE", "2.5")   # decision lands AFTER the 1 s wait
    monkeypatch.setenv("SLOW_FW_TAIL", "0.5")
    (proj / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    inc = importlib.reload(web.blueprints.inception)
    import web.app
    importlib.reload(web.app)
    monkeypatch.setattr(inc, "FRAMEWORK_ROOT", fake)
    monkeypatch.setattr(inc, "DECIDE_WAIT_SECONDS", 1)
    app = web.app.create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        t0 = time.monotonic()
        html = _post(c, "T-9750").get_data(as_text=True)
        assert time.monotonic() - t0 < 2.4
    assert "Decision in progress" in html
    for bad in FORBIDDEN + ("Decision recorded",):
        assert bad not in html
    # Not killed: it lands, finishes, and the runner records its commits.
    assert _wait_for(proj / "chain-finished", 15)
    run = sorted((proj / ".context/working/decide").glob("T-9750-*"))[-1]
    end = time.monotonic() + 15
    while dr.read_status(run).get("state") != "done" and time.monotonic() < end:
        time.sleep(0.1)
    st = dr.read_status(run)
    assert st["state"] == "done" and st["rc"] == 0
    assert "primary_commit_ok" in st      # committed as soon as it landed
    assert inc._task_in_completed("T-9750")


def test_dead_runner_with_live_fw_still_blocks_a_second_launch(tmp_path):
    """Review r1: the lock dies with the runner; a surviving fw must still count."""
    import subprocess
    proj = tmp_path
    run = proj / ".context/working/decide/T-9770-20261003T000000000000Z"
    run.mkdir(parents=True)
    fw = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)",
                           "inception", "decide", "T-9770"])
    try:
        (run / "status.json").write_text(
            '{"state": "running", "pid": 1, "fw_pid": %d}' % fw.pid)
        assert dr.is_running(proj, "T-9770")
        with pytest.raises(dr.Busy):
            dr.launch("T-9770", "go", "r", project_root=proj, framework_root=tmp_path)
        assert dr.surface(proj, "T-9770") is None   # still running: nothing to report
    finally:
        fw.kill()
        fw.wait()
    assert not dr.is_running(proj, "T-9770")
    assert "stopped before it finished" in (dr.surface(proj, "T-9770") or "")


def test_surface_reports_a_failed_chain_even_when_its_commit_succeeded(tmp_path):
    run = tmp_path / ".context/working/decide/T-9763-20261003T000000000000Z"
    run.mkdir(parents=True)
    (run / "status.json").write_text('{"state": "done", "rc": 137, "commit_ok": true}')
    msg = dr.surface(tmp_path, "T-9763")
    assert msg and "exited with code 137" in msg


def test_surface_reports_a_runner_that_died_before_finishing(tmp_path):
    run = tmp_path / ".context/working/decide/T-9760-20261003T000000000000Z"
    run.mkdir(parents=True)
    (run / "status.json").write_text('{"state": "running", "pid": 1}')
    msg = dr.surface(tmp_path, "T-9760")
    assert msg and "stopped before it finished" in msg


def test_surface_reports_an_uncommitted_followup(tmp_path):
    run = tmp_path / ".context/working/decide/T-9761-20261003T000000000000Z"
    run.mkdir(parents=True)
    (run / "status.json").write_text(
        '{"state": "done", "commit_ok": false, "commit_msg": "hook refused"}')
    msg = dr.surface(tmp_path, "T-9761")
    assert msg and "not committed" in msg and "hook refused" in msg


def test_surface_is_silent_for_a_clean_run(tmp_path):
    run = tmp_path / ".context/working/decide/T-9762-20261003T000000000000Z"
    run.mkdir(parents=True)
    (run / "status.json").write_text('{"state": "done", "rc": 0, "commit_ok": true}')
    assert dr.surface(tmp_path, "T-9762") is None


# ---------------------------------------------------------------- 4. lazy index

def test_lazy_task_index_matches_task_index(tmp_path):
    sys.path.insert(0, str(REPO_ROOT / "lib"))
    import design_register as d
    for loc, tid, st in (("active", "T-12", "started-work"), ("completed", "T-123", "work-completed"),
                         ("active", "T-500", "captured"), ("completed", "T-500", "work-completed")):
        (tmp_path / ".tasks" / loc).mkdir(parents=True, exist_ok=True)
        (tmp_path / ".tasks" / loc / f"{tid}-x.md").write_text(
            f"---\nid: {tid}\nname: n{tid}\nstatus: {st}\n---\nbody {tid}\n")
    full = d.task_index(tmp_path)
    lazy = d.LazyTaskIndex(tmp_path)
    for tid in ("T-12", "T-123", "T-500", "T-1", "T-999", "nonsense"):
        assert (tid in lazy) == (tid in full), tid
        assert lazy.get(tid) == full.get(tid), tid
    with pytest.raises(KeyError):
        lazy["T-999"]
